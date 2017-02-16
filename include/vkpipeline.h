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

// The main structure, which holds the overarching framework.
_Vv_TYPEDEF(VvVkP_Builder);

// A handle for a single operation (or "step") in the workload.
_Vv_TYPEDEF(VvVkP_Operation);

// A handle for a context which changes the function of Operations. In
// particular, these allow the implemenation to optimize state changes.
_Vv_TYPEDEF(VvVkP_Scope);

// A description of a dependency on another Operation. Intended to reflect
// VkSubpassDependency, but with Operations instead of indices.
_Vv_STRUCT(VvVkP_Dependency) {
	// The Operation to depend on.
	VvVkP_Operation* op;

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
	// Create a new Builder
	VvVkP_Builder* (*create)(const VvVk_Binding*,
		uint32_t attachCount, const VkAttachmentDescription* attaches);

	// Destroy a Builder
	void (*destroy)(VvVkP_Builder*);

	// Add a custom Scope to a Builder. <begin> is called before any
	// commands from Operations with this Scope. Similarly,
	// <end> (if not NULL) is called after all commands in this Scope.
	// <subpasslocal> indicates whether <begin> and <end> must be called
	// in the same subpass of the VkRenderPass.
	// Scopes with the same <level> cannot overlap.
	VvVkP_Scope* (*addScope)(VvVkP_Builder*,
		void (*begin)(void* userdata, VkCommandBuffer),
		void (*end)(void* userdata, VkCommandBuffer),
		void* userdata,
		VkBool32 subpasslocal,
		int level);

	// Delete a Scope from a Builder. <scope> is invalid after this.
	// `destroy` should implicitly call `removeScope` for all Scopes.
	void (*removeScope)(VvVkP_Builder*, VvVkP_Scope* scope);

	// Add an Operation to a Builder. <func> and <init> will be called
	// during the call to `record`. <scopes> is an array of <scopeCnt>
	// Scopes; <depends> is an array of <dependCnt> Dependencies.
	// If the set of Scopes is impossible to occur, this can return NULL.
	VvVkP_Operation* (*addOperation)(VvVkP_Builder*,
		VkResult (*init)(void* userdata,
			const VkCommandBufferInheritanceInfo* cbii),
		void (*func)(void* userdata, VkCommandBuffer),
		void* userdata,
		int scopeCnt, VvVkP_Scope** scopes,
		int dependCnt, const VvVkP_Dependency* depends);

	// Delete a Scope from a Builder. <op> is invalid after this.
	// `destroy` must implicitly call `removeOperation` for all Operations.
	void (*removeOperation)(VvVkP_Builder*, VvVkP_Operation* op);

	// Add even more Dependencies to an Operation.
	void (*depends)(VvVkP_Builder*, VvVkP_Operation*,
		int cnt, const VvVkP_Dependency* depends);

	// Record the actual VkCommandBuffers to perform the rendering.
	// Before `vkBeginCommandBuffer` is called, the RenderPass should be
	// created, and the <init> for all Operations should be called.
	// Returns the first erroring VkResult from an Operation's <init>, or
	// the VkResult from `vkEndCommandBuffer` if none do.
	// Since the Builder is const here, this operation is threadsafe with
	// respect to the Builder.
	VkResult (*record)(const VvVkP_Builder*, VkCommandBuffer,
		const VkRenderPassBeginInfo* rpbi);

	// Add a pipeline binding Scope to the Builder. This is similar to
	// `addScope(builder, vkCmdBindPipeline, NULL, pipeline, VK_FALSE)`,
	// where <pipeline> is a VkPipeline created in `record`.
	// The <renderPass>, <subpass>, and <basePipelineIndex> fields of
	// <info> should be ignored, and if <basePipelineHandle> is NULL, then
	// the pipeline's base will be the pipeline created by <base>.
	VvVkP_Scope* (*addGraphicsPipeline)(VvVkP_Builder*,
		const VkGraphicsPipelineCreateInfo* info,
		VvVkP_Scope* base);
	VvVkP_Scope* (*addComputePipeline)(VvVkP_Builder*,
		const VkComputePipelineCreateInfo* info,
		VvVkP_Scope* base);
};

// Test TEST, test test Test.
extern const Vv_VulkanPipeline vVvkp_test;

#endif // H_vivacious_vkpipeline
