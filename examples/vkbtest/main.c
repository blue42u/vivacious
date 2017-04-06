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

#include <vivacious/vkbplate.h>
#include <stdio.h>
#include <stdlib.h>

#define vkb vVvkb_test		// Choose our imp.
#define vVvk vVvk_lib

// Stuff from debug.c
void startDebug(const VvVk_Binding*, VkInstance);
void endDebug(VkInstance);

void error(const char* m, VkResult r) {
	if(r != 0) fprintf(stderr, "Error: %s! (%d)\n", m, r);
	else fprintf(stderr, "Error: %s!\n", m);
	exit(1);
}

VvVk_1_0* vk;

VkBool32 valid(void* udata, VkPhysicalDevice pdev) {
	VkPhysicalDeviceProperties pdp;
	vk->GetPhysicalDeviceProperties(pdev, &pdp);
	return pdp.limits.maxImageArrayLayers >= 2;
}

VvVk_Binding bind;
VkInstance inst;
VkPhysicalDevice pdev;
VkDevice dev;

const VvVkB_TaskInfo intasks[] = {
	{.flags = VK_QUEUE_GRAPHICS_BIT, .family = 1, .priority = 1.0},
	{.flags = VK_QUEUE_TRANSFER_BIT, .family = 2, .priority = 0.5}
};
VkQueue qs[sizeof(intasks)/sizeof(VvVkB_TaskInfo)];

void setupVk() {
	vVvk.allocate(&bind);
	vk = bind.core->vk_1_0;
	VvVkB_InstInfo* ii = vkb.createInstInfo("VkBoilerplate Test",
		VK_MAKE_VERSION(1,0,0));

	vkb.setInstVersion(ii, VK_MAKE_VERSION(1,0,0));
	vkb.addLayers(ii, (const char*[]){
		"VK_LAYER_LUNARG_core_validation",
		"VK_LAYER_LUNARG_parameter_validation",
		"VK_LAYER_LUNARG_object_tracker",
		"VK_LAYER_GOOGLE_threading",
		"VK_LAYER_GOOGLE_unique_objects",
		NULL });
	vkb.addInstExtensions(ii, (const char*[]){
		"VK_KHR_surface", "VK_KHR_xcb_surface",
		"VK_EXT_debug_report", NULL });

	VkResult r = vkb.createInstance(&bind, ii, &inst);
	if(r<0) error("Could not create instance", r);
	vVvk.loadInst(&bind, inst, VK_FALSE);
	startDebug(&bind, inst);

	VvVkB_DevInfo* di = vkb.createDevInfo(VK_MAKE_VERSION(1,0,0));
	vkb.addDevExtensions(di, (const char*[]){
		"VK_KHR_swapchain", NULL });
	vkb.setValidity(di, valid, NULL);

	for(int i=0; i<sizeof(intasks)/sizeof(VvVkB_TaskInfo); i++) {
		*vkb.newTask(di) = intasks[i];
	}

	VvVkB_QueueSpec* qspecs = malloc(
		vkb.getTaskCount(di)*sizeof(VvVkB_QueueSpec));
	r = vkb.createDevice(&bind, di, inst, &pdev, &dev, qspecs);
	if(r<0) error("Could not create device", r);
	vVvk.loadDev(&bind, dev, VK_TRUE);

	for(int i=0; i<sizeof(intasks)/sizeof(VvVkB_TaskInfo); i++) {
		vk->GetDeviceQueue(dev, qspecs[i].family,
			qspecs[i].index, &qs[i]);
	}
	free(qspecs);
}

void shutdownVk() {
	vk->DestroyDevice(dev, NULL);
	endDebug(inst);
	vk->DestroyInstance(inst, NULL);
	vVvk.free(&bind);
}

int main() {
	setupVk();
	// Do stuff
	shutdownVk();
	return 0;
}
