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

#include "vivacious/vulkan.h"
#include <stdio.h>

int main() {
	vV_Vulkan_1_0 vk;
	if(!vV_loadVulkan_1_0(&vk)) {
		printf("Error loading vulkan!\n");
		return 1;
	}

	VkInstance inst;
	const char* exts[] = { "VK_EXT_debug_report" };
	VkInstanceCreateInfo ico = {
		VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
		NULL, 0,
		NULL,
		0, NULL,
		1, exts
	};
	VkResult r = vk.CreateInstance(&ico, NULL, &inst);
	if(r < 0) printf("Error creating instance: %d\n", r);

	printf("Before I optimize: %p\n", vk.EnumeratePhysicalDevices);
	vk.optimizeInstance_vV(inst, &vk);
	printf("After I  optimize: %p\n", vk.EnumeratePhysicalDevices);

	return 0;
}
