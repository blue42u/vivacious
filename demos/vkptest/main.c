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
#include <vivacious/vivacious.h>
#include <time.h>

Vv V;

VkRenderPass rpass;

typedef struct {
	char name[100];
	uint32_t id;
} UData;

void enter(void* xx, void* udata, VkCommandBuffer cb) {
	UData* ud = udata;
	printf("Setting State %s!\n", ud->name);
	vVvk_CmdPushConstants(cb, playout,
		VK_SHADER_STAGE_VERTEX_BIT,
		0, sizeof(uint32_t), &ud->id);
}

void inside(void* xx, void* udata, VkCommandBuffer cb) {
	UData* ud = udata;
	printf("Executing Step %s!\n", ud->name);
	vVvk_CmdDraw(cb, 3, 1, 0, ud->id);
}

static VkAttachmentReference arefs[] = {
	{0, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL },
};
VkSubpassDescription spass(void* ud,
	size_t spcnt, void** steps,
	size_t stcnt, void** states) {

	return (VkSubpassDescription){
			0, VK_PIPELINE_BIND_POINT_GRAPHICS,
			0, NULL,
			1, arefs, NULL,
			NULL,
			0, NULL,
	};
}

#define STAGE VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT

#define addSp(DATA, SCOPES, DEPENDS) ({ \
	VvVkP_State* _stats[] = SCOPES; \
	VvVkP_Step* _dsteps[] = DEPENDS; \
	VvVkP_Dependency _deps[Vv_LEN(_dsteps)]; \
	VvVkP_Dependency* _pdeps[Vv_LEN(_deps)]; \
	for(int i=0; i<Vv_LEN(_deps); i++) { \
		_deps[i] = VvVkP_Dependency(.step=_dsteps[i], \
			.srcStage=STAGE, .dstStage=STAGE); \
		_pdeps[i] = &_deps[i]; \
	} \
	vVvkp_addStep(g, &DATA, 0, Vv_LEN(_stats), _stats, \
		Vv_LEN(_pdeps), _pdeps); \
})

int main() {
	V = vV();

	setupVk();
	setupWin();
	setupSChain();
	setupCb();

	VkResult r;

	// Create the vV Graph for this
	VvVkP_Graph* g = vVvkp_create();

	VvVkP_State* stats[] = {
		vVvkp_addState(g, &(UData){ "1", 0 }, 0),
		vVvkp_addState(g, &(UData){ "2", 1 }, 0),
	};

	VvVkP_Step* steps[4];
	steps[0] = addSp(((UData){"1:1", 0}), { stats[0] }, {});
	steps[2] = addSp(((UData){"2:1", 0}), { stats[1] }, { steps[0] });
	steps[1] = addSp(((UData){"1:2", 1}), { stats[0] }, { steps[0] });
	steps[3] = addSp(((UData){"2:2", 1}), { stats[1] }, { steps[2] });

	VvVkP_Dependency edeps[] = {
		VvVkP_Dependency(.step=steps[0],.srcStage=STAGE,.dstStage=STAGE),
		VvVkP_Dependency(.step=steps[1],.srcStage=STAGE,.dstStage=STAGE),
	};
	vVvkp_addDepends(g, steps[2],
		2, (VvVkP_Dependency*[]){&edeps[0], &edeps[1]});
	//vVvkp_removeStep(g, steps[3]);

	// Get the RenderPass
	rpass = vVvkp_getRenderPass(g, dev,
		1, (VkAttachmentDescription[]){
			{
				.format = format,
				.samples = VK_SAMPLE_COUNT_1_BIT,
				.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
				.storeOp = VK_ATTACHMENT_STORE_OP_STORE,
				.initialLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
				.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
			},
		}, spass, NULL, &r);
	if(!rpass) error("creating RenderPass", r);

	setupFBuff();
	setupPipeline();

	// Record the CommandBuffers
	for(int i=0; i<imageCount; i++) {
		r = vVvk_BeginCommandBuffer(cbs[i], &(VkCommandBufferBeginInfo){
			VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO, NULL,
			.pInheritanceInfo = NULL,
		});
		if(r<0) error("starting CommandBuffer", r);

		vVvk_CmdBindPipeline(cbs[i], VK_PIPELINE_BIND_POINT_GRAPHICS,
			pipeline);

		vVvkp_record(g, cbs[i], &(VkRenderPassBeginInfo){
			VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO, NULL,
			.renderPass = rpass, .framebuffer = fbuffs[i],
			.renderArea = { .offset = {0,0}, .extent = extent, },
			.clearValueCount = 1, .pClearValues = (VkClearValue[]){
				{.color={.float32={.01,.03,.05,1}}},
			},
		}, &images[i], enter, NULL, NULL, NULL, inside, NULL);

		vVvk_EndCommandBuffer(cbs[i]);

		r = vVvk_BeginCommandBuffer(cbi[i], &(VkCommandBufferBeginInfo){
			VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO, NULL,
			.pInheritanceInfo = NULL,
		});
		if(r<0) error("starting CommandBuffer", r);
		vVvk_CmdPipelineBarrier(cbi[i],
			VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
			VK_PIPELINE_STAGE_ALL_GRAPHICS_BIT,
			0,
			0, NULL,
			0, NULL,
			1, (VkImageMemoryBarrier[]) { {
				VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, NULL,
				VK_ACCESS_HOST_WRITE_BIT,
				VK_ACCESS_MEMORY_WRITE_BIT,
				VK_IMAGE_LAYOUT_UNDEFINED,
				VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
				VK_QUEUE_FAMILY_IGNORED,
				VK_QUEUE_FAMILY_IGNORED,
				images[i],
				{ VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1, },
			} });
		vVvk_EndCommandBuffer(cbi[i]);
	}

	VkSemaphore draw, pres;
	{
		VkSemaphoreCreateInfo sci = {
			VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO, NULL,
		};
		r = vVvk_CreateSemaphore(dev, &sci, NULL, &draw);
		if(r<0) error("creating semaphore", r);
		r = vVvk_CreateSemaphore(dev, &sci, NULL, &pres);
		if(r<0) error("creating semaphore", r);
	}

	VkFence fences[imageCount];
	int used[imageCount];
	for(int i=0; i<imageCount; i++) {
		vVvk_CreateFence(dev, &(VkFenceCreateInfo){
			VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, NULL,
			.flags = VK_FENCE_CREATE_SIGNALED_BIT,
		}, NULL, &fences[i]);
		used[i] = 0;
	}

	time_t start = time(NULL);
	while(difftime(time(NULL), start) < 3) {
		uint32_t index;
		r = vVvk_AcquireNextImageKHR(dev, schain, UINT64_MAX,
			draw, NULL, &index);
		if(r<0) error("acquiring image", r);

		r = vVvk_WaitForFences(dev, 1, &fences[index],
			VK_TRUE, UINT64_MAX);
		if(r<0) error("waiting for a fence", r);

		r = vVvk_ResetFences(dev, 1, &fences[index]);
		if(r<0) error("resetting a fence", r);

		r = vVvk_QueueSubmit(q, 1, (VkSubmitInfo[]){ {
			VK_STRUCTURE_TYPE_SUBMIT_INFO, NULL,
			.waitSemaphoreCount = 1, .pWaitSemaphores = &draw,
			.pWaitDstStageMask = (VkPipelineStageFlags[]){
				VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
			},
			.commandBufferCount = used[index] ? 1 : 2,
			.pCommandBuffers = (VkCommandBuffer[]){
				cbi[index], cbs[index],
			},
			.signalSemaphoreCount = 1, .pSignalSemaphores = &pres,
		} }, fences[index]);
		if(r<0) error("submitting", r);

		used[index] = 1;

		vVvk_QueuePresentKHR(q, (VkPresentInfoKHR[]){ {
			VK_STRUCTURE_TYPE_PRESENT_INFO_KHR, NULL,
			.waitSemaphoreCount = 1, .pWaitSemaphores = &pres,
			.swapchainCount = 1, .pSwapchains = &schain,
			.pImageIndices = &index,
			.pResults = NULL
		} });
		if(r<0) error("presenting", r);
	}

	r = vVvk_WaitForFences(dev, imageCount, fences, VK_TRUE, UINT64_MAX);
	if(r<0) error("waiting for fences", r);

	vVvk_DestroySemaphore(dev, draw, NULL);
	vVvk_DestroySemaphore(dev, pres, NULL);
	for(int i=0; i<imageCount; i++)
		vVvk_DestroyFence(dev, fences[i], NULL);

	cleanupPipeline();
	cleanupFBuff();

	vVvkp_destroy(g);

	cleanupCb();
	cleanupSChain();
	cleanupWin();
	cleanupVk();
	return 0;
}