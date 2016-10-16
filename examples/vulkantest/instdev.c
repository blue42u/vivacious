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

#include "common.h"

static const char* exts[] = {
	"VK_EXT_debug_report",
	"VK_KHR_surface",
	"VK_KHR_xcb_surface",
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
	VkResult r = vk->CreateInstance(&ico, NULL, &com.inst);
	if(r<0) error("Error creating instance: %d!\n", r);
	vkapi->LoadInstance(vkb, com.inst, VK_FALSE);
}

void createDev() {
	uint32_t cnt = 1;
	VkResult r = vk->EnumeratePhysicalDevices(com.inst, &cnt, &com.pdev);
	if(r<0) error("Error enum'ing PDevs: %d!\n", r);

	VkPhysicalDeviceProperties pdp;
	vk->GetPhysicalDeviceProperties(com.pdev, &pdp);
	printf("Vk version loaded: %d.%d.%d!\n",
		VK_VERSION_MAJOR(pdp.apiVersion),
		VK_VERSION_MINOR(pdp.apiVersion),
		VK_VERSION_PATCH(pdp.apiVersion));

	const float pris[] = { 0 };
	VkDeviceQueueCreateInfo dqci = {
		VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
		NULL, 0,
		0, 1, pris
	};
	VkDeviceCreateInfo dci = {
		VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
		NULL, 0,
		1, &dqci,
		1, lays,
		0, NULL,
		NULL
	};
	r = vk->CreateDevice(com.pdev, &dci, NULL, &com.dev);
	if(r<0) error("Error creating device: %d!\n", r);
	vkapi->LoadDevice(vkb, com.dev, VK_TRUE);
}

void destroyDev() {
	vk->DestroyDevice(com.dev, NULL);
}

void destroyInst() {
	vk->DestroyInstance(com.inst, NULL);
}
