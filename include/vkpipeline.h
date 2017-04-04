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

// The entire Graph, which holds the dependancy info for Steps and States.
_Vv_TYPEDEF(VvVkP_Graph);

// An atomic (may be single) Step. Just a handle into the appropriate Graph.
_Vv_TYPEDEF(VvVkP_Step);

// A State in which a Step may be executed.
_Vv_TYPEDEF(VvVkP_State);

// A description of a dependency on another Step. Intended to reflect
// VkSubpassDependency, but with Steps instead of subpass indices.
_Vv_STRUCT(VvVkP_Dependency) {
	// The Step to depend on, such that <step> happens-before <self>.
	VvVkP_Step* step;

	// The specific stages of <step> and <self> which are affected.
	VkPipelineStageFlags srcStage;
	VkPipelineStageFlags dstStage;

	// Extra flags to describe the dependency. Note that due to §6.5.1 in
	// Vulkan spec 1.0.38, VK_DEPENDENCY_BY_REGION_BIT may be added
	// when both stages affect framebuffer-space.
	VkDependencyFlags flags;

	// The specific types of memory access which are affected.
	VkAccessFlags srcAccess;
	VkAccessFlags dstAccess;

	// Use an attachment-centered dependency?
	VkBool32 attachmentEnable;
	// Attachment index and range of the dependent memory.
	uint32_t attachment;
	VkImageSubresourceRange attachmentRange;
};

_Vv_STRUCT(Vv_VulkanPipeline) {
	// Create a new Graph. Starts out very empty.
	VvVkP_Graph* (*create)();

	// Destroy a Graph, cleaning up all the little extra bits.
	void (*destroy)(VvVkP_Graph*);

	// Add a State to the Graph. <udata> is passed to the State handlers
	// during `record`, and is returned by `getStates`. If <spassBound> is
	// a true value, then the created State is "subpass-bound", which means
	// that all Steps that use it will occur in one subpass.
	VvVkP_State* (*addState)(VvVkP_Graph*, void* udata, int spassBound);

	// Add a Step to the Graph, complete with some dependancies.
	// <udata> is passed to the Step handler during `record`.
	// <secondary> indicates whether this Step requires the use of
	// VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS.
	// May return NULL if the sets of States or Dependencies are invalid.
	VvVkP_Step* (*addStep)(VvVkP_Graph*, void* udata, int secondary,
		int statecnt, const VvVkP_State** states,
		int depcnt, const VvVkP_Dependency* depends);

	// Add more dependencies to a Step. For adding things into the middle
	// of the entire pipeline/pass.
	void (*addDepends)(VvVkP_Graph*, VvVkP_Step*,
		int depcnt, const VvVkP_Dependency* depends);

	// Remove a Step from the Graph. Since its not needed anymore, I see.
	void (*removeStep)(VvVkP_Graph*, VvVkP_Step*);

	// Get the VkRenderPass from the Graph. When <spass> is called,
	// it is given the list of Steps and subpass-bound States for a
	// particular subpass, and returns the description for that subpass.
	// If NULL is returned, <result> is set to the result from
	// a call to vkCreateRenderPass, or another suitable error.
	VkRenderPass (*getRenderPass)(VvVkP_Graph*, const VvVk_Binding*,
		VkResult* result, VkDevice dev,
		uint32_t attachCount, const VkAttachmentDescription* attaches,
		VkSubpassDescription (*spass)(
			int stepCnt, void** steps,
			int stateCnt, void** states));

	// Copy a list of all the udata's for all the States in the Graph. This
	// may not include all unused States. If <spasses> is not NULL, it will
	// be filled with the corrosponding subpass indicies for subpass-bound
	// States. Return value and <spasses> should be freed by applications.
	// const for multithreading.
	void** (*getStates)(const VvVkP_Graph*, int* cnt, uint32_t** spasses);

	// Copy a list of all the udata's for all the Steps in the Graph.
	// Return value should be freed by the application.
	// const for multithreading.
	void** (*getSteps)(const VvVkP_Graph*, int* cnt);

	// Record an invokation of the VkRenderPass returned by `getRenderPass`.
	// <set> and <uset> are used for recording State transitions, and
	// <cmd> for recording Steps. No Step should be called with a
	// different set of "set" States than specified by `addStep`.
	// <attachments> is the array of Images that were used to create
	// the Framebuffer, used for attachment-based dependencies.
	// const to allow for multithreading.
	void (*record)(const VvVkP_Graph*, const VvVk_Binding*,
		VkCommandBuffer, const VkRenderPassBeginInfo*,
		VkImage* attachments,
		void (*set)(const VvVk_Binding*, void* udata, VkCommandBuffer),
		void (*uset)(const VvVk_Binding*, void* udata, VkCommandBuffer),
		void (*cmd)(const VvVk_Binding*, void* udata, VkCommandBuffer));
};

// Test TEST, test test Test.
extern const Vv_VulkanPipeline vVvkp_test;

#endif // H_vivacious_vkpipeline
