/**************************************************************************
   Copyright 2016-2017 Jonathon Anderson

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
***************************************************************************/

#ifdef Vv_ENABLE_VULKAN

#define Vv_CHOICE *V
#define Vv_IMP_vks
#include <vivacious/vkshader.h>
#include "internal.h"
#include "spirv/1.2/spirv.h"
#include "vkshader/mcopy.h"
#include "vkshader/sections.h"
#include <string.h>
#include <stdio.h>
#include <unistd.h>

struct VvVkS_Bank {
	VvVkS_Component* components;
};

struct VvVkS_Component {
	VvVkS_Component* next;
	size_t size;
	uint32_t* code;
};

static VvVkS_Bank* createBank(const Vv* V) {
	VvVkS_Bank* b = malloc(sizeof(VvVkS_Bank));
	b->components = NULL;
	return b;
}

static void destroyBank(const Vv* V, VvVkS_Bank* b) {
	for(VvVkS_Component* c = b->components; c;) {
		VvVkS_Component* n = c->next;
		free(c->code);
		free(c);
		c = n;
	}
	free(b);
}

static VvVkS_Component* loadShader(const Vv* V, VvVkS_Bank* b,
	VkShaderModuleCreateInfo* smci) {

	if(smci->sType != VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO)
		return NULL;
	if(smci->pCode[1] > SpvVersion) return NULL;
	VvVkS_Component* c = malloc(sizeof(VvVkS_Component));
	c->next = b->components;
	c->size = smci->codeSize / 4;
	c->code = malloc(smci->codeSize);
	memcpy(c->code, smci->pCode, smci->codeSize);
	b->components = c;
	return c;
}

static VkResult construct(const Vv* V, VvVkS_Bank* b, VkDevice dev,
	size_t nc, VvVkS_Component** cs, VkShaderModule* sm) {

	// 5+1+2 (header) + 1+1 (footer) for each EPs function,
	// and 4 for each component in each EP.
	size_t sz = (10+4*nc)*7;
	for(size_t i=0; i<nc; i++) sz += cs[i]->size;
	uint32_t* out = malloc(sz*sizeof(uint32_t));

	uint32_t shifts[nc+1];
	shifts[0] = 0;
	size_t heres[nc];
	size_t fstarts[nc];
	for(size_t i=0; i<nc; i++) {
		shifts[i+1] = shifts[i] + cs[i]->code[3];
		heres[i] = 5;	// Instructions start on index 5
		fstarts[i] = 0;
	}

	iddata ids[shifts[nc]];
	for(uint32_t i=0; i<shifts[nc]; i++) {
		ids[i].defined = false;
		ids[i].map = i;
		ids[i].numwords = 0;
		ids[i].op = NULL;
	}

	size_t here = 0;
#define FORCS for(size_t csind=0; csind<nc; csind++)
#define WRITE(S) \
(here += _vVvks_mcopy_idshift(S, &out[here], shifts[nc], ids, shifts[csind]))
#define RAW(...) ({ \
	uint32_t d[] = {__VA_ARGS__}; \
	memcpy(&out[here], d, sizeof(d)); \
	here += sizeof(d)/sizeof(d[0]); \
})
#define WORD (cs[csind]->code[heres[csind]])
#define OP (WORD & SpvOpCodeMask)
#define WC (WORD >> SpvWordCountShift)
#define OPER(N) (cs[csind]->code[heres[csind]+(N)])
#define NEXT (heres[csind] += WC)
#define PASS (WRITE(&WORD), NEXT)
#define EOI (heres[csind] >= cs[csind]->size)

	// Write the header, with 7 extra ids for the EP functions
	RAW(SpvMagicNumber, SpvVersion, 0, shifts[nc]+7, 0);

	FORCS while(OP == SpvOpCapability) PASS;
	FORCS while(OP == SpvOpExtension) PASS;
	FORCS while(OP == SpvOpExtInstImport) PASS;

	// Here in the OpMemoryModel, EPs and EMs do we have to do stuff
	// First make sure the memory models are the same:
	{
		uint32_t opmm[3];
		memcpy(opmm, &cs[0]->code[heres[0]], 3*sizeof(uint32_t));
		FORCS {
			if(memcmp(opmm, &WORD, 3*sizeof(uint32_t)) != 0)
				return VK_ERROR_INCOMPATIBLE_DRIVER;
			NEXT;
		}
		RAW(opmm[0], opmm[1], opmm[2]);
	}

	// Now choose all the EPs
	uint32_t funcs[7][nc]; // Indexed by [ExecutionModel+7*csind]
	for(SpvExecutionModel em = 0; em < 7; em++) {
		uint32_t istart = here;
		uint32_t idcnt = 0;
		RAW(SpvOpEntryPoint, em, shifts[nc]+1+em, 0x6E69616D, 0);
		FORCS {
			uint32_t rewind = heres[csind];
			funcs[em][csind] = 0;
			while(OP == SpvOpEntryPoint) {
				if(OPER(1) == em) {
					funcs[em][csind] = OPER(2)+shifts[csind];
					int i = 3;
					while(OPER(i)>>24
						&& (OPER(i)>>16)&0xFF
						&& (OPER(i)>>8)&0xFF
						&& OPER(i)&0xFF) i++;
					i++;
					idcnt += WC-i;
					for(; i<WC; i++)
						RAW(OPER(i)+shifts[csind]);
					break;
				}
				NEXT;
			}
			heres[csind] = rewind;
		}
		if(idcnt > 0) out[istart] |= (idcnt+5)<<SpvWordCountShift;
		else here = istart;
	}
	FORCS while(OP == SpvOpEntryPoint) NEXT;

	// Currently skip the EMs, and just assume we don't need any
	FORCS while(OP == SpvOpExecutionMode) NEXT;

	FORCS while(SEC_DEBUGA) PASS;
	FORCS while(SEC_DEBUGB) PASS;
	FORCS while(SEC_ANNOTATE) PASS;
	FORCS while(SEC_TYPES) PASS;
	FORCS {
		size_t rewind = 0;
		while(!EOI) {
			if(OP == SpvOpFunction) {
				fstarts[csind] = heres[csind];
				rewind = here;
			} else if(OP == SpvOpLabel) break;
			PASS;
		}
		if(!EOI) {
			heres[csind] = fstarts[csind];
			here = rewind;
		}
	}
	FORCS while(!EOI) PASS;

	// At the end we put the composite EP functions. First find the void:
	uint32_t voidid = 0;
	for(uint32_t i=0; i<shifts[nc]; i++) {
		if(ids[i].defined && ids[i].op
		&& (ids[i].op[0]&SpvOpCodeMask) == SpvOpTypeVoid) {
			voidid = i;
			break;
		}
	}
	if(!voidid) {free(out); return VK_ERROR_INITIALIZATION_FAILED;}

	// Then find the void function
	uint32_t voidfunc = 0;
	for(uint32_t i=0; i<shifts[nc]; i++) {
		if(ids[i].defined && ids[i].op
		&& ids[i].op[0] == (SpvOpTypeFunction|3<<SpvWordCountShift)
		&& ids[i].op[2] == voidid) {
			voidfunc = i;
			break;
		}
	}
	if(!voidfunc) {free(out); return VK_ERROR_INITIALIZATION_FAILED;}

	// Now write out the different functions
	uint32_t extra = out[3];
	for(SpvExecutionModel em = 0; em < 7; em++) {
		RAW(SpvOpFunction | 5<<SpvWordCountShift, voidid,
			shifts[nc]+1+em, 0, voidfunc);
		RAW(SpvOpLabel | 2<<SpvWordCountShift, ++extra);
		FORCS {
			if(funcs[em][csind])
				RAW(SpvOpFunctionCall | 4<<SpvWordCountShift,
					voidid, ++extra, funcs[em][csind]);
		}
		RAW(SpvOpReturn | 1<<SpvWordCountShift);
		RAW(SpvOpFunctionEnd | 1<<SpvWordCountShift);
	}
	out[3] = extra+1;

	VkResult r = vVvk_CreateShaderModule(dev, &(VkShaderModuleCreateInfo){
		.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
		.codeSize = here*4,
		.pCode = out,
	}, NULL, sm);
	free(out);
	return r;
}

const VvVkS libVv_vks_test = {
	.createBank = createBank,
	.destroyBank = destroyBank,
	.loadShader = loadShader,
	.construct = construct,
};

#endif // Vv_ENABLE_VULKAN
