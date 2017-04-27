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

struct VvVkB_InstInfo {
	const char* appName;
	uint32_t appVer;
	uint32_t apiVer;

	int laycnt;
	const char** lays;

	int extcnt;
	const char** exts;
};

static VvVkB_InstInfo* createInstInfo(const Vv* V, const char* name, uint32_t ver) {
	VvVkB_InstInfo* ii = malloc(sizeof(VvVkB_InstInfo));
	*ii = (VvVkB_InstInfo) {
		.appName = name, .appVer = ver,
		.apiVer = 0,	// No particular version required
		.laycnt = 0, .extcnt = 0,
		.lays = NULL, .exts = NULL,	// No layers or exts yet.
	};
	return ii;
}

static void setIVer(const Vv* V, VvVkB_InstInfo* ii, uint32_t ver) {
	ii->apiVer = ver;
}

static void addLays(const Vv* V, VvVkB_InstInfo* ii, const char** names) {
	int cnt;
	for(cnt = 0; names[cnt] != NULL; cnt++);
	if(ii->laycnt == 0) ii->lays = malloc(cnt*sizeof(char*));
	else ii->lays = realloc(ii->lays, (cnt+ii->laycnt)*sizeof(char*));
	for(int i=0; i<cnt; i++)
		ii->lays[ii->laycnt + i] = names[i];
	ii->laycnt += cnt;
}

static void addIExts(const Vv* V, VvVkB_InstInfo* ii, const char** names) {
	int cnt;
	for(cnt = 0; names[cnt] != NULL; cnt++);
	if(ii->extcnt == 0) ii->exts = malloc(cnt*sizeof(char*));
	else ii->exts = realloc(ii->exts, (cnt+ii->extcnt)*sizeof(char*));
	for(int i=0; i<cnt; i++)
		ii->exts[ii->extcnt + i] = names[i];
	ii->extcnt += cnt;
}

static VkResult createInst(const Vv* V, VvVkB_InstInfo* ii,
	VkInstance* inst) {

	VkResult r = vVvk10_CreateInstance(&(VkInstanceCreateInfo){
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

	void* validudata;
	VkBool32 (*valid)(void*, VkPhysicalDevice);

	void* compudata;
	VkBool32 (*comp)(void*, VkPhysicalDevice, VkPhysicalDevice);

	int taskcnt;
	int tasksize;
	VvVkB_TaskInfo* tasks;
};

static VvVkB_DevInfo* createDevInfo(const Vv* V, uint32_t ver) {
	VvVkB_DevInfo* di = malloc(sizeof(VvVkB_DevInfo));
	*di = (VvVkB_DevInfo){
		.ver = ver,
		.extcnt = 0, .exts = NULL,	// No extensions yet
		.valid = NULL, .comp = NULL,	// No custom functions yet
		.taskcnt = 0, .tasksize = 0,
		.tasks = NULL,			// No tasks yet
	};
	return di;
}

static void addDExts(const Vv* V, VvVkB_DevInfo* di, const char** names) {
	int cnt;
	for(cnt = 0; names[cnt] != NULL; cnt++);
	if(di->extcnt == 0) di->exts = malloc(cnt*sizeof(char*));
	else di->exts = realloc(di->exts, (cnt+di->extcnt)*sizeof(char*));
	for(int i=0; i<cnt; i++)
		di->exts[di->extcnt + i] = names[i];
	di->extcnt += cnt;
}

static void setValid(const Vv* V, VvVkB_DevInfo* di, VkBool32 (*f)(
	void*, VkPhysicalDevice), void* udata) {

	di->validudata = udata;
	di->valid = f;
}

static void setComp(const Vv* V, VvVkB_DevInfo* di, VkBool32 (*f)(
	void*, VkPhysicalDevice, VkPhysicalDevice), void* udata) {

	di->compudata = udata;
	di->comp = f;
}

static int getTCount(const Vv* V, VvVkB_DevInfo* di) {
	return di->taskcnt;
}

static VvVkB_TaskInfo* nextT(const Vv* V, VvVkB_DevInfo* di) {
	if(di->taskcnt == di->tasksize) {
		di->tasksize = 2*di->tasksize + 1;
		di->tasks = realloc(di->tasks,
			di->tasksize*sizeof(VvVkB_TaskInfo));
	}
	di->taskcnt++;
	return &di->tasks[di->taskcnt-1];
}

static VkBool32 queuePDev(const Vv* V, VvVkB_DevInfo* di,
	VkPhysicalDevice pdev, VvVkB_QueueSpec* qs, int** rcnts) {

	uint32_t cnt = 0;
	vVvk10_GetPhysicalDeviceQueueFamilyProperties(pdev, &cnt, NULL);
	VkQueueFamilyProperties* qfp = malloc(cnt*sizeof(VkQueueFamilyProperties));
	if(qfp == NULL) printf("NULL qfp!\n");
	vVvk10_GetPhysicalDeviceQueueFamilyProperties(pdev, &cnt, qfp);
	int* cnts = calloc(cnt, sizeof(int));
	for(int i=0; i < di->taskcnt; i++) {
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
	vVvk10_GetPhysicalDeviceProperties(pdev, &pdp);
	if(pdp.apiVersion < di->ver) return VK_FALSE;

	if(!queuePDev(V, di, pdev, qs, NULL)) return VK_FALSE;

	// The custom check is last, of course.
	if(di->valid) return di->valid(di->validudata, pdev);
	else return VK_TRUE;
}

static VkBool32 compPDevs(const Vv* V, VvVkB_DevInfo* di,
	VkInstance inst, VkPhysicalDevice a, VkPhysicalDevice b) {

	if(di->comp) return di->comp(di->compudata, a, b);
	else return VK_FALSE;
}

static VkResult choosePDev(const Vv* V, VvVkB_DevInfo* di,
	VkInstance inst, VkPhysicalDevice* pdev, VvVkB_QueueSpec* qs,
	int** cnts) {
	VkResult r;

	uint32_t pdevcnt = 0;
	r = vVvk10_EnumeratePhysicalDevices(inst, &pdevcnt, NULL);
	if(r<0) return r;
	VkPhysicalDevice* pdevs = malloc(pdevcnt*sizeof(VkPhysicalDevice));
	r = vVvk10_EnumeratePhysicalDevices(inst, &pdevcnt, pdevs);
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
	VkInstance inst, VkPhysicalDevice* pdev, VkDevice* dev,
	VvVkB_QueueSpec* qs) {

	int* fcnts;
	VkResult r = choosePDev(V, di, inst, pdev, qs, &fcnts);
	if(r < 0) {
		free(fcnts);
		return r;
	}

	uint32_t fcnt = 0;
	vVvk10_GetPhysicalDeviceQueueFamilyProperties(*pdev, &fcnt, NULL);

	int dqcicnt = 0;
	for(int i=0; i<fcnt; i++) if(fcnts[i] > 0) dqcicnt++;

	VkDeviceQueueCreateInfo* dqci = malloc(dqcicnt*sizeof(VkDeviceQueueCreateInfo));
	float* pris = malloc(di->taskcnt*sizeof(float));

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
			for(int j=0; j < di->taskcnt; j++)
				if(qs[j].family == i)
					pris[prioff + qs[j].index] =
						di->tasks[j].priority;
			prioff += fcnts[i];
		}
	}

	r = vVvk10_CreateDevice(*pdev, &(VkDeviceCreateInfo){
		.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
		.enabledExtensionCount = di->extcnt,
		.ppEnabledExtensionNames = di->exts,
		.queueCreateInfoCount = dqcicnt,
		.pQueueCreateInfos = dqci,
	}, NULL, dev);

	free(pris);
	free(dqci);
	free(fcnts);
	free(di->tasks);
	free(di->exts);
	free(di);
	return r;
}

const Vv_VulkanBoilerplate libVv_vkb_test = {
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
	.newTask = nextT,
};

#endif // Vv_ENABLE_VULKAN
