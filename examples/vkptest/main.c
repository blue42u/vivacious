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

#include "common.h"

VkRenderPass rpass;

typedef struct {
	char name[100];
	uint32_t id;
} UData;

void enter(const VvVk_Binding* vkb, void* udata, VkCommandBuffer cb) {
	UData* ud = udata;
	printf("Setting State %s!\n", ud->name);
	vk->CmdPushConstants(cb, playout,
		VK_SHADER_STAGE_VERTEX_BIT,
		0, sizeof(uint32_t), &ud->id);
}

void inside(const VvVk_Binding* vkb, void* udata, VkCommandBuffer cb) {
	UData* ud = udata;
	printf("Executing Step %s!\n", ud->name);
	vk->CmdDraw(cb, 3, 1, 0, ud->id);
}

#define STAGE VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT

#define addSp(DATA, SCOPES, DEPENDS) ({ \
	VvVkP_State* _stats[] = SCOPES; \
	VvVkP_Dependency _deps[] = DEPENDS; \
	for(int i=0; i<sizeof(_deps)/sizeof(_deps[0]); i++) { \
		_deps[i].srcStage = STAGE; \
		_deps[i].dstStage = STAGE; \
	} \
	vkp.addStep(g, &(UData)DATA, 0, \
		sizeof(_stats)/sizeof(VvVkP_State*), _stats, \
		sizeof(_deps)/sizeof(VvVkP_Dependency), _deps); \
})

int main() {
	setupVk();
	setupWin();
	setupSChain();
	setupCb();

	VkResult r;

	VvVkP_Graph* g = vkp.create(sizeof(UData));

	VvVkP_State* stats[] = {
		vkp.addState(g, &(UData){ "1", 0 }),
		vkp.addState(g, &(UData){ "2", 1 }),
	};

	VvVkP_Step* steps[4];
	steps[0] = addSp({"1:1"}, { stats[0] }, {});
	steps[1] = addSp({"1:2"}, { stats[0] }, { steps[0] });
	steps[2] = addSp({"2:1"}, { stats[1] }, { steps[0] });
	steps[3] = addSp({"2:2"}, { stats[1] }, { steps[2] });

	vkp.addDepends(g, steps[2],
		2, (VvVkP_Dependency[]){
			{steps[0],STAGE,STAGE},
			{steps[1],STAGE,STAGE}
		});
	vkp.removeStep(g, steps[3]);

	int subcnt;
	UData* udsteps = vkp.getSteps(g, &subcnt);
	VkSubpassDescription subdes[subcnt];
	for(int i=0; i<subcnt; i++) {
		subdes[i] = (VkSubpassDescription){
			0, VK_PIPELINE_BIND_POINT_GRAPHICS,
			0, NULL,
			1, (VkAttachmentReference[]){
				{0, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL },
			}, NULL,
			NULL,
			0, NULL,
		};
	}
	free(udsteps);

	uint32_t depcnt;
	VkSubpassDependency* deps = vkp.getDepends(g, &depcnt);
	r = vk->CreateRenderPass(dev, &(VkRenderPassCreateInfo){
		VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO, NULL,
		.attachmentCount = 1,
		.pAttachments = (VkAttachmentDescription[]){
			{
				.format = format,
				.samples = VK_SAMPLE_COUNT_1_BIT,
				.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
				.storeOp = VK_ATTACHMENT_STORE_OP_STORE,
				.initialLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
				.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
			},
		},
		.subpassCount = subcnt, .pSubpasses = subdes,
		.dependencyCount = depcnt, .pDependencies = deps,
	}, NULL, &rpass);
	if(r<0) error("creating RenderPass", r);
	free(deps);

	setupFBuff();
	setupPipeline();

	for(int i=0; i<imageCount; i++) {
		r = vk->BeginCommandBuffer(cbs[i], &(VkCommandBufferBeginInfo){
			VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO, NULL,
			.pInheritanceInfo = NULL,
		});
		if(r<0) error("starting CommandBuffer", r);

		vk->CmdBindPipeline(cbs[i], VK_PIPELINE_BIND_POINT_GRAPHICS,
			pipeline);

		vkp.execute(g, &vkbind, cbs[i], &(VkRenderPassBeginInfo){
			VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO, NULL,
			.renderPass = rpass, .framebuffer = fbuffs[i],
			.renderArea = { .offset = {0,0}, .extent = extent, },
			.clearValueCount = 1, .pClearValues = (VkClearValue[]){
				{},
			},
		}, enter, NULL, inside);

		vk->EndCommandBuffer(cbs[i]);
	}

	cleanupPipeline();
	cleanupFBuff();

	vk->DestroyRenderPass(dev, rpass, NULL);
	vkp.destroy(g);

	cleanupCb();
	cleanupSChain();
	cleanupWin();
	cleanupVk();
	return 0;
}
