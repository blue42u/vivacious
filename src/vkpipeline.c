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

#include <vivacious/vkpipeline.h>
#include "internal.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

struct VvVkP_Graph {
	size_t size;

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
};

struct VvVkP_State {
	VvVkP_State* prev;
	VvVkP_State* next;
	char udata[];
};
#define FREE_ST(st) (\
free(st))

struct VvVkP_Step {
	VvVkP_Step* prev;
	VvVkP_Step* next;

	VkSubpassContents contents;

	struct {
		int cnt;
		VvVkP_State** data;
	} stats;

	struct {
		int cnt;
		VvVkP_Dependency* data;
	} depends;

	char udata[];
};
#define FREE_SP(sp) (\
free((sp)->stats.data), \
free((sp)->depends.data), \
free(sp))

static VvVkP_Graph* create(size_t udatasize) {
	VvVkP_Graph* g = malloc(sizeof(VvVkP_Graph));
	*g = (VvVkP_Graph){
		.size=udatasize,
		.stats.begin = NULL, .stats.end = NULL,
		.steps.begin = NULL, .steps.end = NULL,
	};
	return g;
}

static void destroy(VvVkP_Graph* g) {
	VvVkP_State* stat = g->stats.begin;
	while(stat && stat->next) {
		stat = stat->next;
		FREE_ST(stat->prev);
	}
	FREE_ST(stat);

	VvVkP_Step* sp = g->steps.begin;
	while(sp && sp->next) {
		sp = sp->next;
		FREE_SP(sp->prev);
	}
	FREE_SP(sp);

	free(g);
}

static VvVkP_State* addSt(VvVkP_Graph* g, void* udata) {
	VvVkP_State* sp = malloc(sizeof(VvVkP_State) + g->size);
	*sp = (VvVkP_State){
		.prev = g->stats.end, .next = NULL,
	};
	memcpy(sp->udata, udata, g->size);
	if(!g->stats.begin) g->stats.begin = sp;
	if(g->stats.end) g->stats.end->next = sp;
	g->stats.end = sp;
	return sp;
}

static void rmSt(VvVkP_Graph* g, VvVkP_State* sp) {
	if(sp == g->stats.begin) g->stats.begin = sp->next;
	if(sp == g->stats.end) g->stats.end = sp->prev;
	if(sp->prev) sp->prev->next = sp->next;
	if(sp->next) sp->next->prev = sp->prev;
	free(sp);
}

static void insertSub(VvVkP_Graph* g, VvVkP_Step* sp) {
	int missing = sp->depends.cnt;
	VvVkP_Step* before = g->steps.begin;
	while(missing > 0 && before != NULL) {
		for(int i=0; i < sp->depends.cnt; i++)
			if(sp->depends.data[i].step == before)
				missing--;
		before = before->next;
	}
	if(missing > 0) {
		fprintf(stderr, "Error in insertOp!\n");
		return;
	}
	if(before == NULL) {	// i.e. we reached the end
		if(g->steps.end) g->steps.end->next = sp;
		sp->prev = g->steps.end;
		sp->next = NULL;
		g->steps.end = sp;
		if(!g->steps.begin) g->steps.begin = sp;	// If empty...
	} else if(before == g->steps.begin) {	// i.e. we just began
		before->prev = sp;
		sp->next = before;
		sp->prev = NULL;
		g->steps.begin = sp;
	} else {	// Somewhere in the middle
		sp->prev = before->prev;
		before->prev->next = sp;
		sp->next = before;
		before->prev = sp;
	}
}

static VvVkP_Step* addSp(VvVkP_Graph* g, void* udata, int second,
	int sc, VvVkP_State** ss,
	int dc, const VvVkP_Dependency* ds) {

	VvVkP_Step* sp = malloc(sizeof(VvVkP_Step) + g->size);
	*sp = (VvVkP_Step){
		.contents = second
			? VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS
			: VK_SUBPASS_CONTENTS_INLINE,
		.stats.cnt = sc, .stats.data = NULL,
		.depends.cnt = dc, .depends.data = NULL,
	};
	memcpy(sp->udata, udata, g->size);

	if(sc > 0) {
		sp->stats.data = malloc(sc*sizeof(VvVkP_State*));
		memcpy(sp->stats.data, ss, sc*sizeof(VvVkP_State*));
	}
	if(dc > 0) {
		sp->depends.data = malloc(dc*sizeof(VvVkP_Dependency));
		memcpy(sp->depends.data, ds, dc*sizeof(VvVkP_Dependency));
	}

	insertSub(g, sp);
	return sp;
}

static void rmSp(VvVkP_Graph* g, VvVkP_Step* sp) {
	if(sp == g->steps.begin) g->steps.begin = sp->next;
	if(sp == g->steps.end) g->steps.end = sp->prev;
	if(sp->prev) sp->prev->next = sp->next;
	if(sp->next) sp->next->prev = sp->prev;
	FREE_SP(sp);
}

static void depends(VvVkP_Graph* g, VvVkP_Step* sp,
	int dc, const VvVkP_Dependency* ds) {

	// First, we take the Step out of the list
	if(sp == g->steps.begin) g->steps.begin = sp->next;
	if(sp == g->steps.end) g->steps.end = sp->prev;
	if(sp->prev) sp->prev->next = sp->next;
	if(sp->next) sp->next->prev = sp->prev;

	// Then we expand depends.data
	sp->depends.data = realloc(sp->depends.data,
		(dc + sp->depends.cnt)*sizeof(VvVkP_Dependency));
	memcpy(&sp->depends.data[sp->depends.cnt], ds,
		dc*sizeof(VvVkP_Dependency));
	sp->depends.cnt += dc;

	// Then we add it back in (slight issue, fix later)
	insertSub(g, sp);
}

static void* getSts(const VvVkP_Graph* g, int* cnt) {
	*cnt = 0;
	for(VvVkP_State* st = g->stats.begin; st; st = st->next)
		(*cnt)++;
	char* out = malloc(*cnt * g->size);
	int i = 0;
	for(VvVkP_State* st = g->stats.begin; st; st=st->next, i++)
		memcpy(&out[i*g->size], st->udata, g->size);
	return out;
}

static void* getSps(const VvVkP_Graph* g, int* cnt) {
	*cnt = 0;
	for(VvVkP_Step* sp = g->steps.begin; sp; sp = sp->next)
		(*cnt)++;
	char* out = malloc(*cnt * g->size);
	int i = 0;
	for(VvVkP_Step* sp = g->steps.begin; sp; i++, sp=sp->next)
		memcpy(&out[i*g->size], sp->udata, g->size);
	return out;
}

static VkSubpassDependency* getDeps(const VvVkP_Graph* g, uint32_t* cnt) {
	int sc = 0;
	*cnt = 0;
	for(VvVkP_Step* sp = g->steps.begin; sp; sp = sp->next) {
		*cnt += sp->depends.cnt;
		sc++;
	}
	VvVkP_Step* sps[sc];
	sc = 0;
	for(VvVkP_Step* sp = g->steps.begin; sp; sp = sp->next, sc++)
		sps[sc] = sp;

	VkSubpassDependency* out = malloc(*cnt * sizeof(VkSubpassDependency));

	int si = 0;
	int ind = 0;
	for(VvVkP_Step* sp = g->steps.begin; sp; sp=sp->next, si++) {
		for(int i=0; i < sp->depends.cnt && ind<*cnt; i++) {
			VvVkP_Dependency d = sp->depends.data[i];
			int srcind = -1;
			for(int i=0; i<sc; i++) {
				if(sps[i] == d.step) {
					srcind = i;
					break;
				}
			}
			out[ind] = (VkSubpassDependency){
				srcind, si,
				d.srcStage, d.dstStage,
				d.srcAccess, d.dstAccess,
				d.flags,
			};
			ind++;
		}
	}
	return out;
}

static void exec(const VvVkP_Graph* g, const VvVk_Binding* vk,
	VkCommandBuffer cbuff, const VkRenderPassBeginInfo* info,
	void (*set)(const VvVk_Binding*, void*, VkCommandBuffer),
	void (*uset)(const VvVk_Binding*, void*, VkCommandBuffer),
	void (*cmd)(const VvVk_Binding*, void*, VkCommandBuffer)) {

	int statcnt = 0;
	for(VvVkP_State* st = g->stats.begin; st; st = st->next)
		statcnt++;
	VvVkP_State* stats[statcnt];
	int setting[statcnt];

	VvVkP_State* st;
	int i;
	for(st=g->stats.begin, i=0; st; st = st->next, i++) {
		stats[i] = st;
		setting[i] = 0;
	}

	// Enter the RenderPass
	vk->core->vk_1_0->CmdBeginRenderPass(cbuff, info,
		g->steps.begin ? g->steps.begin->contents
		: VK_SUBPASS_CONTENTS_INLINE);

	for(VvVkP_Step* c = g->steps.begin; c; c = c->next) {
		// First, get the States right
		for(int i=0; i<statcnt; i++) {
			int shouldbe = 0;
			for(int j=0; j < c->stats.cnt; j++) {
				if(c->stats.data[j] == stats[i]) {
					shouldbe = 1;
					break;
				}
			}

			if(shouldbe && !setting[i]) {
				if(set) set(vk, stats[i]->udata, cbuff);
			} else if(!shouldbe && setting[i]) {
				if(uset) uset(vk, stats[i]->udata, cbuff);
			}
			setting[i] = shouldbe;
		}

		// Now execute the Step
		if(cmd) cmd(vk, c->udata, cbuff);

		// Record the subpass shift
		if(c->next)
			vk->core->vk_1_0->CmdNextSubpass(cbuff,
				c->next->contents);
	}

	// Now unset all the extra States
	if(uset) {
		for(int i=0; i<statcnt; i++) {
			if(setting[i])
				uset(vk, stats[i]->udata, cbuff);
		}
	}

	// Exit the RenderPass
	vk->core->vk_1_0->CmdEndRenderPass(cbuff);
}

VvAPI const Vv_VulkanPipeline vVvkp_test = {
	.create = create, .destroy = destroy,
	.addState = addSt,
	.addStep = addSp, .removeStep = rmSp, .addDepends = depends,
	.getStates = getSts, .getSteps = getSps, .getDepends = getDeps,
	.execute = exec,
};

#endif // Vv_ENABLE_VULKAN
