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
	} scopes;

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
	} scopes;

	struct {
		int cnt;
		VvVkP_Dependency* data;
	} depends;
};

VvVkP_Builder* create(const VvVk_Binding* vk, uint32_t acnt,
	const VkAttachmentDescription* as) {

	VvVkP_Builder* b = malloc(sizeof(VvVkP_Builder));
	*b = (VvVkP_Builder){
		.vk = vk,
		.attach.cnt = acnt,
		.attach.data = malloc(acnt * sizeof(VkAttachmentDescription)),
		.scopes.begin = NULL, .scopes.end = NULL,
		.ops.begin = NULL, .ops.end = NULL,
	};
	memcpy(b->attach.data, as, acnt * sizeof(VkAttachmentDescription));
	return b;
}

void destroy(VvVkP_Builder* b) {
	free(b->attach.data);

	VvVkP_Scope* scop = b->scopes.begin;
	while(scop && scop->next) {
		scop = scop->next;
		free(scop->prev);
	}
	free(scop);

	VvVkP_Operation* op = b->ops.begin;
	while(op && op->next) {
		op = op->next;
		free(op->prev);
	}
	free(op);

	free(b);
}

VvAPI const Vv_VulkanPipeline vVvkp_test = {
	.create = create, .destroy = destroy,
};

#endif // Vv_ENABLE_VULKAN
