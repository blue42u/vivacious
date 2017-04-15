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
	VvVkB_InstInfo* (*createInstInfo)(const VvC*, const char* name,
		uint32_t ver);
#ifdef Vv_vkb_ENABLED
#define vVvkb_createInstInfo(...) vVcore_FUNC(vkb, createInstInfo, __VA_ARGS__)
#endif

	// Create the Instance, freeing the InstInfo in the process.
	// Returns the VkResult from vkCreateInstance.
	VkResult (*createInstance)(const VvC*, VvVkB_InstInfo*,
		VkInstance*);
#ifdef Vv_vkb_ENABLED
#define vVvkb_createInstance(...) vVcore_FUNC(vkb, createInstance, __VA_ARGS__)
#endif

	// Set the minimum version of Vulkan to request for the Instance.
	// Defaults to 0.
	void (*setInstVersion)(const VvC*, VvVkB_InstInfo*, uint32_t version);
#ifdef Vv_vkb_ENABLED
#define vVvkb_setInstVersion(...) vVcore_FUNC(vkb, setInstVersion, __VA_ARGS__)
#endif

	// Add some layers to the Instance.
	// <names> is a pointer to an array of strings with a NULL sentinal.
	void (*addLayers)(const VvC*, VvVkB_InstInfo*, const char** names);
#ifdef Vv_vkb_ENABLED
#define vVvkb_addLayers(...) vVcore_FUNC(vkb, addLayers, __VA_ARGS__)
#endif

	// Add some extensions to the Instance.
	// <names> is a pointer to an array of strings with a NULL sentinal.
	void (*addInstExtensions)(const VvC*, VvVkB_InstInfo*, const char** names);
#ifdef Vv_vkb_ENABLED
#define vVvkb_addInstExtensions(...) vVcore_FUNC(vkb, addInstExtensions, __VA_ARGS__)
#endif

	// Allocate some space for a DevInfo.
	// <ver> is the minimum allowed API version for the PhysicalDevice.
	VvVkB_DevInfo* (*createDevInfo)(const VvC*, uint32_t ver);
#ifdef Vv_vkb_ENABLED
#define vVvkb_createDevInfo(...) vVcore_FUNC(vkb, createDevInfo, __VA_ARGS__)
#endif

	// Create the Device, freeing the DevInfo in the process.
	// Returns the VkResult from vkCreateDevice.
	// <queues> should point to an array of a size greater than
	// or equal to the count returned by getTaskCount.
	VkResult (*createDevice)(const VvC*, VvVkB_DevInfo*,
		VkInstance, VkPhysicalDevice*, VkDevice*,
		VvVkB_QueueSpec* queues);
#ifdef Vv_vkb_ENABLED
#define vVvkb_createDevice(...) vVcore_FUNC(vkb, createDevice, __VA_ARGS__)
#endif

	// Add some extensions to the Device.
	// <names> is a pointer to an array of strings with a NULL sentinal.
	void (*addDevExtensions)(const VvC*, VvVkB_DevInfo*, const char** names);
#ifdef Vv_vkb_ENABLED
#define vVvkb_addDevExtensions(...) vVcore_FUNC(vkb, addDevExtensions, __VA_ARGS__)
#endif

	// Set the custom validity check for the DevInfo.
	// Defaults to a function that always returns VK_TRUE.
	// <func> should return VK_TRUE if the given PhysicalDevice is usable
	// by the application, VK_FALSE otherwise. <udata> is passed as the
	// first argument to <func>.
	void (*setValidity)(const VvC*, VvVkB_DevInfo*, VkBool32 (*func)(
		void*, VkPhysicalDevice), void* udata);
#ifdef Vv_vkb_ENABLED
#define vVvkb_setValidity(...) vVcore_FUNC(vkb, setValidity, __VA_ARGS__)
#endif

	// Set the custom comparison for the DevInfo.
	// Defaults to a function that always returns VK_FALSE.
	// <udata> is passed as the first argument to <func>.
	// <func> should return VK_TRUE if <a> is "better" than <b>,
	// VK_FALSE otherwise.
	void (*setComparison)(const VvC*, VvVkB_DevInfo*, VkBool32 (*func)(
		void*, VkPhysicalDevice a, VkPhysicalDevice b), void* udata);
#ifdef Vv_vkb_ENABLED
#define vVvkb_setComparison(...) vVcore_FUNC(vkb, setComparison, __VA_ARGS__)
#endif

	// Get the number of tasks in the DevInfo (so far).
	int (*getTaskCount)(const VvC*, VvVkB_DevInfo*);
#ifdef Vv_vkb_ENABLED
#define vVvkb_getTaskCount(...) vVcore_FUNC(vkb, getTaskCount, __VA_ARGS__)
#endif

	// Add a new task. The final index of the task will be the result of
	// getTaskCount just before calling newTask.
	VvVkB_TaskInfo* (*newTask)(const VvC*, VvVkB_DevInfo*);
#ifdef Vv_vkb_ENABLED
#define vVvkb_newTask(...) vVcore_FUNC(vkb, newTask, __VA_ARGS__)
#endif
};

// TEST test, test Test test.
extern const Vv_VulkanBoilerplate vVvkb_Test;

#endif // H_vivacious_vkbplate
