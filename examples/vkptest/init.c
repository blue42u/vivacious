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

	vVvk_allocate();

	VvVkB_InstInfo* ii = vVvkb_createInstInfo("VkP test!", 0);
	vVvkb_setInstVersion(ii, VK_MAKE_VERSION(1,0,0));
	vVvkb_addLayers(ii, (const char*[]){
		"VK_LAYER_LUNARG_core_validation",
		"VK_LAYER_LUNARG_parameter_validation",
		"VK_LAYER_LUNARG_object_tracker",
		"VK_LAYER_GOOGLE_threading",
		"VK_LAYER_GOOGLE_unique_objects",

		"VK_LAYER_LUNARG_swapchain",
		NULL
	});
	vVvkb_addInstExtensions(ii, (const char*[]){
		"VK_EXT_debug_report",
		"VK_KHR_surface",
		"VK_KHR_xcb_surface",
		NULL
	});
	r = vVvkb_createInstance(ii, &inst);
	if(r < 0) error("Cannot create instance", r);

	vVvk_loadInst(inst, VK_FALSE);

	VvVkB_DevInfo* di = vVvkb_createDevInfo(VK_MAKE_VERSION(1,0,0));
	vVvkb_addDevExtensions(di, (const char*[]){
		"VK_KHR_swapchain",
		NULL
	});
	*vVvkb_newTask(di) = (VvVkB_TaskInfo){.flags = VK_QUEUE_GRAPHICS_BIT};
	if(vVvkb_getTaskCount(di) != 1) error("Odd thing with VkB", 0);
	VvVkB_QueueSpec qs;
	r = vVvkb_createDevice(di, inst, &pdev, &dev, &qs);
	if(r < 0) error("Cannot create device", r);

	vVvk_loadDev(dev, VK_TRUE);

	vVvk10_GetDeviceQueue(dev, qs.family, qs.index, &q);
	qfam = qs.family;
}

void cleanupVk() {
	vVvk10_DestroyDevice(dev, NULL);
	vVvk10_DestroyInstance(inst, NULL);
	vVvk_free();
}

VkCommandPool cpool;
VkCommandBuffer* cbs;
VkCommandBuffer* cbi;

void setupCb() {
	VkResult r = vVvk10_CreateCommandPool(dev, &(VkCommandPoolCreateInfo){
		.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
		.queueFamilyIndex = qfam,
	}, NULL, &cpool);
	if(r < 0) error("Could not create CommandPool", r);

	cbs = malloc(imageCount*sizeof(VkCommandBuffer));

	r = vVvk10_AllocateCommandBuffers(dev, &(VkCommandBufferAllocateInfo){
		.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
		.commandPool = cpool,
		.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
		.commandBufferCount = imageCount,
	}, cbs);
	if(r < 0) error("Could not allocate CommandBuffers", r);

	cbi = malloc(imageCount*sizeof(VkCommandBuffer));

	r = vVvk10_AllocateCommandBuffers(dev, &(VkCommandBufferAllocateInfo){
		.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
		.commandPool = cpool,
		.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
		.commandBufferCount = imageCount,
	}, cbi);
	if(r < 0) error("Could not allocate CommandBuffers", r);
}

void cleanupCb() {
	vVvk10_FreeCommandBuffers(dev, cpool, imageCount, cbs);
	free(cbs);
	vVvk10_FreeCommandBuffers(dev, cpool, imageCount, cbi);
	free(cbi);
	vVvk10_DestroyCommandPool(dev, cpool, NULL);
}
