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

	int iextcnt;
	const char** iexts;
};

static VvVkB_InstInfo* createInstInfo(const char* name, uint32_t ver) {
	VvVkB_InstInfo* ii = malloc(sizeof(VvVkB_InstInfo));
	*ii = (VvVkB_InstInfo) {
		.appName = name, .appVer = ver,
		.apiVer = 0,	// No particular version required
		.laycnt = 0, .iextcnt = 0,
		.lays = NULL, .iexts = NULL,	// No layers or exts yet.
	};
	return ii;
}

static void setVer(VvVkB_InstInfo* ii, uint32_t ver) {
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
	if(ii->iextcnt == 0) ii->iexts = malloc(cnt*sizeof(char*));
	else ii->iexts = realloc(ii->iexts, (cnt+ii->iextcnt)*sizeof(char*));
	for(int i=0; i<cnt; i++)
		ii->iexts[ii->iextcnt + i] = names[i];
	ii->iextcnt += cnt;
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
		.enabledExtensionCount = ii->iextcnt,
		.ppEnabledExtensionNames = ii->iexts,
	}, NULL, inst);

	free(ii->lays);	free(ii->iexts);
	free(ii);
	return r;
}

VvAPI const Vv_VulkanBoilerplate vVvkb_test = {
	.createInstInfo = createInstInfo,
	.setVersion = setVer,
	.addLayers = addLays,
	.addInstExtensions = addIExts,
	.createInstance = createInst,
};

#endif // Vv_ENABLE_VULKAN
