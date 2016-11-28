/**************************************************************************
   Copyright 2016 Jonathon Anderson

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

#include <vivacious/vkmemory.h>
#include <vivacious/vkbplate.h>
#include <stdio.h>
#include <stdlib.h>

#define vkm vVvkm_test		// Choose our imp.
#define vkb vVvkb_test		// Helpers for the test
#define vVvk vVvk_lib

// Stuff from debug.c
void startDebug(const VvVk_Binding*, VkInstance);
void endDebug(VkInstance);

void error(const char* m, VkResult r) {
	if(r != 0) fprintf(stderr, "Error: %s! (%d)\n", m, r);
	else fprintf(stderr, "Error: %s!\n", m);
	exit(1);
}

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

	VvVkB_InstInfo* ii = vkb.createInstInfo("VkM test!", 0);
	vkb.setInstVersion(ii, VK_MAKE_VERSION(1,0,0));
	vkb.addLayers(ii, (const char*[]){
		"VK_LAYER_LUNARG_standard_validation",
		NULL
	});
	vkb.addInstExtensions(ii, (const char*[]){
		"VK_EXT_debug_report",
		NULL
	});
	r = vkb.createInstance(&vkbind, ii, &inst);
	if(r < 0) error("Cannot create instance", r);

	vVvk.loadInst(&vkbind, inst, VK_FALSE);

	VvVkB_DevInfo* di = vkb.createDevInfo(VK_MAKE_VERSION(1,0,0));
	*vkb.newTask(di) = (VvVkB_TaskInfo){.flags = VK_QUEUE_TRANSFER_BIT};
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
struct {
	VkCommandBuffer cpTo;
	VkCommandBuffer cpFrom;
	VkCommandBuffer fill;
} cb;

void setupCb() {
	VkResult r = vk->CreateCommandPool(dev, &(VkCommandPoolCreateInfo){
		.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
		.queueFamilyIndex = qfam,
	}, NULL, &cpool);
	if(r < 0) error("Could not create CommandPool", r);

	VkCommandBuffer cbuffs[3];
	r = vk->AllocateCommandBuffers(dev, &(VkCommandBufferAllocateInfo){
		.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
		.commandPool = cpool,
		.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
		.commandBufferCount = 3,
	}, cbuffs);
	if(r < 0) error("Could not allocate CommandBuffers", r);

	cb.cpTo = cbuffs[0];
	cb.cpFrom = cbuffs[1];
	cb.fill = cbuffs[2];
}

void cleanupCb() {
	vk->FreeCommandBuffers(dev, cpool, 3,
		(VkCommandBuffer[]){ cb.cpTo, cb.cpFrom, cb.fill });
	vk->DestroyCommandPool(dev, cpool, NULL);
}

int main() {
	setupVk();
	setupCb();

	cleanupCb();
	cleanupVk();

	return 0;
}
