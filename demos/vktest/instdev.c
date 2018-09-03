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
	if(com.vk->vkEnumerateInstanceVersion) {
		uint32_t ver;
		VkResult r = vVvkEnumerateInstanceVersion(com.vk, &ver);
		if(r<0) error("Error getting Instance version!\n");
		printf("Vk Instance version loaded: %d.%d.%d!\n",
			VK_VERSION_MAJOR(ver),
			VK_VERSION_MINOR(ver),
			VK_VERSION_PATCH(ver));
	}
	com.inst = vVcreateVkInstance(com.vk, (&(VkInstanceCreateInfo){
		.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
		.pNext = &debug_ci,
		.enabledLayerCount = sizeof(lays)/sizeof(lays[0]),
		.ppEnabledLayerNames = lays,
		.enabledExtensionCount = sizeof(exts)/sizeof(exts[0]),
		.ppEnabledExtensionNames = exts,
	}), NULL);
	if(!com.inst) error("Error creating instance!\n");
}

void destroyInst() {
	vVdestroy(com.inst);
}

void createDev() {
	uint32_t cnt = 0;
	VkResult r = vVvkEnumeratePhysicalDevices(com.inst, &cnt, NULL);
	if(r<0) error("Error enum'ing PDevs: %d!\n", r);
	VkPhysicalDevice* pdev_is = malloc(cnt*sizeof(VkPhysicalDevice));
	r = vVvkEnumeratePhysicalDevices(com.inst, &cnt, pdev_is);
	if(r<0) error("Error enum'ing PDevs: %d!\n", r);
	VvVkPhysicalDevice** pdevs = malloc(cnt*sizeof(VvVkPhysicalDevice*));
	for(int i=0; i<cnt; i++)
	pdevs[i] = vVwrapVkPhysicalDevice(com.inst, pdev_is[i]);
	free(pdev_is);

	for(int i=0; i<cnt; i++) {
		uint32_t qcnt = 0;
		vVvkGetPhysicalDeviceQueueFamilyProperties(pdevs[i], &qcnt, NULL);
		VkQueueFamilyProperties* qfps = malloc(qcnt*sizeof(VkQueueFamilyProperties));
		vVvkGetPhysicalDeviceQueueFamilyProperties(pdevs[i], &qcnt, qfps);

		uint32_t qfam = -1;
		for(int i=0; i<cnt; i++) {
			if(qfps[i].queueFlags && VK_QUEUE_GRAPHICS_BIT) {
				qfam = i;
				break;
			}
		}
		free(qfps);
		if(qfam == -1) continue;

		/*
		VkBool32 supported;
		vVvk_GetPhysicalDeviceSurfaceSupportKHR(pdevs[i],
			0, com.surf, &supported);
		if(!supported) continue;
		*/

		com.pdev = pdevs[i];
		com.qfam = qfam;
	}
	for(int i=0; i<cnt; i++) if(pdevs[i] != com.pdev) vVdestroy(pdevs[i]);
	free(pdevs);

	VkPhysicalDeviceProperties pdp;
	vVvkGetPhysicalDeviceProperties(com.pdev, &pdp);
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
	com.dev = vVcreateVkDevice(com.pdev, &dci, NULL);
	if(!com.dev) error("Error creating device!\n");

	com.queue = vVcreateVkQueue(com.dev, com.qfam, 0);
}

void destroyDev() {
	vVdestroy(com.queue);
	vVdestroy(com.dev);
	vVdestroy(com.pdev);
}
