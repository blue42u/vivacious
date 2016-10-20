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

#include "common.h"
#include <stdarg.h>

void error(const char* format, ...) {
	va_list list;
	va_start(list, format);
	vfprintf(stderr, format, list);
	va_end(list);
	exit(1);
}

const VvVk_1_0* vk;
const VvVk_KHR_surface* vks;
const VvVk_KHR_swapchain* vkc;
const Vv_Vulkan* vkapi;
VvVk_Binding* vkb;

struct Common com;

void loadVulkan() {
	vkapi = vVvk_lib();
	if(!vkapi) error("Error loading VvVulkan!\n");

	vkb = vkapi->Create();
	vk = vkapi->core->vk_1_0(vkb);
	vks = vkapi->ext->KHR_surface(vkb);
	vkc = vkapi->ext->KHR_swapchain(vkb);
}

void unloadVulkan() {
	vkapi->Destroy(vkb);
}
