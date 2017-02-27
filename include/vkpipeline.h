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

// The entire Graph, which holds the dependancy info for Commands and
// States.
_Vv_TYPEDEF(VvVkP_Graph);

// An atomic (may be single) Command. Just a handle into the appropriate Graph.
_Vv_TYPEDEF(VvVkP_Command);

// A State in which a Command may be executed.
_Vv_TYPEDEF(VvVkP_State);

// A description of a dependency on another Command. Intended to reflect
// VkSubpassDependency, but with Commands instead of indices.
_Vv_STRUCT(VvVkP_Dependency) {
	// The Command to depend on.
	VvVkP_Command* op;

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
	// Every Command and State has a piece of udata, which is <udatasize>
	// large. This is for use in `execute` later.
	VvVkP_Graph* (*create)(size_t udatasize);

	// Destroy a Graph, cleaning up all the little extra bits.
	void (*destroy)(VvVkP_Graph*);

	// Add a State to the Graph, with some udata. See `addCommand`.
	VvVkP_State* (*addState)(VvVkP_Graph*, void* udata);

	// Add a Command to the Graph, complete with some dependancies.
	// <udata> should point to a block of <udatasize> which is copied and
	// stored as part of the Command.
	// <secondary> indicates whether this Command needs to be in a
	// VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS subpass.
	VvVkP_Command* (*addCommand)(VvVkP_Graph*, void* udata, int secondary,
		int statecnt, VvVkP_State** states,
		int depcnt, const VvVkP_Dependency* depends);

	// Add more dependencies to a Command. For adding things into the middle
	// of the entire pipeline/pass.
	void (*addDepends)(VvVkP_Graph*, VvVkP_Command*,
		int depcnt, const VvVkP_Dependency* depends);

	// Remove a Command from the Graph. Since its not needed anymore, I see.
	void (*removeCommand)(VvVkP_Graph*, VvVkP_Command*);

	// Create a VkRenderPass from the Graph, which is designed to work as
	// expected when used in `execute`. <subpassCount>, <pSubpasses>,
	// <dependencyCount>, and <pDependencies> are ignored in <info>.
	// const to allow for multithreading.
	VkRenderPass (*compile)(const VvVkP_Graph*, const VvVk_Binding*,
		const VkRenderPassCreateInfo* info);

	// Execute the proper Vulkan calls from `vkBeginRenderPass` to `End`,
	// using the handlers to convert the Commands and States to commands.
	// const to allow for multithreading.
	// <set> is called to set a State, <uset> to unset a State,
	// and <cmd> to execute a Command.
	// No Command should be executed with more than its States set.
	void (*execute)(const VvVkP_Graph*, const VvVk_Binding*,
		const VkRenderPassBeginInfo*,
		void (*set)(const VvVk_Binding*, void* udata, VkCommandBuffer),
		void (*uset)(const VvVk_Binding*, void* udata, VkCommandBuffer),
		void (*cmd)(const VvVk_Binding*, void* udata, VkCommandBuffer));
};

// Test TEST, test test Test.
extern const Vv_VulkanPipeline vVvkp_test;

#endif // H_vivacious_vkpipeline
