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

struct VvVkP_Builder {
	const VvVk_Binding* vk;
	struct {
		uint32_t cnt;
		VkAttachmentDescription* data;
	} attach;

	// Doubly-linked list for the Scopes.
	struct {
		VvVkP_Scope* begin;
		VvVkP_Scope* end;
	} sps;

	// Doubly-linked list for the Operations.
	struct {
		VvVkP_Operation* begin;
		VvVkP_Operation* end;
	} ops;
};

struct VvVkP_Scope {
	VvVkP_Scope* prev;
	VvVkP_Scope* next;

	struct {
		void (*begin)(void*, VkCommandBuffer);
		void (*end)(void*, VkCommandBuffer);
		void* udata;
	} funcs;

	VkBool32 sublocal;
	int level;
};

struct VvVkP_Operation {
	VvVkP_Operation* prev;
	VvVkP_Operation* next;

	struct {
		VkResult (*init)(void*, const VkCommandBufferInheritanceInfo*);
		void (*func)(void*, VkCommandBuffer);
		void* udata;
	} funcs;

	struct {
		int cnt;
		VvVkP_Scope* data;
	} sps;

	struct {
		int cnt;
		VvVkP_Dependency* data;
	} depends;
};
#define FREE_OP(op) (\
free((op)->sps.data), \
free((op)->depends.data), \
free(op))

static VvVkP_Builder* create(const VvVk_Binding* vk, uint32_t acnt,
	const VkAttachmentDescription* as) {

	VvVkP_Builder* b = malloc(sizeof(VvVkP_Builder));
	*b = (VvVkP_Builder){
		.vk = vk,
		.attach.cnt = acnt,
		.attach.data = malloc(acnt * sizeof(VkAttachmentDescription)),
		.sps.begin = NULL, .sps.end = NULL,
		.ops.begin = NULL, .ops.end = NULL,
	};
	memcpy(b->attach.data, as, acnt * sizeof(VkAttachmentDescription));
	return b;
}

static void destroy(VvVkP_Builder* b) {
	free(b->attach.data);

	VvVkP_Scope* scop = b->sps.begin;
	while(scop && scop->next) {
		scop = scop->next;
		free(scop->prev);
	}
	free(scop);

	VvVkP_Operation* op = b->ops.begin;
	while(op && op->next) {
		op = op->next;
		FREE_OP(op->prev);
	}
	FREE_OP(op);

	free(b);
}

static VvVkP_Scope* addSp(VvVkP_Builder* b,
	void (*begin)(void*, VkCommandBuffer),
	void (*end)(void*, VkCommandBuffer),
	void* udata,
	VkBool32 sublocal, int level) {

	VvVkP_Scope* sp = malloc(sizeof(VvVkP_Scope));
	*sp = (VvVkP_Scope){
		.sublocal = sublocal, .level = level,
		.funcs.begin = begin, .funcs.end = end, .funcs.udata = udata,
		.prev = b->sps.end, .next = NULL,
	};
	if(!b->sps.begin) b->sps.begin = sp;
	if(b->sps.end) b->sps.end->next = sp;
	b->sps.end = sp;
	return sp;
}

static void rmSp(VvVkP_Builder* b, VvVkP_Scope* sp) {
	if(sp == b->sps.begin) b->sps.begin = sp->next;
	if(sp == b->sps.end) b->sps.end = sp->prev;
	if(sp->prev) sp->prev->next = sp->next;
	if(sp->next) sp->next->prev = sp->prev;
	free(sp);
}

static void insertOp(VvVkP_Builder* b, VvVkP_Operation* op) {
	int missing = op->depends.cnt;
	VvVkP_Operation* before = b->ops.begin;
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
		if(b->ops.end) b->ops.end->next = op;
		op->prev = b->ops.end;
		op->next = NULL;
		b->ops.end = op;
		if(!b->ops.begin) b->ops.begin = op;	// If empty...
	} else if(before == b->ops.begin) {	// i.e. we just began
		before->prev = op;
		op->next = before;
		op->prev = NULL;
		b->ops.begin = op;
	} else {	// Somewhere in the middle
		op->prev = before->prev;
		before->prev->next = op;
		op->next = before;
		before->prev = op;
	}
}

static VvVkP_Operation* addOp(VvVkP_Builder* b,
	VkResult (*init)(void*, const VkCommandBufferInheritanceInfo*),
	void (*func)(void*, VkCommandBuffer),
	void* udata,
	int sc, VvVkP_Scope** ss,
	int dc, const VvVkP_Dependency* ds) {

	VvVkP_Operation* op = malloc(sizeof(VvVkP_Operation));
	*op = (VvVkP_Operation){
		.funcs.init = init, .funcs.func = func, .funcs.udata = udata,
		.sps.cnt = sc, .sps.data = NULL,
		.depends.cnt = dc, .depends.data = NULL,
	};

	if(sc > 0) {
		op->sps.data = malloc(sc*sizeof(VvVkP_Scope*));
		memcpy(op->sps.data, ss, sc*sizeof(VvVkP_Scope*));
	}
	if(dc > 0) {
		op->depends.data = malloc(dc*sizeof(VvVkP_Dependency));
		memcpy(op->depends.data, ds, dc*sizeof(VvVkP_Dependency));
	}

	insertOp(b, op);
	return op;
}

static void rmOp(VvVkP_Builder* b, VvVkP_Operation* op) {
	if(op == b->ops.begin) b->ops.begin = op->next;
	if(op == b->ops.end) b->ops.end = op->prev;
	if(op->prev) op->prev->next = op->next;
	if(op->next) op->next->prev = op->prev;
	FREE_OP(op);
}

static void depends(VvVkP_Builder* b, VvVkP_Operation* op, int dc,
	const VvVkP_Dependency* ds) {

	// First, we take the op out of the list
	if(op == b->ops.begin) b->ops.begin = op->next;
	if(op == b->ops.end) b->ops.end = op->prev;
	if(op->prev) op->prev->next = op->next;
	if(op->next) op->next->prev = op->prev;

	// Then we expand depends.data
	op->depends.data = realloc(op->depends.data,
		(dc + op->depends.cnt)*sizeof(VvVkP_Dependency));
	memcpy(&op->depends.data[op->depends.cnt], ds,
		dc*sizeof(VvVkP_Dependency));
	op->depends.cnt += dc;

	// Then we add it back in
	insertOp(b, op);
}

VvAPI const Vv_VulkanPipeline vVvkp_test = {
	.create = create, .destroy = destroy,
	.addScope = addSp, .removeScope = rmSp,
	.addOperation = addOp, .removeOperation = rmOp,
	.depends = depends,
};

#endif // Vv_ENABLE_VULKAN
