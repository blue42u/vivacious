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
	vVvk_GetPhysicalDeviceProperties(pdev, &pdp);
	return pdp.limits.maxImageArrayLayers >= 2;
}

VkInstance inst;
VkPhysicalDevice pdev;
VkDevice dev;

void setupVk() {
	vVvk_load();

	const char* iexts[] = {
		"VK_KHR_surface", "VK_KHR_xcb_surface",
		"VK_EXT_debug_report",
	};
	const char* ilays[] = {
		"VK_LAYER_LUNARG_standard_validation",
	};
	VvVkB_InstInfo ii = VvVkB_InstInfo(
		Vv_ARRAY(extensions, iexts),
		Vv_ARRAY(layers, ilays),
		.name = "VkBoilerplate Test", .version=VK_MAKE_VERSION(1,0,0)
	);
	VkResult r = vVvkb_createInstance(&ii, &inst);
	if(r<0) error("Could not create instance", r);
	vVvk_loadInst(inst, VK_FALSE);
	startDebug(inst);

	const char* dexts[] = {
		"VK_KHR_swapchain",
	};
	VvVkB_TaskInfo intasks[] = {
		{.flags = VK_QUEUE_GRAPHICS_BIT, .family = 1, .priority = 1.0},
		{.flags = VK_QUEUE_TRANSFER_BIT, .family = 2, .priority = 0.5}
	};
	VkQueue qs[Vv_LEN(intasks)];
	VvVkB_DevInfo di = VvVkB_DevInfo(
		Vv_ARRAY(extensions, dexts),
		Vv_ARRAY(tasks, intasks),
		.version=VK_API_VERSION_1_0
	);
	VvVkB_QueueSpec* qspecs = malloc(sizeof intasks/sizeof(intasks[0])
		*sizeof(VvVkB_QueueSpec));
	r = vVvkb_createDevice(&di, inst, &dev, &pdev, qspecs);
	if(r<0) error("Could not create device", r);
	vVvk_loadDev(dev, VK_TRUE);

	for(int i=0; i<sizeof(intasks)/sizeof(VvVkB_TaskInfo); i++) {
		vVvk_GetDeviceQueue(dev, qspecs[i].family,
			qspecs[i].index, &qs[i]);
	}
	free(qspecs);
}

void shutdownVk() {
	vVvk_DestroyDevice(dev, NULL);
	endDebug(inst);
	vVvk_DestroyInstance(inst, NULL);
	vVvk_unload();
}

int main() {
	V = vV();
	setupVk();
	// Do stuff
	shutdownVk();
	return 0;
}
