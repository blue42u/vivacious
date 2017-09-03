--[========================================================================[
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
--]========================================================================]

io.output(arg[1])
local function out(s) io.write(s..'\n') end

out([[
#include "common.h"

static uint32_t vertShader[] = {]])

for word in io.lines('vert.spv', 4) do
	out(string.unpack('<I4', word)..',')
end

out([[
};

static uint32_t fragShader[] = {]])

for word in io.lines('frag.spv', 4) do
	out(string.unpack('<I4', word)..',')
end

out([[
};

VkPipeline pipeline;
VkPipelineLayout playout;
static VkShaderModule vert, frag;

void setupPipeline() {
	VkResult r;

	r = vVvk_CreateShaderModule(dev, &(VkShaderModuleCreateInfo){
		VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO, NULL,
		.codeSize = sizeof(vertShader),
		.pCode = vertShader,
	}, NULL, &vert);
	if(r<0) error("loading vert shader", r);

	r = vVvk_CreateShaderModule(dev, &(VkShaderModuleCreateInfo){
		VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO, NULL,
		.codeSize = sizeof(fragShader),
		.pCode = fragShader,
	}, NULL, &frag);
	if(r<0) error("loading frag shader", r);

	r = vVvk_CreatePipelineLayout(dev, &(VkPipelineLayoutCreateInfo){
		VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO, NULL,
		.setLayoutCount = 0, .pSetLayouts = NULL,
		.pushConstantRangeCount = 1,
		.pPushConstantRanges = (VkPushConstantRange[]){ {
			.stageFlags = VK_SHADER_STAGE_VERTEX_BIT,
			.offset = 0, .size = sizeof(uint32_t),
		}, },
	}, NULL, &playout);
	if(r<0) error("creating pipeline layout", r);

	r = vVvk_CreateGraphicsPipelines(dev, NULL, 1, &(VkGraphicsPipelineCreateInfo){
		VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO, NULL,
		.stageCount=2, .pStages=(VkPipelineShaderStageCreateInfo[]){
			{ VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
				NULL,
				.stage = VK_SHADER_STAGE_VERTEX_BIT,
				.module = vert, .pName = "main",
				.pSpecializationInfo = NULL,
			},
			{ VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
				NULL,
				.stage = VK_SHADER_STAGE_FRAGMENT_BIT,
				.module = frag, .pName = "main",
				.pSpecializationInfo = NULL,
			},
		},
		.pVertexInputState = &(VkPipelineVertexInputStateCreateInfo){
			VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
			NULL,
			.vertexBindingDescriptionCount=0,
			.pVertexBindingDescriptions = NULL,
			.vertexAttributeDescriptionCount=0,
			.pVertexAttributeDescriptions=NULL,
		},
		.pInputAssemblyState = &(VkPipelineInputAssemblyStateCreateInfo){
			VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
			NULL,
			.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
			.primitiveRestartEnable = VK_FALSE,
		},
		.pTessellationState = NULL,
		.pViewportState = &(VkPipelineViewportStateCreateInfo){
			VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
			NULL,
			.viewportCount = 1, .pViewports = (VkViewport[]){
				{0, 0, extent.width, extent.height, -1, 1}},
			.scissorCount=1, .pScissors = (VkRect2D[]){
				{.extent=extent, .offset={0,0}} },
		},
		.pRasterizationState = &(VkPipelineRasterizationStateCreateInfo){
			VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
			NULL,
			.depthClampEnable = VK_FALSE,
			.rasterizerDiscardEnable = VK_FALSE,
			.polygonMode = VK_POLYGON_MODE_FILL,
			.cullMode = 0,	// No culling, too much pain
			.frontFace = VK_FRONT_FACE_CLOCKWISE,
			.depthBiasEnable = VK_FALSE,
			.lineWidth = 1,
		},
		.pMultisampleState = &(VkPipelineMultisampleStateCreateInfo){
			VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
			NULL,
			.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT,
			.sampleShadingEnable = VK_FALSE, // No point here
			.minSampleShading = 0,
			.pSampleMask = NULL,
			.alphaToCoverageEnable = VK_FALSE,
			.alphaToOneEnable = VK_FALSE,
		},
		.pDepthStencilState = NULL,
		.pColorBlendState = &(VkPipelineColorBlendStateCreateInfo){
			VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
			NULL,
			.logicOpEnable = VK_FALSE,
			.attachmentCount = 1,
			.pAttachments = (VkPipelineColorBlendAttachmentState[]){
				{
					.blendEnable = VK_FALSE,
					.colorWriteMask=
						VK_COLOR_COMPONENT_R_BIT |
						VK_COLOR_COMPONENT_G_BIT |
						VK_COLOR_COMPONENT_B_BIT |
						VK_COLOR_COMPONENT_A_BIT
				},
			},
		},
		.pDynamicState = NULL,
		.layout = playout,
		.renderPass = rpass, .subpass = 0,
	}, NULL, &pipeline);
	if(r<0) error("creating pipeline", r);
}

void cleanupPipeline() {
	vVvk_DestroyPipeline(dev, pipeline, NULL);
	vVvk_DestroyPipelineLayout(dev, playout, NULL);
	vVvk_DestroyShaderModule(dev, vert, NULL);
	vVvk_DestroyShaderModule(dev, frag, NULL);
}
]])
