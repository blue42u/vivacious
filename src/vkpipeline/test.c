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
#define Vv_IMP_vkp

#include <vivacious/vkpipeline.h>
#include "internal.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

struct VvVkP_Graph {
	VkRenderPass rpass;	// Because we must remember.
	VkDevice dev;
	PFN_vkDestroyRenderPass drpass;
	VkImageLayout* layouts;	// Saving info for attachment-based deps.

	// Doubly-linked list for the States.
	struct {
		VvVkP_State* begin;
		VvVkP_State* end;
	} stats;

	// Doubly-linked list for the Steps.
	struct {
		VvVkP_Step* begin;
		VvVkP_Step* end;
	} steps;

	int second;	// Since we only have one subpass, global contents
};

struct VvVkP_State {
	VvVkP_State* prev;
	VvVkP_State* next;
	void* udata;
	int bound;	// subpass-bound flag
};
#define FREE_ST(st) (\
free(st))

struct VvVkP_Step {
	VvVkP_Step* prev;
	VvVkP_Step* next;
	void* udata;

	struct {
		int cnt;
		VvVkP_State** data;
	} stats;

	struct {
		int cnt;
		VvVkP_Dependency* data;
	} depends;
};
#define FREE_SP(sp) (\
free((sp)->stats.data), \
free((sp)->depends.data), \
free(sp))

static VvVkP_Graph* create(const Vv* V) {
	VvVkP_Graph* g = malloc(sizeof(VvVkP_Graph));
	*g = (VvVkP_Graph){
		.stats.begin = NULL, .stats.end = NULL,
		.steps.begin = NULL, .steps.end = NULL,
		.second = -1, .layouts = NULL, .rpass = VK_NULL_HANDLE,
	};
	return g;
}

static void destroy(const Vv* V, VvVkP_Graph* g) {
	VvVkP_State* stat = g->stats.begin;
	while(stat && stat->next) {
		stat = stat->next;
		FREE_ST(stat->prev);
	}
	if(stat) FREE_ST(stat);

	VvVkP_Step* sp = g->steps.begin;
	while(sp && sp->next) {
		sp = sp->next;
		FREE_SP(sp->prev);
	}
	if(sp) FREE_SP(sp);

	if(g->layouts) free(g->layouts);
	if(g->rpass) g->drpass(g->dev, g->rpass, NULL);

	free(g);
}

static VvVkP_State* addSt(const Vv* V, VvVkP_Graph* g, void* udata, int bound) {
	VvVkP_State* sp = malloc(sizeof(VvVkP_State));
	*sp = (VvVkP_State){
		.prev = g->stats.end, .next = NULL,
		.udata = udata, .bound = bound ? 1 : 0,
	};
	if(!g->stats.begin) g->stats.begin = sp;
	if(g->stats.end) g->stats.end->next = sp;
	g->stats.end = sp;
	return sp;
}

static void insert(VvVkP_Graph* g, VvVkP_Step* sp) {
	int missing = sp->depends.cnt;
	sp->prev = sp->next = NULL;
	struct {
		VvVkP_Step* begin;
		VvVkP_Step* end;
	} strip = {sp, sp};
	VvVkP_Step* here = g->steps.begin;
	while(missing > 0 && here != NULL) {
		int needsus = 0;
		for(int i=0; i < here->depends.cnt; i++) {
			for(VvVkP_Step* us = sp; us; us = us->next) {
				if(here->depends.data[i].step == us) {
					needsus = 1;
					break;
				}
			}
			if(needsus) break;
		}
		if(!needsus) { // If it doesn't need to come after, does it come before?
			for(int i=0; i < sp->depends.cnt; i++)
				if(sp->depends.data[i].step == here)
					missing--;
			here = here->next;
		} else {
			VvVkP_Step* piece = here;
			here = here->next;
			if(piece->next) piece->next->prev = piece->prev;
			else g->steps.end = piece->prev;
			if(piece->prev) piece->prev->next = piece->next;
			else g->steps.begin = piece->next;

			// Move after to the end of the "allafter" l-list
			strip.end->next = piece;
			piece->prev = strip.end;
			piece->next = NULL;
			strip.end = piece;
		}
	}
	if(missing > 0) {
		fprintf(stderr, "Error in insert!\n");
		return;
	}
	if(here == NULL) {	// i.e. we reached the end
		if(g->steps.end) g->steps.end->next = strip.begin;
		strip.begin->prev = g->steps.end;
		strip.end->next = NULL;
		g->steps.end = strip.end;
		if(!g->steps.begin) g->steps.begin = strip.begin;	// If empty...
	} else if(here == g->steps.begin) {	// i.e. we just began
		here->prev = strip.end;
		strip.end->next = here;
		strip.begin->prev = NULL;
		g->steps.begin = strip.begin;
	} else {	// Somewhere in the middle
		strip.begin->prev = here->prev;
		here->prev->next = strip.begin;
		strip.end->next = here;
		here->prev = strip.end;
	}
}

static VvVkP_Step* addSp(const Vv* V, VvVkP_Graph* g, void* udata, int second,
	size_t sc, VvVkP_State** ss,
	size_t dc, VvVkP_Dependency** ds) {

	if(g->second == -1) g->second = second ? 1 : 0;
	else if(g->second != (second ? 1 : 0)) return NULL;

	VvVkP_Step* sp = malloc(sizeof(VvVkP_Step));
	*sp = (VvVkP_Step){
		.stats.cnt = sc, .stats.data = NULL,
		.depends.cnt = dc, .depends.data = NULL,
		.udata = udata,
	};

	if(sc > 0) {
		sp->stats.data = malloc(sc*sizeof(VvVkP_State*));
		memcpy(sp->stats.data, ss, sc*sizeof(VvVkP_State*));
	}
	if(dc > 0) {
		sp->depends.data = malloc(dc*sizeof(VvVkP_Dependency));
		for(int i=0; i<dc; i++)
			sp->depends.data[i] = *ds[i];
	}

	insert(g, sp);
	return sp;
}

static void rmSp(const Vv* V, VvVkP_Graph* g, VvVkP_Step* sp) {
	if(sp == g->steps.begin) g->steps.begin = sp->next;
	if(sp == g->steps.end) g->steps.end = sp->prev;
	if(sp->prev) sp->prev->next = sp->next;
	if(sp->next) sp->next->prev = sp->prev;
	FREE_SP(sp);
}

static void depends(const Vv* V, VvVkP_Graph* g, VvVkP_Step* sp,
	size_t dc, VvVkP_Dependency** ds) {

	// First, we take the Step out of the list
	if(sp == g->steps.begin) g->steps.begin = sp->next;
	if(sp == g->steps.end) g->steps.end = sp->prev;
	if(sp->prev) sp->prev->next = sp->next;
	if(sp->next) sp->next->prev = sp->prev;

	// Then we expand depends.data
	sp->depends.data = realloc(sp->depends.data,
		(dc + sp->depends.cnt)*sizeof(VvVkP_Dependency));
	for(int i=0; i<dc; i++)
		sp->depends.data[i+sp->depends.cnt] = *ds[i];
	sp->depends.cnt += dc;

	// Then we add it back in (slight issue, fix later)
	insert(g, sp);
}

static VkRenderPass getRP(const Vv* V, VvVkP_Graph* g, VkDevice dev,
	size_t aCnt, VkAttachmentDescription* as,
	VkSubpassDescription (*spass)(void*,size_t,void**,size_t,void**),
	void* spass_ud, VkResult* rs) {

	// Destroy the old RenderPass
	if(g->rpass) g->drpass(g->dev, g->rpass, NULL);

	// Get a contiguous array of Steps and dependencies
	int depcnt = 0, spcnt = 0;
	for(VvVkP_Step* sp = g->steps.begin; sp; sp = sp->next) {
		spcnt++;
		depcnt += sp->depends.cnt;
	}
	void** sps = malloc(spcnt*sizeof(void*));
	VkSubpassDependency* deps = malloc(depcnt*sizeof(VkSubpassDependency));
	spcnt = 0; depcnt = 0;
	for(VvVkP_Step* sp = g->steps.begin; sp; sp = sp->next) {
		sps[spcnt++] = sp;
		for(int i=0; i < sp->depends.cnt; i++) {
			deps[depcnt++] = (VkSubpassDependency){
				.srcSubpass = 0, .dstSubpass = 0,
				.srcStageMask = sp->depends.data[i].srcStage,
				.dstStageMask = sp->depends.data[i].dstStage,
				.srcAccessMask = sp->depends.data[i].srcAccess,
				.dstAccessMask = sp->depends.data[i].dstAccess,
				.dependencyFlags = sp->depends.data[i].flags
					| (sp->depends.data[i].attachmentEnable
					? VK_DEPENDENCY_BY_REGION_BIT : 0),
			};
		}
	}

	// Get a contiguous array of bound States
	int stcnt = 0;
	for(VvVkP_State* st = g->stats.begin; st; st = st->next)
		if(st->bound) stcnt++;
	void** sts = malloc(stcnt*sizeof(void*));
	stcnt = 0;
	for(VvVkP_State* st = g->stats.begin; st; st = st->next)
		if(st->bound) sts[stcnt++] = st;

	// Get the description for the only subpass
	VkSubpassDescription sd = spass(spass_ud, spcnt, sps, stcnt, sts);
	free(sps);
	free(sts);
	if(g->layouts) free(g->layouts);
	g->layouts = calloc(aCnt, sizeof(VkImageLayout));
	for(int i=0; i<sd.inputAttachmentCount; i++)
		g->layouts[sd.pInputAttachments[i].attachment]
			= sd.pInputAttachments[i].layout;
	for(int i=0; i<sd.colorAttachmentCount; i++) {
		g->layouts[sd.pColorAttachments[i].attachment]
			= sd.pColorAttachments[i].layout;
		if(sd.pResolveAttachments)
			g->layouts[sd.pResolveAttachments[i].attachment]
				= sd.pResolveAttachments[i].layout;
	}
	if(sd.pDepthStencilAttachment)
		g->layouts[sd.pDepthStencilAttachment->attachment]
			= sd.pDepthStencilAttachment->layout;

	// Make the RenderPass
	g->dev = dev;
	g->drpass = V->vk->cmds->core->DestroyRenderPass;
	VkResult r = vVvk_CreateRenderPass(dev, &(VkRenderPassCreateInfo){
		VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO, NULL, 0,
		aCnt, as,
		1, &sd,
		depcnt, deps,
	}, NULL, &(g->rpass));
	free(deps);
	if(r<0) {
		g->rpass = VK_NULL_HANDLE;
		if(rs) *rs = r;
		return VK_NULL_HANDLE;
	} else return g->rpass;
}

static size_t getSts(const Vv* V, VvVkP_Graph* g, void** udata, int* spasses) {
	int cnt = 0;
	for(VvVkP_State* st = g->stats.begin; st; st=st->next) {
		if(udata) udata[cnt] = st->udata;
		if(spasses) spasses[cnt] = 0;
		cnt++;
	}
	return cnt;
}

static size_t getSps(const Vv* V, VvVkP_Graph* g, void** udata) {
	int cnt = 0;
	for(VvVkP_Step* sp = g->steps.begin; sp; sp = sp->next) {
		if(udata) udata[cnt] = sp->udata;
		cnt++;
	}
	return cnt;
}

static void rec(const Vv* V, VvVkP_Graph* g,
	VkCommandBuffer cbuff, VkRenderPassBeginInfo* info,
	VkImage* imgs,
	void (*set)(void*, void*, VkCommandBuffer), void* set_ud,
	void (*uset)(void*, void*, VkCommandBuffer), void* uset_ud,
	void (*cmd)(void*, void*, VkCommandBuffer), void* cmd_ud) {

	int statcnt = 0;
	for(VvVkP_State* st = g->stats.begin; st; st = st->next)
		statcnt++;
	VvVkP_State* stats[statcnt];
	int setting[statcnt];
	statcnt = 0;
	for(VvVkP_State* st = g->stats.begin; st; st = st->next) {
		stats[statcnt] = st;
		setting[statcnt] = 0;
		statcnt++;
	}

	// Enter the RenderPass
	vVvk_CmdBeginRenderPass(cbuff, info,
		g->second ? VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS
		: VK_SUBPASS_CONTENTS_INLINE);

	for(VvVkP_Step* sp = g->steps.begin; sp; sp = sp->next) {
		// Record all the dependencies
		for(int i=0; i < sp->depends.cnt; i++) {
			VvVkP_Dependency* d = &sp->depends.data[i];
			if(d->attachmentEnable)
				vVvk_CmdPipelineBarrier(cbuff,
					d->srcStage, d->dstStage, d->flags,
					0, NULL,
					0, NULL,
					1, &(VkImageMemoryBarrier){
						VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
						NULL,
						d->srcAccess, d->dstAccess,
						g->layouts[d->attachment],
						g->layouts[d->attachment],
						VK_QUEUE_FAMILY_IGNORED,
						VK_QUEUE_FAMILY_IGNORED,
						imgs[d->attachment],
						d->attachmentRange,
					});
			else
				vVvk_CmdPipelineBarrier(cbuff,
					d->srcStage, d->dstStage, d->flags,
					1, &(VkMemoryBarrier){
						VK_STRUCTURE_TYPE_MEMORY_BARRIER,
						NULL,
						d->srcAccess, d->dstAccess,
					},
					0, NULL,
					0, NULL);
		}

		// Get the States right
		for(int i=0; i<statcnt; i++) {
			int shouldbe = 0;
			for(int j=0; j < sp->stats.cnt; j++) {
				if(sp->stats.data[j] == stats[i]) {
					shouldbe = 1;
					break;
				}
			}

			if(shouldbe && !setting[i]) {
				if(set) set(set_ud, stats[i]->udata, cbuff);
			} else if(!shouldbe && setting[i]) {
				if(uset) uset(uset_ud, stats[i]->udata, cbuff);
			}
			setting[i] = shouldbe;
		}

		// Now execute the Step
		if(cmd) cmd(cmd_ud, sp->udata, cbuff);
	}

	// Now unset all the extra States
	if(uset) {
		for(int i=0; i<statcnt; i++) {
			if(setting[i])
				uset(uset_ud, stats[i]->udata, cbuff);
		}
	}

	// Exit the RenderPass
	vVvk_CmdEndRenderPass(cbuff);
}

const VvVkP libVv_vkp_test = {
	.create = create, .destroy = destroy,
	.addState = addSt,
	.addStep = addSp, .removeStep = rmSp, .addDepends = depends,
	.getRenderPass = getRP,
	.getStates = getSts, .getSteps = getSps,
	.record = rec,
};

#endif // Vv_ENABLE_VULKAN
