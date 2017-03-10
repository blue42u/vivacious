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

#ifndef H_vivacious_vkpipeline
#define H_vivacious_vkpipeline

#include <vivacious/core.h>
#include <vivacious/vulkan.h>

// The entire Graph, which holds the dependancy info for Subpasss and
// States.
_Vv_TYPEDEF(VvVkP_Graph);

// An atomic (may be single) Subpass. Just a handle into the appropriate Graph.
_Vv_TYPEDEF(VvVkP_Subpass);

// A State in which a Subpass may be executed.
_Vv_TYPEDEF(VvVkP_State);

// A description of a dependency on another Subpass. Intended to reflect
// VkSubpassDependency, but with Subpasss instead of indices.
_Vv_STRUCT(VvVkP_Dependency) {
	// The Subpass to depend on.
	VvVkP_Subpass* subpass;

	// The specific stages of <op> and the "dst" Op which are affected.
	VkPipelineStageFlags srcStage;
	VkPipelineStageFlags dstStage;

	// The specific types of memory access which are affected.
	VkAccessFlags srcAccess;
	VkAccessFlags dstAccess;

	// Any other flags for the Dependency.
	VkDependencyFlags flags;
};

_Vv_STRUCT(Vv_VulkanPipeline) {
	// Create a new Graph. Starts out very empty.
	// Every Subpass and State has a piece of udata, which is <udatasize>
	// large. This is for use in `execute` later.
	VvVkP_Graph* (*create)(size_t udatasize);

	// Destroy a Graph, cleaning up all the little extra bits.
	void (*destroy)(VvVkP_Graph*);

	// Add a State to the Graph, with some udata. See `addSubpass`.
	VvVkP_State* (*addState)(VvVkP_Graph*, void* udata);

	// Add a Subpass to the Graph, complete with some dependancies.
	// <udata> should point to a block of <udatasize> which is copied and
	// stored as part of the Subpass.
	// <secondary> indicates whether this Subpass requires the use of
	// VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS.
	VvVkP_Subpass* (*addSubpass)(VvVkP_Graph*, void* udata, int secondary,
		int statecnt, VvVkP_State** states,
		int depcnt, const VvVkP_Dependency* depends);

	// Add more dependencies to a Subpass. For adding things into the middle
	// of the entire pipeline/pass.
	void (*addDepends)(VvVkP_Graph*, VvVkP_Subpass*,
		int depcnt, const VvVkP_Dependency* depends);

	// Remove a Subpass from the Graph. Since its not needed anymore, I see.
	void (*removeSubpass)(VvVkP_Graph*, VvVkP_Subpass*);

	// Copy a list of all the udata's for all the States in the Graph. This
	// may not include all unused States. Return value should be freed by
	// the application.
	// const for multithreading.
	void* (*getStates)(const VvVkP_Graph*, int* cnt);

	// Copy a list of all the udata's for all the Subpasss in the Graph.
	// Return value should be freed by the application.
	// const for multithreading.
	void* (*getSubpasses)(const VvVkP_Graph*, int* cnt);

	// Compile out the list of subpass dependencies. Subpass indices are
	// the same as indicies from `getSubpasses`. Return freed by app.
	// const for multithreading.
	VkSubpassDependency* (*getDepends)(const VvVkP_Graph*, uint32_t* cnt);

	// Execute the proper Vulkan calls from `vkBeginRenderPass` to `End`,
	// using the handlers to convert the Subpasss and States to commands.
	// const to allow for multithreading.
	// <set> is called to set a State, <uset> to unset a State,
	// and <cmd> to execute a Subpass.
	// No Subpass should be executed with more than its States set.
	void (*execute)(const VvVkP_Graph*, const VvVk_Binding*,
		VkCommandBuffer, const VkRenderPassBeginInfo*,
		void (*set)(const VvVk_Binding*, void* udata, VkCommandBuffer),
		void (*uset)(const VvVk_Binding*, void* udata, VkCommandBuffer),
		void (*cmd)(const VvVk_Binding*, void* udata, VkCommandBuffer));
};

// Test TEST, test test Test.
extern const Vv_VulkanPipeline vVvkp_test;

#endif // H_vivacious_vkpipeline
