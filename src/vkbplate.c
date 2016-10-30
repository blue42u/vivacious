/**************************************************************************
   Copyright 2016 Jonathon Anderson

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

#include <vivacious/vkbplate.h>
#include "internal.h"
#include <stdlib.h>
#include <string.h>

_Vv_ENUM(RuleType) {
	RULE_VERSION,
	RULE_LAYER,
	RULE_INST_EXT,
};

_Vv_STRUCT(Rule) {
	int id;
	Rule* next;
	RuleType type;
	float pri;
	int satisfied;
	union {
		uint32_t version;	// RULE_VERSION
		const char* layer;	// RULE_LAYER
		const char* inst_ext;	// RULE_INST_EXT
	};
};

struct VvVkBp_Rules {
	Rule* headRule;	// This imp uses a linked-list approach for rules.
	Rule* tailRule;

	int appRule;
	const char* appName;
	uint32_t appVer;

	const Vv_Vulkan* vkapi;
	const VvVk_Binding* vkb;

	VkInstance* inst;
};

static VvVkBp_Rules* create(const Vv_Vulkan* vkapi, const VvVk_Binding* vkb) {
	VvVkBp_Rules* r = malloc(sizeof(VvVkBp_Rules));
	r->headRule = NULL;
	r->tailRule = NULL;

	r->appRule = 0;
	r->appName = "They said they would tell me :'(";
	r->appVer = VK_MAKE_VERSION(0,0,0);

	r->vkapi = vkapi;
	r->vkb = vkb;

	r->inst = NULL;
	return r;
}

static void destroy(VvVkBp_Rules* r) {
	Rule* rule = r->headRule;
	while(rule) {
		Rule* next = rule->next;
		free(rule);
		rule = next;
	}
	free(r);
}

static int resolveInst(VvVkBp_Rules*);

static int resolve(VvVkBp_Rules* r) {
	int res;
	if(r->inst) res = resolveInst(r);
	if(res) return res;
	return 0;
}

static int satisfied(const VvVkBp_Rules* r, int rid) {
	Rule* last = NULL;
	Rule* rl =  r->headRule;
	while(rl && rl->id < rid) {
		last = rl;
		rl = rl->next;
	}
	if(!rl || rl->id > rid) return 1;
	else return rl->satisfied;
}

static void remove(VvVkBp_Rules* r, int id) {
	Rule* last = NULL;
	Rule* rl =  r->headRule;
	while(rl && rl->id < id) {
		last = rl;
		rl = rl->next;
	}
	if(!rl || rl->id > id) return;
	if(last) last->next = rl->next;
	else r->headRule = rl->next;
	free(rl);
}

// Internal function
static Rule* newRule(VvVkBp_Rules* r, float p) {
	Rule* res = malloc(sizeof(Rule));
	res->next = NULL;
	res->satisfied = 0;
	res->pri = p;
	if(r->tailRule) {
		res->id = r->tailRule->id + 1;
		r->tailRule->next = res;
	} else {
		res->id = 2;	// rid 1 is reserved for the AppInfo rule
		r->headRule = res;
	}
	r->tailRule = res;
	return res;
}

static int addVersion(VvVkBp_Rules* r, float p, uint32_t ver) {
	Rule* rl = newRule(r, p);
	rl->type = RULE_VERSION;
	rl->version = ver;
	return rl->id;
}

static int addLayer(VvVkBp_Rules* r, float p, const char* lay) {
	Rule* rl = newRule(r, p);
	rl->type = RULE_LAYER;
	rl->layer = lay;
	return rl->id;
}

static int addInstExt(VvVkBp_Rules* r, float p, const char* ext) {
	Rule* rl = newRule(r, p);
	rl->type = RULE_INST_EXT;
	rl->inst_ext = ext;
	return rl->id;
}

static int addAppInfo(VvVkBp_Rules* r, float p, const char* n, uint32_t v) {
	if(r->appRule) return 0;
	r->appRule = 1;
	r->appName = n;
	r->appVer = v;
	return 1;
}

static void setInstance(VvVkBp_Rules* r, VkInstance* pinst) {
	r->inst = pinst;
}

// Internal Function
static int resolveInst(VvVkBp_Rules* r) {
	const VvVk_1_0* vk = r->vkapi->core->vk_1_0(r->vkb);

	uint32_t lpc;
	vk->EnumerateInstanceLayerProperties(&lpc, NULL);
	VkLayerProperties* lps = malloc(lpc*sizeof(VkLayerProperties));
	vk->EnumerateInstanceLayerProperties(&lpc, lps);

	uint32_t epc;
	vk->EnumerateInstanceExtensionProperties(NULL, &epc, NULL);
	VkExtensionProperties* eps = malloc(epc*sizeof(VkExtensionProperties));
	vk->EnumerateInstanceExtensionProperties(NULL, &epc, eps);

	int layc = 0;
	int extc = 0;

	int tmp;

	Rule* rl = r->headRule;
	while(rl) {
		switch(rl->type) {
		case RULE_LAYER:
			tmp = 0;
			for(int i=0; i<lpc; i++)
				if(!strcmp(lps[i].layerName, rl->layer)) {
					tmp = 1;
					break;
				}
			if(tmp == 0) {
				free(lps);
				free(eps);
				return rl->id;
			}
			layc++; break;
		case RULE_INST_EXT:
			tmp = 0;
			for(int i=0; i<epc; i++)
				if(!strcmp(eps[i].extensionName,rl->inst_ext)) {
					tmp = 1;
					break;
				}
			if(tmp == 0) {
				free(lps);
				free(eps);
				return rl->id;
			}
			extc++; break;
		default: break;
		};
		rl = rl->next;
	}

	free(lps);
	free(eps);

	uint32_t apiver = 0;
	const char** lays = malloc(layc*sizeof(char*));
	const char** exts = malloc(extc*sizeof(char*));
	layc = extc = 0;

	rl = r->headRule;
	while(rl) {
		switch(rl->type) {
		case RULE_VERSION:
			if(apiver < rl->version)
				apiver = rl->version;
			break;
		case RULE_LAYER:
			lays[layc] = rl->layer;
			layc++;
			break;
		case RULE_INST_EXT:
			exts[extc] = rl->inst_ext;
			extc++;
			break;
		};
		rl = rl->next;
	}

	VkApplicationInfo ai = {
		VK_STRUCTURE_TYPE_APPLICATION_INFO, NULL,
		r->appName, r->appVer,
		"Vivacious", VK_MAKE_VERSION(Vv_VERSION_MAJOR,
					Vv_VERSION_MINOR, Vv_VERSION_PATCH),
		apiver,
	};
	VkInstanceCreateInfo ici = {
		VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO, NULL, 0,
		&ai,
		layc, lays,
		extc, exts,
	};
	VkResult rs = vk->CreateInstance(&ici, NULL, r->inst);
	if(rs < 0) return rs;
	else return 0;
}

VvAPI const Vv_VulkanBoilerplate vVvkbp_sum = {
	create, destroy,
	resolve, satisfied,
	remove,
	addVersion, addLayer, addInstExt, addAppInfo, setInstance,
};

#endif // Vv_ENABLE_VULKAN
