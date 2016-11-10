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

#ifndef H_vivacious_vkbplate
#define H_vivacious_vkbplate

#include <vivacious/core.h>
#include <vivacious/vulkan.h>
#include <vivacious/window.h>

// A handle which collects information on the Instance to be created.
_Vv_TYPEDEF(VvVkB_InstInfo);

// A handle which collects info on the Device to be created.
_Vv_TYPEDEF(VvVkB_DevInfo);

_Vv_STRUCT(Vv_VulkanBoilerplate) {
	// Allocate some space for the InstInfo.
	// <name> is the reported name of the application, and
	// <ver> is the reported version.
	VvVkB_InstInfo* (*createInstInfo)(const char* name, uint32_t ver);

	// Set the version of Vulkan to request for the Instance
	void (*setInstVersion)(VvVkB_InstInfo*, uint32_t version);

	// Add some layers to the Instance.
	// <names> is a pointer to an array of strings with a NULL sentinal.
	void (*addLayers)(VvVkB_InstInfo*, const char** names);

	// Add some extensions to the Instance.
	// <names> is a pointer to an array of strings with a NULL sentinal.
	void (*addInstExtensions)(VvVkB_InstInfo*, const char** names);

	// Create the Instance, freeing the InstInfo in the process.
	// Returns the VkResult from vkCreateInstance.
	VkResult (*createInstance)(const VvVk_1_0*, VvVkB_InstInfo*,
		VkInstance*);

	// Allocate some space for a DevInfo.
	// <ver> is the minimum allowed API version for the PhysicalDevice.
	VvVkB_DevInfo* (*createDevInfo)(uint32_t ver);

	// Add some extensions to the Device.
	// <names> is a pointer to an array of strings with a NULL sentinal.
	void (*addDevExtensions)(VvVkB_DevInfo*, const char** names);

	// Create the Device, freeing the DevInfo in the process.
	// Returns the VkResult from vkCreateDevice.
	VkResult (*createDevice)(const VvVk_1_0*, VvVkB_DevInfo*,
		VkInstance, VkPhysicalDevice*, VkDevice*);
};

// TEST test, test Test test.
extern const Vv_VulkanBoilerplate vVvkb_test;

#endif // H_vivacious_vkbplate
