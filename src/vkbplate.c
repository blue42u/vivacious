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

#ifdef Vv_ENABLE_VULKAN

#include <vivacious/vkbplate.h>
#include "internal.h"
#include <stdlib.h>
#include <stdio.h>

struct VvVkB_InstInfo {
	const char* appName;
	uint32_t appVer;
	uint32_t apiVer;

	int laycnt;
	const char** lays;

	int extcnt;
	const char** exts;
};

static VvVkB_InstInfo* createInstInfo(const char* name, uint32_t ver) {
	VvVkB_InstInfo* ii = malloc(sizeof(VvVkB_InstInfo));
	*ii = (VvVkB_InstInfo) {
		.appName = name, .appVer = ver,
		.apiVer = 0,	// No particular version required
		.laycnt = 0, .extcnt = 0,
		.lays = NULL, .exts = NULL,	// No layers or exts yet.
	};
	return ii;
}

static void setIVer(VvVkB_InstInfo* ii, uint32_t ver) {
	ii->apiVer = ver;
}

static void addLays(VvVkB_InstInfo* ii, const char** names) {
	int cnt;
	for(cnt = 0; names[cnt] != NULL; cnt++);
	if(ii->laycnt == 0) ii->lays = malloc(cnt*sizeof(char*));
	else ii->lays = realloc(ii->lays, (cnt+ii->laycnt)*sizeof(char*));
	for(int i=0; i<cnt; i++)
		ii->lays[ii->laycnt + i] = names[i];
	ii->laycnt += cnt;
}

static void addIExts(VvVkB_InstInfo* ii, const char** names) {
	int cnt;
	for(cnt = 0; names[cnt] != NULL; cnt++);
	if(ii->extcnt == 0) ii->exts = malloc(cnt*sizeof(char*));
	else ii->exts = realloc(ii->exts, (cnt+ii->extcnt)*sizeof(char*));
	for(int i=0; i<cnt; i++)
		ii->exts[ii->extcnt + i] = names[i];
	ii->extcnt += cnt;
}

static VkResult createInst(const VvVk_1_0* vk, VvVkB_InstInfo* ii,
	VkInstance* inst) {

	VkResult r = vk->CreateInstance(&(VkInstanceCreateInfo){
		.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
		.pApplicationInfo = &(VkApplicationInfo){
			.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
			.pApplicationName = ii->appName,
			.applicationVersion = ii->appVer,
			.pEngineName = "Vivacious",
			.engineVersion = VK_MAKE_VERSION(Vv_VERSION_MAJOR,
				Vv_VERSION_MINOR, Vv_VERSION_PATCH),
			.apiVersion = ii->apiVer,
		},
		.enabledLayerCount = ii->laycnt,
		.ppEnabledLayerNames = ii->lays,
		.enabledExtensionCount = ii->extcnt,
		.ppEnabledExtensionNames = ii->exts,
	}, NULL, inst);

	free(ii->lays);	free(ii->exts);
	free(ii);
	return r;
}

struct VvVkB_DevInfo {
	uint32_t ver;

	int extcnt;
	const char** exts;
};

static VvVkB_DevInfo* createDevInfo(uint32_t ver) {
	VvVkB_DevInfo* di = malloc(sizeof(VvVkB_DevInfo));
	*di = (VvVkB_DevInfo){
		.ver = ver,
		.extcnt = 0, .exts = NULL,	// No extensions yet
	};
	return di;
}

static void addDExts(VvVkB_DevInfo* di, const char** names) {
	int cnt;
	for(cnt = 0; names[cnt] != NULL; cnt++);
	if(di->extcnt == 0) di->exts = malloc(cnt*sizeof(char*));
	else di->exts = realloc(di->exts, (cnt+di->extcnt)*sizeof(char*));
	for(int i=0; i<cnt; i++)
		di->exts[di->extcnt + i] = names[i];
	di->extcnt += cnt;
}

static VkResult choosePDev(const VvVk_1_0* vk, VvVkB_DevInfo* di,
	VkInstance inst, VkPhysicalDevice* pdev) {
	VkResult r;

	uint32_t pdevcnt;
	r = vk->EnumeratePhysicalDevices(inst, &pdevcnt, NULL);
	if(r<0) return r;
	VkPhysicalDevice* pdevs = malloc(pdevcnt*sizeof(VkPhysicalDevice));
	r = vk->EnumeratePhysicalDevices(inst, &pdevcnt, pdevs);
	if(r<0) {
		free(pdevs);
		return r;
	}

	for(int i=0; i<pdevcnt; i++) {
		VkPhysicalDeviceProperties pdp;
		vk->GetPhysicalDeviceProperties(pdevs[i], &pdp);
		if(pdp.apiVersion >= di->ver) {
			*pdev = pdevs[i];
			free(pdevs);
			return VK_SUCCESS;
		}
	}

	free(pdevs);
	return VK_ERROR_INCOMPATIBLE_DRIVER;
}

static VkResult createDev(const VvVk_1_0* vk, VvVkB_DevInfo* di,
	VkInstance inst, VkPhysicalDevice* pdev, VkDevice* dev) {

	VkResult r = choosePDev(vk, di, inst, pdev);
	if(r >= 0) {
		r = vk->CreateDevice(*pdev, &(VkDeviceCreateInfo){
			.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
			.enabledExtensionCount = di->extcnt,
			.ppEnabledExtensionNames = di->exts,
		}, NULL, dev);

		free(di->exts);
		free(di);
	}
	return r;
}

VvAPI const Vv_VulkanBoilerplate vVvkb_test = {
	.createInstInfo = createInstInfo,
	.setInstVersion = setIVer,
	.addLayers = addLays,
	.addInstExtensions = addIExts,
	.createInstance = createInst,

	.createDevInfo = createDevInfo,
	.addDevExtensions = addDExts,
	.createDevice = createDev,
};

#endif // Vv_ENABLE_VULKAN
