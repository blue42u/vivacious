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

VkInstance inst;
VkPhysicalDevice pdev;
VkDevice dev;
VkQueue q;
uint32_t qfam;

void setupVk() {
	VkResult r;

	vVvk_load();

	VvVkB_InstInfo ii = VvVkB_InstInfo(
		.name = "VkP test!", .version = 0,
		.vkversion = VK_API_VERSION_1_0,
		Vv_ARRAY(layers, ((const char*[]){
			"VK_LAYER_LUNARG_standard_validation",
		})),
		Vv_ARRAY(extensions, ((const char*[]){
			"VK_EXT_debug_report",
			"VK_KHR_surface",
			"VK_KHR_xcb_surface",
		})),
	);
	r = vVvkb_createInstance(&ii, &inst);
	if(r < 0) error("Cannot create instance", r);
	vVvk_loadInst(inst, VK_FALSE);

	VvVkB_DevInfo di = VvVkB_DevInfo(
		.version = VK_API_VERSION_1_0,
		Vv_ARRAY(extensions, ((const char*[]){
			"VK_KHR_swapchain",
		})),
		Vv_ARRAY(tasks, ((VvVkB_TaskInfo[]){
			{.flags = VK_QUEUE_GRAPHICS_BIT},
		})),
	);
	VvVkB_QueueSpec qs;
	r = vVvkb_createDevice(&di, inst, &dev, &pdev, &qs);
	if(r < 0) error("Cannot create device", r);

	vVvk_loadDev(dev, VK_TRUE);

	vVvk_GetDeviceQueue(dev, qs.family, qs.index, &q);
	qfam = qs.family;
}

void cleanupVk() {
	vVvk_DestroyDevice(dev, NULL);
	vVvk_DestroyInstance(inst, NULL);
	vVvk_unload();
}

VkCommandPool cpool;
VkCommandBuffer* cbs;
VkCommandBuffer* cbi;

void setupCb() {
	VkResult r = vVvk_CreateCommandPool(dev, &(VkCommandPoolCreateInfo){
		.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
		.queueFamilyIndex = qfam,
	}, NULL, &cpool);
	if(r < 0) error("Could not create CommandPool", r);

	cbs = malloc(imageCount*sizeof(VkCommandBuffer));

	r = vVvk_AllocateCommandBuffers(dev, &(VkCommandBufferAllocateInfo){
		.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
		.commandPool = cpool,
		.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
		.commandBufferCount = imageCount,
	}, cbs);
	if(r < 0) error("Could not allocate CommandBuffers", r);

	cbi = malloc(imageCount*sizeof(VkCommandBuffer));

	r = vVvk_AllocateCommandBuffers(dev, &(VkCommandBufferAllocateInfo){
		.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
		.commandPool = cpool,
		.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
		.commandBufferCount = imageCount,
	}, cbi);
	if(r < 0) error("Could not allocate CommandBuffers", r);
}

void cleanupCb() {
	vVvk_FreeCommandBuffers(dev, cpool, imageCount, cbs);
	free(cbs);
	vVvk_FreeCommandBuffers(dev, cpool, imageCount, cbi);
	free(cbi);
	vVvk_DestroyCommandPool(dev, cpool, NULL);
}
