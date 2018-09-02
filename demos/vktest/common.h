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

#ifndef H_common
#define H_common

#define Vv_CHOICE V
#include <vivacious/vulkan.h>

#include <stdio.h>	// Since this is a test, after all.
#include <stdlib.h>

// A wrapper for vfprintf to print to stderr, then exit's with 1.
void error(const char*, ...);

// Standard common pieces.
struct CBuffs {
	VvVkCommandBuffer* readyRend;
	VvVkCommandBuffer* readyPres;
	VvVkCommandBuffer* blue;
	VvVkCommandBuffer* red;
};
struct Common {
	VvVk* vk;
	VvVkInstance* inst;
	VvVkPhysicalDevice* pdev;
	uint32_t qfam;
	VvVkDevice* dev;
	VkQueue queue;
	union {
		struct CBuffs* cb;
		VvVkCommandBuffer** cbuffs;
	};
};
extern struct Common com;

// And now the functions that do specific tasks around here.
void startDebug();
void endDebug();
void loadVulkan();
void unloadVulkan();
void createInst();
void destroyInst();
void createDev();
void destroyDev();
void createCBuffs();
void destroyCBuffs();

#endif // H_common
