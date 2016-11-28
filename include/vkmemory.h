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

#ifndef H_vivacious_vkmemory
#define H_vivacious_vkmemory

#include <vivacious/core.h>
#include <vivacious/vulkan.h>

// The handle for the Pool of allocated (and allocatable) memory. It is
// assumed that only one pool will be used.
_Vv_TYPEDEF(VvVkM_Pool);

_Vv_STRUCT(Vv_VulkanMemoryManager) {
	// Create a new Pool, setup for the card being used.
	VvVkM_Pool* (*create)(const VvVk_Binding*, VkPhysicalDevice, VkDevice);

	// Destroy a Pool, freeing any device memory accociated with it.
	void (*destroy)(VvVkM_Pool*);

	// Register a resource, to batch the allocation and binding process.
	// This can allow the implementation to better optimize allocation.
	void (*registerBuffer)(VvVkM_Pool*, VkBuffer,
		VkMemoryPropertyFlags ideal, VkMemoryPropertyFlags required);
	void (*registerImage)(VvVkM_Pool*, VkImage,
		VkMemoryPropertyFlags ideal, VkMemoryPropertyFlags required);

	// Bind any resources that are currently registered.
	void (*bind)(VvVkM_Pool*);

	// Possibly unbind a resource, and register it so a later `bind`
	// will place it in a (better?) place. May also no-op. Imp-dependant.
	// Assume the contents of the resource are undefined after `bind`.
	void (*unbindBuffer)(VvVkM_Pool*, VkBuffer);
	void (*unbindImage)(VvVkM_Pool*, VkImage);

	// Destroy a resource, deallocating its memory if needed.
	void (*destroyBuffer)(VvVkM_Pool*, VkBuffer);
	void (*destroyImage)(VvVkM_Pool*, VkImage);
};

// TEST test, test Test test.
extern const Vv_VulkanMemoryManager vVvkm_test;

#endif // H_vivacious_vkmemory
