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

void loadCBuffs() {
	VkCommandBufferBeginInfo cbbi = {
		VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO, NULL,
		VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT, NULL,
	};
	for(int i=0; i<com.simagecnt; i++) {
		VkImageMemoryBarrier imb1 = {
			VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, NULL,
			VK_ACCESS_MEMORY_READ_BIT, VK_ACCESS_TRANSFER_WRITE_BIT,
			VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
			VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
			VK_QUEUE_FAMILY_IGNORED, VK_QUEUE_FAMILY_IGNORED,
			com.simages[i],
			{ VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 },
		};
		vVvk10_BeginCommandBuffer(com.cb[i].readyRend, &cbbi);
		vVvk10_CmdPipelineBarrier(com.cb[i].readyRend,
			VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
			VK_PIPELINE_STAGE_TRANSFER_BIT,
			0,
			0, NULL,
			0, NULL,
			1, &imb1);
		vVvk10_EndCommandBuffer(com.cb[i].readyRend);


		VkImageMemoryBarrier imb2 = {
			VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, NULL,
			VK_ACCESS_TRANSFER_WRITE_BIT, VK_ACCESS_MEMORY_READ_BIT,
			VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
			VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
			VK_QUEUE_FAMILY_IGNORED, VK_QUEUE_FAMILY_IGNORED,
			com.simages[i],
			{ VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 },
		};
		vVvk10_BeginCommandBuffer(com.cb[i].readyPres, &cbbi);
		vVvk10_CmdPipelineBarrier(com.cb[i].readyPres,
			VK_PIPELINE_STAGE_TRANSFER_BIT,
			VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
			0,
			0, NULL,
			0, NULL,
			1, &imb2);
		vVvk10_EndCommandBuffer(com.cb[i].readyPres);
	}
}

static VkCommandPool pool;

void createCBuffs() {
	VkCommandPoolCreateInfo cpci = {
		VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO, NULL,
		0, com.qfam,
	};
	VkResult r = vVvk10_CreateCommandPool(com.dev, &cpci, NULL, &pool);
	if(r<0) error("Error creating command pool: %d!\n", r);

	com.cbuffs = malloc(com.simagecnt*sizeof(struct CBuffs));

	VkCommandBufferAllocateInfo cbai = {
		VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO, NULL,
		pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY,
		com.simagecnt*sizeof(struct CBuffs)/sizeof(VkCommandBuffer),
	};
	r = vVvk10_AllocateCommandBuffers(com.dev, &cbai, com.cbuffs);

	loadCBuffs();
}

void destroyCBuffs() {
	vVvk10_FreeCommandBuffers(com.dev, pool,
		com.simagecnt*sizeof(struct CBuffs)/sizeof(VkCommandBuffer),
		com.cbuffs);
	vVvk10_DestroyCommandPool(com.dev, pool, NULL);
	free(com.cbuffs);
}

