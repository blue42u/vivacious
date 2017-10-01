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

#define Vv_CHOICE V
#include <vivacious/vivacious.h>
#include <stdio.h>
#include <stdlib.h>

Vv V;

// Stuff from debug.c
void startDebug(VkInstance);
void endDebug(VkInstance);

void error(const char* m, VkResult r) {
	if(r != 0) fprintf(stderr, "Error: %s! (%d)\n", m, r);
	else fprintf(stderr, "Error: %s!\n", m);
	exit(1);
}

VkInstance inst;
VkPhysicalDevice pdev;
VkDevice dev;
VkQueue q;
uint32_t qfam;

void setupVk() {
	VkResult r;

	vVvk_load();

	VvVkB_InstInfo ii = VvVkB_InstInfo(
		Vv_ARRAY(layers, ((const char*[]){
			"VK_LAYER_LUNARG_standard_validation",
		})),
		Vv_ARRAY(extensions, ((const char*[]){
			"VK_EXT_debug_report",
		})),
		.name = "VkM test!", .version=0,
		.vkversion=VK_API_VERSION_1_0,
	);
	r = vVvkb_createInstance(&ii, &inst);
	if(r < 0) error("Cannot create instance", r);
	vVvk_loadInst(inst, VK_FALSE);

	VvVkB_DevInfo di = VvVkB_DevInfo(
		Vv_ARRAY(tasks, ((VvVkB_TaskInfo[]){
			{.flags = VK_QUEUE_TRANSFER_BIT}
		})),
		.version=VK_API_VERSION_1_0,
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
struct {
	VkCommandBuffer cpTo;
	VkCommandBuffer cpFrom;
	VkCommandBuffer fill;
} cb;

void setupCb() {
	VkResult r = vVvk_CreateCommandPool(dev, &(VkCommandPoolCreateInfo){
		.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
		.queueFamilyIndex = qfam,
	}, NULL, &cpool);
	if(r < 0) error("Could not create CommandPool", r);

	VkCommandBuffer cbuffs[3];
	r = vVvk_AllocateCommandBuffers(dev, &(VkCommandBufferAllocateInfo){
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
	vVvk_FreeCommandBuffers(dev, cpool, 3,
		(VkCommandBuffer[]){ cb.cpTo, cb.cpFrom, cb.fill });
	vVvk_DestroyCommandPool(dev, cpool, NULL);
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
	VkResult r = vVvk_CreateBuffer(dev, &(VkBufferCreateInfo){
		.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
		.size = sizeof(BuffData),
		.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT
			| VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
		.sharingMode = VK_SHARING_MODE_EXCLUSIVE,
	}, NULL, &bf.host);
	if(r < 0) error("Count not create Buffer `host`", r);

	r = vVvk_CreateBuffer(dev, &(VkBufferCreateInfo){
		.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
		.size = sizeof(BuffData),
		.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT
			| VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
		.sharingMode = VK_SHARING_MODE_EXCLUSIVE,
	}, NULL, &bf.device);
	if(r < 0) error("Count not create Buffer `device`", r);
}

void cleanupBuff() {
	vVvk_DestroyBuffer(dev, bf.host, NULL);
	vVvk_DestroyBuffer(dev, bf.device, NULL);
}

void fillCb() {
	VkCommandBufferBeginInfo cbbi = {
		.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
	};

	vVvk_BeginCommandBuffer(cb.cpTo, &cbbi);
	vVvk_CmdCopyBuffer(cb.cpTo, bf.host, bf.device,
		1, (VkBufferCopy[]){ {0, 0, sizeof(BuffData)} });
	vVvk_EndCommandBuffer(cb.cpTo);

	vVvk_BeginCommandBuffer(cb.cpFrom, &cbbi);
	vVvk_CmdCopyBuffer(cb.cpFrom, bf.device, bf.host,
		1, (VkBufferCopy[]){ {0, 0, sizeof(BuffData)} });
	vVvk_EndCommandBuffer(cb.cpFrom);

	vVvk_BeginCommandBuffer(cb.fill, &cbbi);
	vVvk_CmdUpdateBuffer(cb.fill, bf.device, 0,
		sizeof(BuffData), &(BuffData){
			.a = -17,
			.b = "Hello, world!",
			.c = 372,
		});
	vVvk_EndCommandBuffer(cb.fill);
}

int main() {
	V = vV();

	setupVk();
	setupCb();
	setupBuff();

	VvVkM_Pool* pool = vVvkm_create(pdev, dev);

	vVvkm_registerBuffer(pool, bf.host, 0,
		VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
	vVvkm_registerBuffer(pool, bf.device, 0,
		VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
	VkResult r = vVvkm_bind(pool);
	if(r < 0) error("Could not bind pool", r);

	fillCb();

	BuffData* bd;
	r = vVvkm_mapBuffer(pool, bf.host, (void**) &bd);
	if(r < 0) error("Could not map memory", r);

	VkMappedMemoryRange mmr = {VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE};

	// Macro it up to reduce repetition.
	#define FLUSH() \
	vVvkm_getRangeBuffer(pool, bf.host, &mmr); \
	r = vVvk_FlushMappedMemoryRanges(dev, 1, &mmr); \
	if(r < 0) error("Could not flush memory", r);

	#define INVALIDATE() \
	vVvkm_getRangeBuffer(pool, bf.host, &mmr); \
	r = vVvk_InvalidateMappedMemoryRanges(dev, 1, &mmr); \
	if(r < 0) error("Could not invalidate memory", r);

	// This is just a test, so we're going to take this slow.
	#define SUBMIT(N) \
	vVvk_QueueSubmit(q, 1, &(VkSubmitInfo){ \
		.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO, \
		.commandBufferCount = 1, \
		.pCommandBuffers = &cb. N, \
	}, NULL); \
	vVvk_QueueWaitIdle(q);

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
	vVvkm_destroy(pool);
	cleanupBuff();
	cleanupCb();
	cleanupVk();
	return 0;
}