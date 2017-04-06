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
		"VK_LAYER_LUNARG_core_validation",
		"VK_LAYER_LUNARG_parameter_validation",
		"VK_LAYER_LUNARG_object_tracker",
		"VK_LAYER_GOOGLE_threading",
		"VK_LAYER_GOOGLE_unique_objects",
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

struct {
	VkBuffer host;
	VkBuffer device;
} bf;
typedef struct {
	int32_t a;
	char b[256];
	uint32_t c;
} BuffData;

void setupBuff() {
	VkResult r = vk->CreateBuffer(dev, &(VkBufferCreateInfo){
		.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
		.size = sizeof(BuffData),
		.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT
			| VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
		.sharingMode = VK_SHARING_MODE_EXCLUSIVE,
	}, NULL, &bf.host);
	if(r < 0) error("Count not create Buffer `host`", r);

	r = vk->CreateBuffer(dev, &(VkBufferCreateInfo){
		.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
		.size = sizeof(BuffData),
		.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT
			| VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
		.sharingMode = VK_SHARING_MODE_EXCLUSIVE,
	}, NULL, &bf.device);
	if(r < 0) error("Count not create Buffer `device`", r);
}

void cleanupBuff() {
	vk->DestroyBuffer(dev, bf.host, NULL);
	vk->DestroyBuffer(dev, bf.device, NULL);
}

void fillCb() {
	VkCommandBufferBeginInfo cbbi = {
		.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
	};

	vk->BeginCommandBuffer(cb.cpTo, &cbbi);
	vk->CmdCopyBuffer(cb.cpTo, bf.host, bf.device,
		1, (VkBufferCopy[]){ {0, 0, sizeof(BuffData)} });
	vk->EndCommandBuffer(cb.cpTo);

	vk->BeginCommandBuffer(cb.cpFrom, &cbbi);
	vk->CmdCopyBuffer(cb.cpFrom, bf.device, bf.host,
		1, (VkBufferCopy[]){ {0, 0, sizeof(BuffData)} });
	vk->EndCommandBuffer(cb.cpFrom);

	vk->BeginCommandBuffer(cb.fill, &cbbi);
	vk->CmdUpdateBuffer(cb.fill, bf.device, 0,
		sizeof(BuffData), &(BuffData){
			.a = -17,
			.b = "Hello, world!",
			.c = 372,
		});
	vk->EndCommandBuffer(cb.fill);
}

int main() {
	setupVk();
	setupCb();
	setupBuff();

	VvVkM_Pool* pool = vkm.create(&vkbind, pdev, dev);

	vkm.registerBuffer(pool, bf.host, 0,
		VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
	vkm.registerBuffer(pool, bf.device, 0,
		VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
	VkResult r = vkm.bind(pool);
	if(r < 0) error("Could not bind pool", r);

	fillCb();

	BuffData* bd;
	r = vkm.mapBuffer(pool, bf.host, (void**) &bd);
	if(r < 0) error("Could not map memory", r);

	// Macro it up to reduce repetition.
	#define FLUSH() \
	r = vk->FlushMappedMemoryRanges(dev, 1, (VkMappedMemoryRange[]){ \
		vkm.getRangeBuffer(pool, bf.host), \
	}); \
	if(r < 0) error("Could not flush memory", r);

	#define INVALIDATE() \
	r = vk->InvalidateMappedMemoryRanges(dev, 1, (VkMappedMemoryRange[]){ \
		vkm.getRangeBuffer(pool, bf.host), \
	}); \
	if(r < 0) error("Could not invalidate memory", r);

	// This is just a test, so we're going to take this slow.
	#define SUBMIT(N) \
	vk->QueueSubmit(q, 1, &(VkSubmitInfo){ \
		.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO, \
		.commandBufferCount = 1, \
		.pCommandBuffers = &cb. N, \
	}, NULL); \
	vk->QueueWaitIdle(q);

	// Main body of the test
	printf("Copying data into and back from the card...\n");
	*bd = (BuffData){ 42, "The Answer", 42 };
	printf("Before: %d '%s' %d\n", bd->a, bd->b, bd->c);
	FLUSH()
	SUBMIT(cpTo)
	*bd = (BuffData){ 0, "This should not be seen", 0 };
	FLUSH()
	SUBMIT(cpFrom)
	INVALIDATE()
	printf("After:  %d '%s' %d\n", bd->a, bd->b, bd->c);

	printf("\nGetting data from command buffer...\n");
	*bd = (BuffData){ 0, "This should also not be seen", 0 };
	FLUSH()
	SUBMIT(fill)
	SUBMIT(cpFrom)
	INVALIDATE()
	printf("Data: %d '%s' %d\n", bd->a, bd->b, bd->c);

	// Cleanup
	vkm.destroy(pool);
	cleanupBuff();
	cleanupCb();
	cleanupVk();
	return 0;
}
