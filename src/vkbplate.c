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

_Vv_STRUCT(FamilySpec) {
	uint32_t id;
	VkQueueFlags flags;
	uint32_t cnt;
	uint32_t* inds;
};

struct VvVkB_DevInfo {
	uint32_t ver;

	int extcnt;
	const char** exts;

	void* validudata;
	VkBool32 (*valid)(const VvVk_1_0*, void*, VkPhysicalDevice);

	void* compudata;
	VkBool32 (*comp)(const VvVk_1_0*, void*, VkPhysicalDevice,
		VkPhysicalDevice);

	uint32_t taskcnt;
	uint32_t familycnt;
	FamilySpec* families;
};

static VvVkB_DevInfo* createDevInfo(uint32_t ver) {
	VvVkB_DevInfo* di = malloc(sizeof(VvVkB_DevInfo));
	*di = (VvVkB_DevInfo){
		.ver = ver,
		.extcnt = 0, .exts = NULL,	// No extensions yet
		.valid = NULL, .comp = NULL,	// No custom functions yet
		.taskcnt = 0,
		.familycnt = 0, .families = NULL,	// No tasks yet
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

static void setValid(VvVkB_DevInfo* di, VkBool32 (*f)(const VvVk_1_0*, void*,
	VkPhysicalDevice), void* udata) {

	di->validudata = udata;
	di->valid = f;
}

static void setComp(VvVkB_DevInfo* di, VkBool32 (*f)(const VvVk_1_0*, void*,
	VkPhysicalDevice, VkPhysicalDevice), void* udata) {

	di->compudata = udata;
	di->comp = f;
}

static uint32_t getTCount(VvVkB_DevInfo* di) {
	return di->taskcnt;
}

static void addTs(VvVkB_DevInfo* di, const VvVkB_TaskInfo* tasks,
	uint32_t* indices) {

	for(int i=0; tasks[i].flags != 0; i++) {
		int found = 0;
		for(int j=0; j < di->familycnt; j++) {
			if(di->families[j].id == tasks[i].family) {
				found = 1;
				FamilySpec* f = &di->families[j];
				f->flags |= tasks[i].flags;
				f->cnt++;
				f->inds = realloc(f->inds,
					f->cnt*sizeof(uint32_t));
				f->inds[f->cnt-1] = di->taskcnt;
			}
		}

		if(!found) {
			di->familycnt++;
			di->families = realloc(di->families,
				di->familycnt*sizeof(FamilySpec));

			di->families[di->familycnt-1] = (FamilySpec){
				.id = tasks[i].family,
				.flags = tasks[i].flags,
				.cnt = 1,
				.inds = malloc(sizeof(uint32_t)),
			};
			di->families[di->familycnt-1].inds[0] = di->taskcnt;
		}

		indices[i] = di->taskcnt;
		di->taskcnt++;
	}
}

static VkBool32 checkPDev(const VvVk_1_0* vk, VvVkB_DevInfo* di,
	VkInstance inst, VkPhysicalDevice pdev) {

	VkPhysicalDeviceProperties pdp;
	vk->GetPhysicalDeviceProperties(pdev, &pdp);
	if(pdp.apiVersion < di->ver) return VK_FALSE;

	uint32_t cnt = 0;
	vk->GetPhysicalDeviceQueueFamilyProperties(pdev, &cnt, NULL);
	VkQueueFamilyProperties* qfp = malloc(cnt*sizeof(VkQueueFamilyProperties));
	vk->GetPhysicalDeviceQueueFamilyProperties(pdev, &cnt, qfp);
	for(int i=0; i < di->familycnt; i++) {
		int found = 0;
		for(int j=0; j<cnt; j++) {
			if((qfp[j].queueFlags & di->families[i].flags) ==
				di->families[i].flags) {

				found = 1;
				if(qfp[j].queueCount < di->families[i].cnt) {
					free(qfp);
					return VK_FALSE;
				}
				qfp[j].queueCount -= di->families[i].cnt;
				break;
			}
		}
		if(!found) {
			free(qfp);
			return VK_FALSE;
		}
	}
	free(qfp);

	// The custom check is last, of course.
	if(di->valid) return di->valid(vk, di->validudata, pdev);
	else return VK_TRUE;
}

static VkBool32 compPDevs(const VvVk_1_0* vk, VvVkB_DevInfo* di,
	VkInstance inst, VkPhysicalDevice a, VkPhysicalDevice b) {

	if(di->comp) return di->comp(vk, di->compudata, a, b);
	else return VK_FALSE;
}

static VkResult choosePDev(const VvVk_1_0* vk, VvVkB_DevInfo* di,
	VkInstance inst, VkPhysicalDevice* pdev) {
	VkResult r;

	uint32_t pdevcnt = 0;
	r = vk->EnumeratePhysicalDevices(inst, &pdevcnt, NULL);
	if(r<0) return r;
	VkPhysicalDevice* pdevs = malloc(pdevcnt*sizeof(VkPhysicalDevice));
	r = vk->EnumeratePhysicalDevices(inst, &pdevcnt, pdevs);
	if(r<0) {
		free(pdevs);
		return r;
	}

	*pdev = NULL;
	for(int i=0; i<pdevcnt; i++) {
		VkPhysicalDevice pd = pdevs[i];
		if(checkPDev(vk, di, inst, pd)) {
			if(*pdev == NULL || compPDevs(vk, di, inst, pd, *pdev))
				*pdev = pd;
		}
	}

	free(pdevs);
	if(*pdev == NULL) return VK_ERROR_INCOMPATIBLE_DRIVER;
	else return VK_SUCCESS;
}

static VkResult createDev(const VvVk_1_0* vk, VvVkB_DevInfo* di,
	VkInstance inst, VkPhysicalDevice* pdev, VkDevice* dev,
	VvVkB_TaskInfo* tasks) {

	VkResult r = choosePDev(vk, di, inst, pdev);
	if(r < 0) return r;

	uint32_t cnt = 0;
	vk->GetPhysicalDeviceQueueFamilyProperties(*pdev, &cnt, NULL);
	VkQueueFamilyProperties* qfp = malloc(cnt*sizeof(VkQueueFamilyProperties));
	vk->GetPhysicalDeviceQueueFamilyProperties(*pdev, &cnt, qfp);


	uint32_t dqcicnt = 0;
	float** priss = NULL;
	int* sizes = NULL;
	VkDeviceQueueCreateInfo* dqci = NULL;

	for(int i=0; i < di->familycnt; i++) {
		FamilySpec* f = &di->families[i];

		int qfam;
		for(int j=0; j<cnt; j++) {
			if((qfp[j].queueFlags & f->flags) == f->flags
				&& qfp[j].queueCount >= f->cnt) {

				qfp[j].queueCount -= f->cnt;

				qfam = j;
				break;
			}
		}

		for(int j=0; j<dqcicnt; j++) {
			if(dqci[j].queueFamilyIndex == qfam) {
				int offset = sizes[j];
				sizes[j] += f->cnt;
				priss[j] = realloc(priss[j], sizes[j]*sizeof(float));
				dqci[j].pQueuePriorities = priss[j];
				for(int k=0; k < f->cnt; k++) {
					priss[qfam][offset+k] = 0;
					tasks[f->inds[k]] = (VvVkB_TaskInfo){
						.flags = f->flags,
						.family = qfam,
						.index = dqci[j].queueCount+k,
					};
				}
				dqci[j].queueCount += f->cnt;
				qfam = -1;
				break;
			}
		}
		if(qfam != -1) {
			dqcicnt++;
			priss = realloc(priss, dqcicnt*sizeof(float*));
			sizes = realloc(sizes, dqcicnt*sizeof(int));
			dqci = realloc(dqci, dqcicnt*sizeof(VkDeviceQueueCreateInfo));

			priss[dqcicnt-1] = malloc(f->cnt*sizeof(float));
			sizes[dqcicnt-1] = f->cnt;
			dqci[dqcicnt-1] = (VkDeviceQueueCreateInfo){
				.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
				.queueFamilyIndex = qfam,
				.queueCount = f->cnt,
				.pQueuePriorities = priss[dqcicnt-1],
			};

			for(int k=0; k < f->cnt; k++) {
				priss[dqcicnt-1][k] = 0;
				tasks[f->inds[k]] = (VvVkB_TaskInfo){
					.flags = f->flags,
					.family = qfam,
					.index = k,
				};
			}
		}
	}

	r = vk->CreateDevice(*pdev, &(VkDeviceCreateInfo){
		.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
		.enabledExtensionCount = di->extcnt,
		.ppEnabledExtensionNames = di->exts,
		.queueCreateInfoCount = dqcicnt,
		.pQueueCreateInfos = dqci,
	}, NULL, dev);

	for(int i=0; i<dqcicnt; i++) free(priss[i]);
	free(priss);
	free(sizes);
	free(qfp);
	free(dqci);
	for(int i=0; i < di->familycnt; i++) free(di->families[i].inds);
	free(di->families);
	free(di->exts);
	free(di);
	return r;
}

VvAPI const Vv_VulkanBoilerplate vVvkb_test = {
	.createInstInfo = createInstInfo,
	.createInstance = createInst,
	.setInstVersion = setIVer,
	.addLayers = addLays,
	.addInstExtensions = addIExts,

	.createDevInfo = createDevInfo,
	.createDevice = createDev,
	.addDevExtensions = addDExts,
	.setValidity = setValid,
	.setComparison = setComp,
	.getTaskCount = getTCount,
	.addTasks = addTs,
};

#endif // Vv_ENABLE_VULKAN
