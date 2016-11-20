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

// A structure used to return the final Task information.
_Vv_STRUCT(VvVkB_TaskInfo) {
	uint32_t family;
	uint32_t index;
};

_Vv_STRUCT(Vv_VulkanBoilerplate) {
	// Allocate some space for the InstInfo.
	// <name> is the reported name of the application, and
	// <ver> is the reported version.
	VvVkB_InstInfo* (*createInstInfo)(const char* name, uint32_t ver);

	// Create the Instance, freeing the InstInfo in the process.
	// Returns the VkResult from vkCreateInstance.
	VkResult (*createInstance)(const VvVk_1_0*, VvVkB_InstInfo*,
		VkInstance*);

	// Set the minimum version of Vulkan to request for the Instance.
	// Defaults to 0.
	void (*setInstVersion)(VvVkB_InstInfo*, uint32_t version);

	// Add some layers to the Instance.
	// <names> is a pointer to an array of strings with a NULL sentinal.
	void (*addLayers)(VvVkB_InstInfo*, const char** names);

	// Add some extensions to the Instance.
	// <names> is a pointer to an array of strings with a NULL sentinal.
	void (*addInstExtensions)(VvVkB_InstInfo*, const char** names);

	// Allocate some space for a DevInfo.
	// <ver> is the minimum allowed API version for the PhysicalDevice.
	VvVkB_DevInfo* (*createDevInfo)(uint32_t ver);

	// Create the Device, freeing the DevInfo in the process.
	// Returns the VkResult from vkCreateDevice.
	// <tasks> should point to an array of TaskInfo of a size greater than
	// or equal to the count returned by getTaskCount.
	VkResult (*createDevice)(const VvVk_1_0*, VvVkB_DevInfo*,
		VkInstance, VkPhysicalDevice*, VkDevice*,
		VvVkB_TaskInfo* tasks);

	// Add some extensions to the Device.
	// <names> is a pointer to an array of strings with a NULL sentinal.
	void (*addDevExtensions)(VvVkB_DevInfo*, const char** names);

	// Set the custom validity check for the DevInfo.
	// Defaults to a function that always returns VK_TRUE.
	// <func> should return VK_TRUE if the given PhysicalDevice is usable
	// by the application, VK_FALSE otherwise. <udata> is passed as the
	// first argument to <func>.
	void (*setValidity)(VvVkB_DevInfo*, VkBool32 (*func)(
		void*, VkPhysicalDevice), void* udata);

	// Set the custom comparison for the DevInfo.
	// Defaults to a function that always returns VK_FALSE.
	// <udata> is passed as the first argument to <func>.
	// <func> should return VK_TRUE if <a> is "better" than <b>,
	// VK_FALSE otherwise.
	void (*setComparison)(VvVkB_DevInfo*, VkBool32 (*func)(
		void*, VkPhysicalDevice a, VkPhysicalDevice b), void* udata);

	// Get the number of tasks in the DevInfo (so far).
	int (*getTaskCount)(VvVkB_DevInfo*);

	// Add a new task. Returns the final index for the task.
	int (*addTask)(VvVkB_DevInfo*, VkQueueFlags flags, int familyid,
		float priority);
};

// This is a structure to aid with management and adding of tasks.
// Since only the macros use it, this structure can change freely. Mostly.
_Vv_STRUCT(VvVkB_TaskSpec) {
	VkQueueFlags flags;
	int fam;
	float pri;
};

// A helper macro to deal with tasks. Usage:
// Vv_VKB_ADDTASK(<imp>, <devinfo*>, <taskspec or compound literal>);
// <imp> and <devinfo*> may be evaluated multiple times.
// The macro's "return value" is the index of the new task.
#define Vv_VKB_ADDTASK(I, D, S) ({ \
	VvVkB_TaskSpec ts = (S); \
\
	int t = (I).addTask((D), ts.flags, ts.fam, ts.pri); \
	t; \
})

// A helper macro to add many tasks. Usage:
// Vv_VKB_ADDTASKS(<imp>, <devinfo*>, <taskspecs[]>, <indices name[]>);
// The arguments may be evaluated multiple times. In addition, <taskspecs>
// must be the actual array, and not a pointer to it.
// <indices name> must be an identifier not used in the context of the "call",
// and will be defined to be an int[].
// This macro is not an expression.
#define Vv_VKB_ADDTASKS(I, D, T, N) \
int N[sizeof(T)/sizeof(VvVkB_TaskSpec)]; \
for(int i=0; i<sizeof(T)/sizeof(VvVkB_TaskSpec); i++) \
	N[i] = Vv_VKB_ADDTASK(I, D, T[i]);

// TEST test, test Test test.
extern const Vv_VulkanBoilerplate vVvkb_test;

#endif // H_vivacious_vkbplate
