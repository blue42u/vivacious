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

// TMP
#include <unistd.h>

int main() {
	loadVulkan();
	createInst();
	startDebug();
	createWindow();
	createDev();
	createSChain();
	createCBuffs();

	printf("Alright, begin!\n");

	VkCommandBufferBeginInfo cbbi = {
		VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO, NULL,
		VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT,
		NULL,
	};
	VkClearColorValue blue = {
		.float32 = {0.0, 0.25, 1.0, 1.0},
	};
	VkClearColorValue red = {
		.float32 = {1.0, 0.25, 0.125, 1.0},
	};
	VkImageSubresourceRange isr = {
		VK_IMAGE_ASPECT_COLOR_BIT,
		0, 1, 0, 1,
	};
	for(int im=0; im<com.simagecnt; im++) {
		vVvk_BeginCommandBuffer(com.cb[im].blue, &cbbi);
		vVvk_CmdClearColorImage(com.cb[im].blue, com.simages[im],
			VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, &blue,
			1, &isr);
		vVvk_EndCommandBuffer(com.cb[im].blue);

		vVvk_BeginCommandBuffer(com.cb[im].red, &cbbi);
		vVvk_CmdClearColorImage(com.cb[im].red, com.simages[im],
			VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, &red,
			1, &isr);
		vVvk_EndCommandBuffer(com.cb[im].red);
	}

//	BREAK

	VkSemaphore donePres;
	VkSemaphore doneRend;
	VkSemaphoreCreateInfo sci = {
		VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO, NULL, 0,
	};
	vVvk_CreateSemaphore(com.dev, &sci, NULL, &donePres);
	vVvk_CreateSemaphore(com.dev, &sci, NULL, &doneRend);

	uint32_t im;
	VkPresentInfoKHR pi = {
		VK_STRUCTURE_TYPE_PRESENT_INFO_KHR, NULL,
		1, &doneRend,
		1, &com.schain, &im,
		NULL,
	};

	for(int i=0; i<100; i++) {
		vVvk_AcquireNextImageKHR(com.dev, com.schain, UINT64_MAX,
			donePres, NULL, &im);

		VkCommandBuffer cbs[] = {
			com.cb[im].readyRend,
			i&1 ? com.cb[im].blue : com.cb[im].red,
			com.cb[im].readyPres,
		};
		VkPipelineStageFlags psf = VK_PIPELINE_STAGE_TRANSFER_BIT;
		VkSubmitInfo si = {
			VK_STRUCTURE_TYPE_SUBMIT_INFO, NULL,
			1, &donePres, &psf,
			3, cbs,
			1, &doneRend,
		};
		vVvk_QueueSubmit(com.queue, 1, &si, NULL);

		vVvk_QueuePresentKHR(com.queue, &pi);
	}

	vVvk_QueueWaitIdle(com.queue);
	vVvk_DestroySemaphore(com.dev, donePres, NULL);
	vVvk_DestroySemaphore(com.dev, doneRend, NULL);

	destroyCBuffs();
	destroySChain();
	destroyDev();
	destroyWindow();
	endDebug();
	destroyInst();
	unloadVulkan();
	return 0;
}
