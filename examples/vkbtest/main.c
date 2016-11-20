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

const VvVkB_TaskSpec intasks[] = {
	{.flags = VK_QUEUE_GRAPHICS_BIT, .fam = 1, .pri = 1.0},
	{.flags = VK_QUEUE_TRANSFER_BIT, .fam = 2, .pri = 0.5}
};
VkQueue qs[sizeof(intasks)/sizeof(VvVkB_TaskSpec)];

void setupVk() {
	vVvk.allocate(&bind);
	vk = bind.core->vk_1_0;
	VvVkB_InstInfo* ii = vkb.createInstInfo("VkBoilerplate Test",
		VK_MAKE_VERSION(1,0,0));

	vkb.setInstVersion(ii, VK_MAKE_VERSION(1,0,0));
	vkb.addLayers(ii, (const char*[]){
		"VK_LAYER_LUNARG_standard_validation", NULL });
	vkb.addInstExtensions(ii, (const char*[]){
		"VK_KHR_surface", "VK_KHR_xcb_surface",
		"VK_EXT_debug_report", NULL });

	VkResult r = vkb.createInstance(vk, ii, &inst);
	if(r<0) error("Could not create instance", r);
	vVvk.loadInst(&bind, inst, VK_FALSE);
	startDebug(&bind, inst);

	VvVkB_DevInfo* di = vkb.createDevInfo(VK_MAKE_VERSION(1,0,0));
	vkb.addDevExtensions(di, (const char*[]){
		"VK_KHR_swapchain", NULL });
	vkb.setValidity(di, valid, NULL);

	Vv_VKB_ADDTASKS(vkb, di, intasks, inds)

	VvVkB_TaskInfo* tasks = malloc(vkb.getTaskCount(di)*sizeof(VvVkB_TaskInfo));
	r = vkb.createDevice(vk, di, inst, &pdev, &dev, tasks);
	if(r<0) error("Could not create device", r);
	vVvk.loadDev(&bind, dev, VK_TRUE);

	vk->GetDeviceQueue(dev, tasks[inds[0]].family, tasks[inds[0]].index, &qs[0]);
	vk->GetDeviceQueue(dev, tasks[inds[1]].family, tasks[inds[1]].index, &qs[1]);
	free(tasks);
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
