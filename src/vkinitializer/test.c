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

#include <vivacious/vkinitializer.h>
#include "internal.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

struct VvVkInstanceCreator {
	struct VvVkInstanceCreator_P _P;
	VkInstanceCreateInfo ici;
	VkApplicationInfo ai;
	char** lays;
	char** exts;
	char* name;
};

static const struct VvVkInstanceCreator_M VvVkInstanceCreator_IMPM;

static const char* enginename = "Vivacious";
static VvVkInstanceCreator libVv_createVkInstanceCreator_test(VvVk vk) {
	VvVkInstanceCreator_R self_R = malloc(sizeof(struct VvVkInstanceCreator));
	self_R->_P._M = &VvVkInstanceCreator_IMPM;
	self_R->_P.vk = vk;

	self_R->ici = VkInstanceCreateInfo_V(
		.pApplicationInfo = &self_R->ai,
	);
	self_R->ai = VkApplicationInfo_V(
		.pEngineName = enginename,
		.engineVersion = VK_MAKE_VERSION(Vv_VERSION_MAJOR, Vv_VERSION_MINOR, Vv_VERSION_PATCH),
		.apiVersion = VK_MAKE_VERSION(1,0,0),
	);

	return (VvVkInstanceCreator)self_R;
}

static VvVkInstanceCreator_destroy_IMP
	vVreset(self);
	free(self_R);
}

static VvVkInstanceCreator_reset_IMP
	// Free the strdup'd memory and string arrays
	for(int i=0; i<self_R->ici.enabledLayerCount; i++) free(self_R->lays[i]);
	free(self_R->lays);
	self_R->lays = NULL;

	for(int i=0; i<self_R->ici.enabledExtensionCount; i++) free(self_R->exts[i]);
	free(self_R->exts);
	self_R->exts = NULL;

	free(name);
	self_R->name = NULL;

	// Clear all the values in the creator at the mo
	self_R->ici.enabledLayerCount = 0;
	self_R->ici.ppEnabledLayerNames = NULL;
	self_R->ici.enabledExtensionCount = 0;
	self_R->ici.ppEnabledExtensionNames = NULL;
	self_R->ai.pApplicationName = NULL;
	self_R->ai.applicationVersion = 0;
}

static VvVkInstanceCreator_append_IMP
	VkResult r;

	// Get the list of layers
	uint32_t cnt;
	r = vVvkEnumerateInstanceLayerProperties(self_R->_P.vk, &cnt, NULL);
	if(r < 0) return r;
	VkLayerProperties* lps = malloc(cnt*sizeof(VkLayerProperties));
	r = vVvkEnumerateInstanceLayerProperties(self_R->_P.vk, &cnt, lps);
	if(r < 0) return r;

	// Check that each of the requested layers actually exists
	for(int i=0; i<info.layersCnt; i++) {
		bool found = false;
		for(int j=0; j<cnt; j++)
			if(strcmp(info.layers[i], lps[j].layerName) == 0) {
				found = true;
				break;
			}
		if(!found) {
			free(lps);
			return VK_ERROR_LAYER_NOT_PRESENT;
		}
	}
	free(lps);

	// We need to check the extensions too, but they are more distributed.
	bool accessable[info.extensionsCnt];
	for(int i=0; i<info.extensionsCnt; i++) accessable[i] = false;

	// First check off the ones from core Vulkan
	r = vVvkEnumerateInstanceExtensionProperties(self_R->_P.vk, NULL, &cnt, NULL);
	if(r < 0) return r;
	VkExtensionProperties* eps = malloc(cnt*sizeof(VkExtensionProperties));
	r = vVvkEnumerateInstanceExtensionProperties(self_R->_P.vk, NULL, &cnt, eps);
	if(r < 0) return r;
	for(int i=0; i<cnt; i++)
		for(int j=0; j<info.extensionsCnt; j++)
			if(strcmp(info.extensions[j], eps[i].extensionName) == 0)
				accessable[j] = true;
	free(eps);

	// Then check off the ones from each of the requested layers
	for(int l=0; l<info.layersCnt; l++) {
		r = vVvkEnumerateInstanceExtensionProperties(self_R->_P.vk, info.layers[l], &cnt, NULL);
		if(r < 0) return r;
		eps = malloc(cnt*sizeof(VkExtensionProperties));
		r = vVvkEnumerateInstanceExtensionProperties(self_R->_P.vk, info.layers[l], &cnt, eps);
		if(r < 0) return r;
		for(int i=0; i<cnt; i++)
			for(int j=0; j<info.extensionsCnt; j++)
				if(strcmp(info.extensions[j], eps[i].extensionName) == 0)
					accessable[j] = true;
		free(eps);
	}

	// Check for them
	for(int i=0; i<info.extensionsCnt; i++)
		if(!accessable[i]) return VK_ERROR_EXTENSION_NOT_PRESENT;

	// All good, copy the data in.
	if(info.name) self_R->ai.pApplicationName = self_R->name = strdup(info.name);
	if(info.version) self_R->ai.applicationVersion = info.version;
	if(info.vkversion > self_R->ai.apiVersion) self_R->ai.apiVersion = info.vkversion;

	self_R->lays = realloc(self_R->lays,
		(info.layersCnt+self_R->ici.enabledLayerCount)*sizeof(char*));
	self_R->ici.ppEnabledLayerNames = (const char* const*)self_R->lays;
	for(int i=0; i<info.layersCnt; i++)
		self_R->lays[self_R->ici.enabledLayerCount+i] = strdup(info.layers[i]);
	self_R->ici.enabledLayerCount += info.layersCnt;

	self_R->exts = realloc(self_R->exts,
		(info.extensionsCnt+self_R->ici.enabledExtensionCount)*sizeof(char*));
	self_R->ici.ppEnabledExtensionNames = (const char* const*)self_R->exts;
	for(int i=0; i<info.extensionsCnt; i++)
		self_R->exts[self_R->ici.enabledExtensionCount+i] = strdup(info.extensions[i]);
	self_R->ici.enabledExtensionCount += info.extensionsCnt;

	return VK_SUCCESS;
}

static VvVkInstanceCreator_create_IMP
	VkInstance inst;
	VkResult r = vVvkCreateInstance(self_R->_P.vk, &self_R->ici, NULL, &inst);
	if(ret1) *ret1 = r;
	if(r < 0) return NULL;
	return 
}

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

	if(di->surface) {
	for(int i=0; i < di->tasksCnt; i++) {
		if(di->tasks[i].presentable) {
			VkBool32 supported;
			VkResult r = vVvk_GetPhysicalDeviceSurfaceSupportKHR(
				pdev, qs[i].family, di->surface, &supported);
			if(r < 0 || !supported) return VK_FALSE;
		}
	}
	}

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
		.pEnabledFeatures = &di->features,
	}, NULL, dev);

	free(pris);
	free(dqci);
	free(fcnts);
	return r;
}

static inline int testPM(int n, VkPresentModeKHR* pms, VkPresentModeKHR pm) {
	for(int i=0; i<n; i++) if(pms[i] == pm) return 1;
	return 0;
}

static inline int choosePM(int n, VkPresentModeKHR* pms, VkPresentModeKHR* pm) {
	if(testPM(n, pms, *pm)) return 1;
	if(*pm == VK_PRESENT_MODE_MAILBOX_KHR) {
		*pm = VK_PRESENT_MODE_FIFO_KHR;
		return 1;
	}
#ifdef VK_KHR_shared_presentable_image
	if(*pm == VK_PRESENT_MODE_SHARED_DEMAND_REFRESH_KHR) {
		*pm = VK_PRESENT_MODE_FIFO_RELAXED_KHR;
		if(testPM(n, pms, *pm)) return 1;
	}
#endif
	if(*pm == VK_PRESENT_MODE_FIFO_RELAXED_KHR) {
		*pm = VK_PRESENT_MODE_IMMEDIATE_KHR;
		if(testPM(n, pms, *pm)) return 1;
	}
	if(*pm == VK_PRESENT_MODE_IMMEDIATE_KHR) {
		*pm = VK_PRESENT_MODE_FIFO_KHR;
		return 1;
	}
	return 0;
}

static VkResult createSc(const Vv* V,
	VkPhysicalDevice pd, VkDevice d, VkSurfaceKHR sf,
	VkSwapchainCreateInfoKHR* sci, int wiRules, VkFormatProperties fps,
	VkSwapchainKHR* sc, uint32_t* icnt) {

	VkResult r;

	sci->surface = sf;

	// First, we need to try and find a format-colorSpace pair.
	uint32_t cnt;
	r = vVvk_GetPhysicalDeviceSurfaceFormatsKHR(pd, sf, &cnt, NULL);
	if(r < 0) return r;
	VkSurfaceFormatKHR* fpairs = malloc(cnt*sizeof(VkSurfaceFormatKHR));
	r = vVvk_GetPhysicalDeviceSurfaceFormatsKHR(pd, sf, &cnt, fpairs);
	if(r < 0) { free(fpairs); return r; }
	sci->imageFormat = VK_FORMAT_UNDEFINED;
	for(int i=0; i<cnt; i++) {
		if(fpairs[i].colorSpace == sci->imageColorSpace) {
			sci->imageFormat = fpairs[i].format;
			break;
		}
	}
	free(fpairs);
	if(sci->imageFormat == VK_FORMAT_UNDEFINED)
		return VK_ERROR_FORMAT_NOT_SUPPORTED;

	// Nab the caps
	VkSurfaceCapabilitiesKHR scaps;
	r = vVvk_GetPhysicalDeviceSurfaceCapabilitiesKHR(pd, sf, &scaps);
	if(r < 0) return r;

	// Now for the extent and transformation... for this imp, we
	// completely ignore the user's transformation.
	if(wiRules && (scaps.currentExtent.width != 0xFFFFFFFF
		|| scaps.currentExtent.height != 0xFFFFFFFF))
		sci->imageExtent = scaps.currentExtent;
	sci->preTransform = scaps.currentTransform;
	if(scaps.minImageCount > sci->minImageCount)
		sci->minImageCount = scaps.minImageCount;

	// Then the alpha handling...
	if(!(sci->compositeAlpha & scaps.supportedCompositeAlpha)) {
		VkCompositeAlphaFlagBitsKHR f;
		for(f = 1; !(scaps.supportedCompositeAlpha & f); f = f<<1);
		sci->compositeAlpha = f;
	}

	// Then the presentation mode...
	r = vVvk_GetPhysicalDeviceSurfacePresentModesKHR(pd, sf, &cnt, NULL);
	if(r < 0) return r;
	VkPresentModeKHR pms[cnt];
	r = vVvk_GetPhysicalDeviceSurfacePresentModesKHR(pd, sf, &cnt, pms);
	if(r < 0) return r;
	if(!choosePM(cnt, pms, &sci->presentMode))
		return VK_ERROR_INCOMPATIBLE_DISPLAY_KHR;

	// And finally just make the Swapchain!
	r = vVvk_CreateSwapchainKHR(d, sci, NULL, sc);
	if(r < 0) return r;
	r = vVvk_GetSwapchainImagesKHR(d, *sc, &cnt, NULL);
	if(r < 0) { vVvk_DestroySwapchainKHR(d, *sc, NULL); return r; }
	*icnt = cnt;
	return VK_SUCCESS;
}

const VvVkB libVv_vkb_test = {
	.createInstance = createInst,
	.createDevice = createDev,
	.createSwapchain = createSc,
};
