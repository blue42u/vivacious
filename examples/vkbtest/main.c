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

VkBool32 valid(void* udata, VkPhysicalDevice pdev) {
	VkPhysicalDeviceProperties pdp;
	vVvk10_GetPhysicalDeviceProperties(pdev, &pdp);
	return pdp.limits.maxImageArrayLayers >= 2;
}

VkInstance inst;
VkPhysicalDevice pdev;
VkDevice dev;

const VvVkB_TaskInfo intasks[] = {
	{.flags = VK_QUEUE_GRAPHICS_BIT, .family = 1, .priority = 1.0},
	{.flags = VK_QUEUE_TRANSFER_BIT, .family = 2, .priority = 0.5}
};
VkQueue qs[sizeof(intasks)/sizeof(VvVkB_TaskInfo)];

void setupVk() {
	vVvk_allocate();
	VvVkB_InstInfo* ii = vVvkb_createInstInfo("VkBoilerplate Test",
		VK_MAKE_VERSION(1,0,0));

	vVvkb_setInstVersion(ii, VK_MAKE_VERSION(1,0,0));
	vVvkb_addLayers(ii, (const char*[]){
		"VK_LAYER_LUNARG_standard_validation",
		NULL });
	vVvkb_addInstExtensions(ii, (const char*[]){
		"VK_KHR_surface", "VK_KHR_xcb_surface",
		"VK_EXT_debug_report", NULL });

	VkResult r = vVvkb_createInstance(ii, &inst);
	if(r<0) error("Could not create instance", r);
	vVvk_loadInst(inst, VK_FALSE);
	startDebug(inst);

	VvVkB_DevInfo* di = vVvkb_createDevInfo(VK_MAKE_VERSION(1,0,0));
	vVvkb_addDevExtensions(di, (const char*[]){
		"VK_KHR_swapchain", NULL });
	vVvkb_setValidity(di, valid, NULL);

	for(int i=0; i<sizeof(intasks)/sizeof(VvVkB_TaskInfo); i++) {
		*vVvkb_newTask(di) = intasks[i];
	}

	VvVkB_QueueSpec* qspecs = malloc(
		vVvkb_getTaskCount(di)*sizeof(VvVkB_QueueSpec));
	r = vVvkb_createDevice(di, inst, &pdev, &dev, qspecs);
	if(r<0) error("Could not create device", r);
	vVvk_loadDev(dev, VK_TRUE);

	for(int i=0; i<sizeof(intasks)/sizeof(VvVkB_TaskInfo); i++) {
		vVvk10_GetDeviceQueue(dev, qspecs[i].family,
			qspecs[i].index, &qs[i]);
	}
	free(qspecs);
}

void shutdownVk() {
	vVvk10_DestroyDevice(dev, NULL);
	endDebug(inst);
	vVvk10_DestroyInstance(inst, NULL);
	vVvk_free();
}

int main() {
	V = vV();
	setupVk();
	// Do stuff
	shutdownVk();
	return 0;
}
