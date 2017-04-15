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

#ifndef H_vivacious_vkmemory
#define H_vivacious_vkmemory

#include <vivacious/core.h>
#include <vivacious/vulkan.h>

// The handle for the Pool of allocated (and allocatable) memory. It is
// assumed that only one pool will be used.
_Vv_TYPEDEF(VvVkM_Pool);

_Vv_STRUCT(Vv_VulkanMemoryManager) {
	// Create a new Pool, setup for the card being used.
	VvVkM_Pool* (*create)(const Vv*, VkPhysicalDevice, VkDevice);
#ifdef Vv_vkm_ENABLED
#define vVvkm_create(...) vVcore_FUNC(vkm, create, __VA_ARGS__)
#endif

	// Destroy a Pool, freeing any device memory accociated with it.
	void (*destroy)(const Vv*, VvVkM_Pool*);
#ifdef Vv_vkm_ENABLED
#define vVvkm_destroy(...) vVcore_FUNC(vkm, destroy, __VA_ARGS__)
#endif

	// Register a resource, to batch the allocation and binding process.
	// This can allow the implementation to better optimize allocation.
	// The actual flags used for `ideal` are `ideal | required`. In other
	// words, the required flags are always present and required.
	void (*registerBuffer)(const Vv*, VvVkM_Pool*, VkBuffer,
		VkMemoryPropertyFlags ideal, VkMemoryPropertyFlags required);
	void (*registerImage)(const Vv*, VvVkM_Pool*, VkImage,
		VkMemoryPropertyFlags ideal, VkMemoryPropertyFlags required);
#ifdef Vv_vkm_ENABLED
#define vVvkm_registerBuffer(...) vVcore_FUNC(vkm, registerBuffer, __VA_ARGS__)
#define vVvkm_registerImage(...) vVcore_FUNC(vkm, registerImage, __VA_ARGS__)
#endif

	// Bind any resources that are currently registered. Returns an error
	// if any errors in allocation and binding are incountered.
	VkResult (*bind)(const Vv*, VvVkM_Pool*);
#ifdef Vv_vkm_ENABLED
#define vVvkm_bind(...) vVcore_FUNC(vkm, bind, __VA_ARGS__)
#endif

	// Map the memory for a resource.
	VkResult (*mapBuffer)(const Vv*, VvVkM_Pool*, VkBuffer, void**);
	VkResult (*mapImage)(const Vv*, VvVkM_Pool*, VkImage, void**);
#ifdef Vv_vkm_ENABLED
#define vVvkm_mapBuffer(...) vVcore_FUNC(vkm, mapImage, __VA_ARGS__)
#define vVvkm_mapImage(...) vVcore_FUNC(vkm, mapBuffer, __VA_ARGS__)
#endif

	// Unmap the memory for a resource.
	void (*unmapBuffer)(const Vv*, VvVkM_Pool*, VkBuffer);
	void (*unmapImage)(const Vv*, VvVkM_Pool*, VkImage);
#ifdef Vv_vkm_ENABLED
#define vVvkm_unmapBuffer(...) vVcore_FUNC(vkm, unmapBuffer, __VA_ARGS__)
#define vVvkm_unmapImage(...) vVcore_FUNC(vkm, unmapImage, __VA_ARGS__)
#endif

	// Get the memory range for a resource. Can be used either to map
	// the memory manually, or to flush or invalidate the resource.
	VkMappedMemoryRange (*getRangeBuffer)(const Vv*, VvVkM_Pool*, VkBuffer);
	VkMappedMemoryRange (*getRangeImage)(const Vv*, VvVkM_Pool*, VkImage);
#ifdef Vv_vkm_ENABLED
#define vVvkm_getRangeBuffer(...) vVcore_FUNC(vkm, getRangeBuffer, __VA_ARGS__)
#define vVvkm_getRangeImage(...) vVcore_FUNC(vkm, getRangeImage, __VA_ARGS__)
#endif

	// Possibly unbind a resource, and register it so a later `bind`
	// will place it in a (better?) place. May also no-op. Imp-dependant.
	// Assume the contents of the resource are undefined after `bind`.
	void (*unbindBuffer)(const Vv*, VvVkM_Pool*, VkBuffer);
	void (*unbindImage)(const Vv*, VvVkM_Pool*, VkImage);
#ifdef Vv_vkm_ENABLED
#define vVvkm_unbindBuffer(...) vVcore_FUNC(vkm, unbindBuffer, __VA_ARGS__)
#define vVvkm_unbindImage(...) vVcore_FUNC(vkm, unbindImage, __VA_ARGS__)
#endif

	// Destroy a resource, deallocating its memory if needed.
	void (*destroyBuffer)(const Vv*, VvVkM_Pool*, VkBuffer);
	void (*destroyImage)(const Vv*, VvVkM_Pool*, VkImage);
#ifdef Vv_vkm_ENABLED
#define vVvkm_destroyBuffer(...) vVcore_FUNC(vkm, destroyBuffer, __VA_ARGS__)
#define vVvkm_destroyImage(...) vVcore_FUNC(vkm, destroyImage, __VA_ARGS__)
#endif
};

// TEST test, test Test test.
extern const Vv_VulkanMemoryManager vVvkm_Test;

#endif // H_vivacious_vkmemory
