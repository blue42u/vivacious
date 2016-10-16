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

#ifndef H_common
#define H_common

#include <vivacious/vulkan.h>

#include <stdio.h>	// Since this is a test, after all.
#include <stdlib.h>

// A wrapper for vfprintf to print to stderr, then exit's with 1.
void error(const char*, ...);

// The pieces of Vulkan this test uses commonly.
extern const VvVulkan_1_0* vk;
extern const VvVulkan_KHR_surface* vks;

// The actual Vulkan binding, for those extra bits.
extern const VvVulkan* vkapi;
extern VvVulkanBinding* vkb;

// Standard common pieces.
struct Common {
	VkInstance inst;
	VkPhysicalDevice pdev;
	VkDevice dev;
	VkSurfaceKHR surf;
};
extern struct Common com;

// And now the functions that do specific tasks around here.
void loadVulkan();
void unloadVulkan();
void createInst();
void destroyInst();
void createDev();
void destroyDev();
void createWindow();
void destroyWindow();
void startDebug();
void endDebug();

#endif // H_common
