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

#ifndef H_vivacious_vkbplate
#define H_vivacious_vkbplate

#include <vivacious/core.h>
#include <vivacious/vulkan.h>

// A handle which collects information on the Instance to be created.
_Vv_TYPEDEF(VvVkB_InstInfo);

// A handle which collects info on the Device to be created.
_Vv_TYPEDEF(VvVkB_DevInfo);

// A structure which holds all the information that would be needed
// about a particular Task.
_Vv_STRUCT(VvVkB_TaskInfo) {
	VkQueueFlags flags;
	int family;
	float priority;
};

// A structure used to return the information for the Queue that was
// chosen for a Task.
_Vv_STRUCT(VvVkB_QueueSpec) {
	uint32_t family;
	uint32_t index;
};

_Vv_STRUCT(Vv_VulkanBoilerplate) {
	// Allocate some space for the InstInfo.
	// <name> is the reported name of the application, and
	// <ver> is the reported version.
	VvVkB_InstInfo* (*createInstInfo)(const Vv*, const char* name,
		uint32_t ver);
#ifdef Vv_vkb_ENABLED
#define vVvkb_createInstInfo(...) _vVcore_FUNC(vkb, createInstInfo, __VA_ARGS__)
#endif

	// Create the Instance, freeing the InstInfo in the process.
	// Returns the VkResult from vkCreateInstance.
	VkResult (*createInstance)(const Vv*, VvVkB_InstInfo*,
		VkInstance*);
#ifdef Vv_vkb_ENABLED
#define vVvkb_createInstance(...) _vVcore_FUNC(vkb, createInstance, __VA_ARGS__)
#endif

	// Set the minimum version of Vulkan to request for the Instance.
	// Defaults to 0.
	void (*setInstVersion)(const Vv*, VvVkB_InstInfo*, uint32_t version);
#ifdef Vv_vkb_ENABLED
#define vVvkb_setInstVersion(...) _vVcore_FUNC(vkb, setInstVersion, __VA_ARGS__)
#endif

	// Add some layers to the Instance.
	// <names> is a pointer to an array of strings with a NULL sentinal.
	void (*addLayers)(const Vv*, VvVkB_InstInfo*, const char** names);
#ifdef Vv_vkb_ENABLED
#define vVvkb_addLayers(...) _vVcore_FUNC(vkb, addLayers, __VA_ARGS__)
#endif

	// Add some extensions to the Instance.
	// <names> is a pointer to an array of strings with a NULL sentinal.
	void (*addInstExtensions)(const Vv*, VvVkB_InstInfo*, const char** names);
#ifdef Vv_vkb_ENABLED
#define vVvkb_addInstExtensions(...) _vVcore_FUNC(vkb, addInstExtensions, __VA_ARGS__)
#endif

	// Allocate some space for a DevInfo.
	// <ver> is the minimum allowed API version for the PhysicalDevice.
	VvVkB_DevInfo* (*createDevInfo)(const Vv*, uint32_t ver);
#ifdef Vv_vkb_ENABLED
#define vVvkb_createDevInfo(...) _vVcore_FUNC(vkb, createDevInfo, __VA_ARGS__)
#endif

	// Create the Device, freeing the DevInfo in the process.
	// Returns the VkResult from vkCreateDevice.
	// <queues> should point to an array of a size greater than
	// or equal to the count returned by getTaskCount.
	VkResult (*createDevice)(const Vv*, VvVkB_DevInfo*,
		VkInstance, VkPhysicalDevice*, VkDevice*,
		VvVkB_QueueSpec* queues);
#ifdef Vv_vkb_ENABLED
#define vVvkb_createDevice(...) _vVcore_FUNC(vkb, createDevice, __VA_ARGS__)
#endif

	// Add some extensions to the Device.
	// <names> is a pointer to an array of strings with a NULL sentinal.
	void (*addDevExtensions)(const Vv*, VvVkB_DevInfo*, const char** names);
#ifdef Vv_vkb_ENABLED
#define vVvkb_addDevExtensions(...) _vVcore_FUNC(vkb, addDevExtensions, __VA_ARGS__)
#endif

	// Set the custom validity check for the DevInfo.
	// Defaults to a function that always returns VK_TRUE.
	// <func> should return VK_TRUE if the given PhysicalDevice is usable
	// by the application, VK_FALSE otherwise. <udata> is passed as the
	// first argument to <func>.
	void (*setValidity)(const Vv*, VvVkB_DevInfo*, VkBool32 (*func)(
		void*, VkPhysicalDevice), void* udata);
#ifdef Vv_vkb_ENABLED
#define vVvkb_setValidity(...) _vVcore_FUNC(vkb, setValidity, __VA_ARGS__)
#endif

	// Set the custom comparison for the DevInfo.
	// Defaults to a function that always returns VK_FALSE.
	// <udata> is passed as the first argument to <func>.
	// <func> should return VK_TRUE if <a> is "better" than <b>,
	// VK_FALSE otherwise.
	void (*setComparison)(const Vv*, VvVkB_DevInfo*, VkBool32 (*func)(
		void*, VkPhysicalDevice a, VkPhysicalDevice b), void* udata);
#ifdef Vv_vkb_ENABLED
#define vVvkb_setComparison(...) _vVcore_FUNC(vkb, setComparison, __VA_ARGS__)
#endif

	// Get the number of tasks in the DevInfo (so far).
	int (*getTaskCount)(const Vv*, VvVkB_DevInfo*);
#ifdef Vv_vkb_ENABLED
#define vVvkb_getTaskCount(...) _vVcore_FUNC(vkb, getTaskCount, __VA_ARGS__)
#endif

	// Add a new task. The final index of the task will be the result of
	// getTaskCount just before calling newTask.
	VvVkB_TaskInfo* (*newTask)(const Vv*, VvVkB_DevInfo*);
#ifdef Vv_vkb_ENABLED
#define vVvkb_newTask(...) _vVcore_FUNC(vkb, newTask, __VA_ARGS__)
#endif
};
const Vv_VulkanBoilerplate* vVvkb_Default(const Vv*);

#endif // H_vivacious_vkbplate
