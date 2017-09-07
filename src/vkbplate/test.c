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

#ifdef Vv_ENABLE_VULKAN

#define Vv_CHOICE *V
#define Vv_IMP_vkb

#include <vivacious/vkbplate.h>
#include "internal.h"
#include <stdlib.h>
#include <stdio.h>

static VkResult createInst(const Vv* V, VvVkB_InstInfo* ii,
	VkInstance* inst) {

	return vVvk_CreateInstance(&(VkInstanceCreateInfo){
		.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
		.pApplicationInfo = &(VkApplicationInfo){
			.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
			.pApplicationName = ii->name,
			.applicationVersion = ii->version,
			.pEngineName = "Vivacious",
			.engineVersion = VK_MAKE_VERSION(Vv_VERSION_MAJOR,
				Vv_VERSION_MINOR, Vv_VERSION_PATCH),
			.apiVersion = ii->vkversion,
		},
		.enabledLayerCount = ii->layersCnt,
		.ppEnabledLayerNames = ii->layers,
		.enabledExtensionCount = ii->extensionsCnt,
		.ppEnabledExtensionNames = ii->extensions,
	}, NULL, inst);
}

static VkBool32 queuePDev(const Vv* V, VvVkB_DevInfo* di,
	VkPhysicalDevice pdev, VvVkB_QueueSpec* qs, int** rcnts) {

	uint32_t cnt = 0;
	vVvk_GetPhysicalDeviceQueueFamilyProperties(pdev, &cnt, NULL);
	VkQueueFamilyProperties* qfp = malloc(cnt*sizeof(VkQueueFamilyProperties));
	if(qfp == NULL) printf("NULL qfp!\n");
	vVvk_GetPhysicalDeviceQueueFamilyProperties(pdev, &cnt, qfp);
	int* cnts = calloc(cnt, sizeof(int));
	for(int i=0; i < di->tasksCnt; i++) {
		int found = 0;
		for(int j=0; j<cnt; j++) {
			if(qfp[j].queueCount == cnts[j]) continue;
			if((qfp[j].queueFlags & di->tasks[i].flags) !=
				di->tasks[i].flags) continue;
			found = 1;
			qs[i] = (VvVkB_QueueSpec){ j, cnts[j] };
			cnts[j]++;
			break;
		}
		if(!found) {
			free(cnts);
			free(qfp);
			return VK_FALSE;
		}
	}
	if(rcnts) *rcnts = cnts;
	else free(cnts);
	free(qfp);
	return VK_TRUE;
}

static VkBool32 checkPDev(const Vv* V, VvVkB_DevInfo* di,
	VkInstance inst, VkPhysicalDevice pdev, VvVkB_QueueSpec* qs) {

	VkPhysicalDeviceProperties pdp;
	vVvk_GetPhysicalDeviceProperties(pdev, &pdp);
	if(pdp.apiVersion < di->version) return VK_FALSE;

	if(!queuePDev(V, di, pdev, qs, NULL)) return VK_FALSE;

	// The custom check is last, of course.
	if(di->validator) return di->validator(di->validator_ud, pdev);
	else return VK_TRUE;
}

static VkBool32 compPDevs(const Vv* V, VvVkB_DevInfo* di,
	VkInstance inst, VkPhysicalDevice a, VkPhysicalDevice b) {

	if(di->comparison) return di->comparison(di->comparison_ud, a, b);
	else return VK_FALSE;
}

static VkResult choosePDev(const Vv* V, VvVkB_DevInfo* di,
	VkInstance inst, VkPhysicalDevice* pdev, VvVkB_QueueSpec* qs,
	int** cnts) {
	VkResult r;

	uint32_t pdevcnt = 0;
	r = vVvk_EnumeratePhysicalDevices(inst, &pdevcnt, NULL);
	if(r<0) return r;
	VkPhysicalDevice* pdevs = malloc(pdevcnt*sizeof(VkPhysicalDevice));
	r = vVvk_EnumeratePhysicalDevices(inst, &pdevcnt, pdevs);
	if(r<0) {
		free(pdevs);
		return r;
	}

	*pdev = NULL;
	for(int i=0; i<pdevcnt; i++) {
		VkPhysicalDevice pd = pdevs[i];
		if(checkPDev(V, di, inst, pd, qs)) {
			if(*pdev == NULL || compPDevs(V, di, inst, pd, *pdev))
				*pdev = pd;
		}
	}

	free(pdevs);
	if(*pdev == NULL) return VK_ERROR_INCOMPATIBLE_DRIVER;
	return queuePDev(V, di, *pdev, qs, cnts) ? VK_SUCCESS
		: VK_ERROR_INCOMPATIBLE_DRIVER;
}

static VkResult createDev(const Vv* V, VvVkB_DevInfo* di,
	VkInstance inst, VkDevice* dev, VkPhysicalDevice* pdev,
	VvVkB_QueueSpec* qs) {

	int* fcnts;
	VkResult r = choosePDev(V, di, inst, pdev, qs, &fcnts);
	if(r < 0) {
		free(fcnts);
		return r;
	}

	uint32_t fcnt = 0;
	vVvk_GetPhysicalDeviceQueueFamilyProperties(*pdev, &fcnt, NULL);

	int dqcicnt = 0;
	for(int i=0; i<fcnt; i++) if(fcnts[i] > 0) dqcicnt++;

	VkDeviceQueueCreateInfo* dqci = malloc(dqcicnt*sizeof(VkDeviceQueueCreateInfo));
	float* pris = malloc(di->tasksCnt*sizeof(float));

	int dqciind = 0;
	int prioff = 0;

	for(int i=0; i<fcnt; i++) {
		if(fcnts[i] > 0) {
			dqci[dqciind] = (VkDeviceQueueCreateInfo){
				.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
				.queueFamilyIndex = i,
				.queueCount = fcnts[i],
				.pQueuePriorities = &pris[prioff],
			};
			for(int j=0; j < di->tasksCnt; j++)
				if(qs[j].family == i)
					pris[prioff + qs[j].index] =
						di->tasks[j].priority;
			prioff += fcnts[i];
		}
	}

	r = vVvk_CreateDevice(*pdev, &(VkDeviceCreateInfo){
		.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
		.enabledExtensionCount = di->extensionsCnt,
		.ppEnabledExtensionNames = di->extensions,
		.queueCreateInfoCount = dqcicnt,
		.pQueueCreateInfos = dqci,
	}, NULL, dev);

	free(pris);
	free(dqci);
	free(fcnts);
	return r;
}

const VvVkB libVv_vkb_test = {
	.createInstance = createInst,
	.createDevice = createDev,
};

#endif // Vv_ENABLE_VULKAN
