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

static const char* exts[] = {
	"VK_EXT_debug_report",
	"VK_KHR_surface",
	"VK_KHR_xcb_surface",
};
static const char* dexts[] = {
	"VK_KHR_swapchain",
};
static const char* lays[] = {
	"VK_LAYER_LUNARG_standard_validation",
};

void createInst() {
	VkInstanceCreateInfo ico = {
		VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
		NULL, 0,
		NULL,
		sizeof(lays)/sizeof(char*), lays,
		sizeof(exts)/sizeof(char*), exts
	};
	VkResult r = vVvk_CreateInstance(&ico, NULL, &com.inst);
	if(r<0) error("Error creating instance: %d!\n", r);
	vVvk_loadInst(com.inst, VK_FALSE);
}

void createDev() {
	uint32_t cnt = 0;
	VkResult r = vVvk_EnumeratePhysicalDevices(com.inst, &cnt, NULL);
	if(r<0) error("Error enum'ing PDevs: %d!\n", r);
	VkPhysicalDevice* pdevs = malloc(cnt*sizeof(VkPhysicalDevice));
	r = vVvk_EnumeratePhysicalDevices(com.inst, &cnt, pdevs);
	if(r<0) error("Error enum'ing PDevs: %d!\n", r);

	for(int i=0; i<cnt; i++) {
		uint32_t qcnt = 0;
		vVvk_GetPhysicalDeviceQueueFamilyProperties(pdevs[i],
			&qcnt, NULL);
		VkQueueFamilyProperties* qfps = malloc(qcnt*sizeof(VkQueueFamilyProperties));
		vVvk_GetPhysicalDeviceQueueFamilyProperties(pdevs[i],
			&qcnt, qfps);

		uint32_t qfam = -1;
		for(int i=0; i<cnt; i++) {
			if(qfps[i].queueFlags && VK_QUEUE_GRAPHICS_BIT) {
				qfam = i;
				break;
			}
		}
		free(qfps);
		if(qfam == -1) continue;

		VkBool32 supported;
		vVvk_GetPhysicalDeviceSurfaceSupportKHR(pdevs[i],
			0, com.surf, &supported);
		if(!supported) continue;

		com.pdev = pdevs[i];
		com.qfam = qfam;
	}
	free(pdevs);

	VkPhysicalDeviceProperties pdp;
	vVvk_GetPhysicalDeviceProperties(com.pdev, &pdp);
	printf("Vk version loaded: %d.%d.%d!\n",
		VK_VERSION_MAJOR(pdp.apiVersion),
		VK_VERSION_MINOR(pdp.apiVersion),
		VK_VERSION_PATCH(pdp.apiVersion));

	const float pris[] = { 0 };
	VkDeviceQueueCreateInfo dqci = {
		VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO, NULL, 0,
		com.qfam, 1, pris
	};
	VkDeviceCreateInfo dci = {
		VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO, NULL, 0,
		1, &dqci,
		sizeof(lays)/sizeof(char*), lays,
		sizeof(dexts)/sizeof(char*), dexts,
		NULL
	};
	r = vVvk_CreateDevice(com.pdev, &dci, NULL, &com.dev);
	if(r<0) error("Error creating device: %d!\n", r);
	vVvk_loadDev(com.dev, VK_TRUE);

	vVvk_GetDeviceQueue(com.dev, com.qfam, 0, &com.queue);
}

void destroyDev() {
	vVvk_DestroyDevice(com.dev, NULL);
}

void destroyInst() {
	vVvk_DestroyInstance(com.inst, NULL);
}
