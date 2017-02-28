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

	// Doubly-linked list for the Subpasss.
	struct {
		VvVkP_Subpass* begin;
		VvVkP_Subpass* end;
	} subs;
};

struct VvVkP_State {
	VvVkP_State* prev;
	VvVkP_State* next;
	char udata[];
};
#define FREE_ST(st) (\
free(st))

struct VvVkP_Subpass {
	VvVkP_Subpass* prev;
	VvVkP_Subpass* next;

	int second;

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
#define FREE_OP(op) (\
free((op)->stats.data), \
free((op)->depends.data), \
free(op))

static VvVkP_Graph* create(size_t udatasize) {
	VvVkP_Graph* g = malloc(sizeof(VvVkP_Graph));
	*g = (VvVkP_Graph){
		.size=udatasize,
		.stats.begin = NULL, .stats.end = NULL,
		.subs.begin = NULL, .subs.end = NULL,
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

	VvVkP_Subpass* sub = g->subs.begin;
	while(sub && sub->next) {
		sub = sub->next;
		FREE_OP(sub->prev);
	}
	FREE_OP(sub);

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

static void insertSub(VvVkP_Graph* g, VvVkP_Subpass* op) {
	int missing = op->depends.cnt;
	VvVkP_Subpass* before = g->subs.begin;
	while(missing > 0 && before != NULL) {
		for(int i=0; i < op->depends.cnt; i++)
			if(op->depends.data[i].op == before)
				missing--;
		before = before->next;
	}
	if(missing > 0) {
		fprintf(stderr, "Error in insertOp!\n");
		return;
	}
	if(before == NULL) {	// i.e. we reached the end
		if(g->subs.end) g->subs.end->next = op;
		op->prev = g->subs.end;
		op->next = NULL;
		g->subs.end = op;
		if(!g->subs.begin) g->subs.begin = op;	// If empty...
	} else if(before == g->subs.begin) {	// i.e. we just began
		before->prev = op;
		op->next = before;
		op->prev = NULL;
		g->subs.begin = op;
	} else {	// Somewhere in the middle
		op->prev = before->prev;
		before->prev->next = op;
		op->next = before;
		before->prev = op;
	}
}

static VvVkP_Subpass* addSub(VvVkP_Graph* g, void* udata, int second,
	int sc, VvVkP_State** ss,
	int dc, const VvVkP_Dependency* ds) {

	VvVkP_Subpass* op = malloc(sizeof(VvVkP_Subpass) + g->size);
	*op = (VvVkP_Subpass){
		.second = second,
		.stats.cnt = sc, .stats.data = NULL,
		.depends.cnt = dc, .depends.data = NULL,
	};
	memcpy(op->udata, udata, g->size);

	if(sc > 0) {
		op->stats.data = malloc(sc*sizeof(VvVkP_State*));
		memcpy(op->stats.data, ss, sc*sizeof(VvVkP_State*));
	}
	if(dc > 0) {
		op->depends.data = malloc(dc*sizeof(VvVkP_Dependency));
		memcpy(op->depends.data, ds, dc*sizeof(VvVkP_Dependency));
	}

	insertSub(g, op);
	return op;
}

static void rmSub(VvVkP_Graph* g, VvVkP_Subpass* op) {
	if(op == g->subs.begin) g->subs.begin = op->next;
	if(op == g->subs.end) g->subs.end = op->prev;
	if(op->prev) op->prev->next = op->next;
	if(op->next) op->next->prev = op->prev;
	FREE_OP(op);
}

static void depends(VvVkP_Graph* g, VvVkP_Subpass* op,
	int dc, const VvVkP_Dependency* ds) {

	// First, we take the op out of the list
	if(op == g->subs.begin) g->subs.begin = op->next;
	if(op == g->subs.end) g->subs.end = op->prev;
	if(op->prev) op->prev->next = op->next;
	if(op->next) op->next->prev = op->prev;

	// Then we expand depends.data
	op->depends.data = realloc(op->depends.data,
		(dc + op->depends.cnt)*sizeof(VvVkP_Dependency));
	memcpy(&op->depends.data[op->depends.cnt], ds,
		dc*sizeof(VvVkP_Dependency));
	op->depends.cnt += dc;

	// Then we add it back in
	insertSub(g, op);
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

	for(VvVkP_Subpass* c = g->subs.begin; c; c = c->next) {
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

		// Now execute the Subpass
		if(cmd) cmd(vk, c->udata, cbuff);
	}

	// Now unset all the extra States
	for(int i=0; i<statcnt; i++) {
		if(setting[i])
			uset(vk, stats[i]->udata, cbuff);
	}
}

VvAPI const Vv_VulkanPipeline vVvkp_test = {
	.create = create, .destroy = destroy,
	.addState = addSt,
	.addSubpass = addSub, .removeSubpass = rmSub, .addDepends = depends,
	.execute = exec,
};

#endif // Vv_ENABLE_VULKAN
