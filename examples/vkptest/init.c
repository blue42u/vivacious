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

VvVk_Binding vkbind;
VvVk_1_0* vk;
VkInstance inst;
VkPhysicalDevice pdev;
VkDevice dev;
VkQueue q;
uint32_t qfam;

void setupVk() {
	VkResult r;

	vVvk.allocate(&vkbind);
	vk = vkbind.core->vk_1_0;

	VvVkB_InstInfo* ii = vkb.createInstInfo("VkP test!", 0);
	vkb.setInstVersion(ii, VK_MAKE_VERSION(1,0,0));
	vkb.addLayers(ii, (const char*[]){
//		"VK_LAYER_LUNARG_core_validation",
		"VK_LAYER_LUNARG_parameter_validation",
		"VK_LAYER_LUNARG_object_tracker",
		"VK_LAYER_GOOGLE_threading",
//		"VK_LAYER_GOOGLE_unique_objects",

		"VK_LAYER_LUNARG_swapchain",
		NULL
	});
	vkb.addInstExtensions(ii, (const char*[]){
		"VK_EXT_debug_report",
		"VK_KHR_surface",
		"VK_KHR_xcb_surface",
		NULL
	});
	r = vkb.createInstance(&vkbind, ii, &inst);
	if(r < 0) error("Cannot create instance", r);

	vVvk.loadInst(&vkbind, inst, VK_FALSE);

	VvVkB_DevInfo* di = vkb.createDevInfo(VK_MAKE_VERSION(1,0,0));
	vkb.addDevExtensions(di, (const char*[]){
		"VK_KHR_swapchain",
		NULL
	});
	*vkb.newTask(di) = (VvVkB_TaskInfo){.flags = VK_QUEUE_GRAPHICS_BIT};
	if(vkb.getTaskCount(di) != 1) error("Odd thing with VkB", 0);
	VvVkB_QueueSpec qs;
	r = vkb.createDevice(&vkbind, di, inst, &pdev, &dev, &qs);
	if(r < 0) error("Cannot create device", r);

	vVvk.loadDev(&vkbind, dev, VK_TRUE);

	vk->GetDeviceQueue(dev, qs.family, qs.index, &q);
	qfam = qs.family;
}

void cleanupVk() {
	vk->DestroyDevice(dev, NULL);
	vk->DestroyInstance(inst, NULL);
	vVvk.free(&vkbind);
}

VkCommandPool cpool;
VkCommandBuffer cb;

void setupCb() {
	VkResult r = vk->CreateCommandPool(dev, &(VkCommandPoolCreateInfo){
		.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
		.queueFamilyIndex = qfam,
	}, NULL, &cpool);
	if(r < 0) error("Could not create CommandPool", r);

	r = vk->AllocateCommandBuffers(dev, &(VkCommandBufferAllocateInfo){
		.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
		.commandPool = cpool,
		.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
		.commandBufferCount = 1,
	}, &cb);
	if(r < 0) error("Could not allocate CommandBuffer", r);
}

void cleanupCb() {
	vk->FreeCommandBuffers(dev, cpool, 1, &cb);
	vk->DestroyCommandPool(dev, cpool, NULL);
}
