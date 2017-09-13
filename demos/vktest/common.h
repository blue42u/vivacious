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

// The Vv structure
extern Vv V;

// Standard common pieces.
struct CBuffs {
	VkCommandBuffer readyRend;
	VkCommandBuffer readyPres;
	VkCommandBuffer blue;
	VkCommandBuffer red;
};
struct Common {
	VkInstance inst;
	VkPhysicalDevice pdev;
	uint32_t qfam;
	VkDevice dev;
	VkSurfaceKHR surf;
	VkSwapchainKHR schain;
	uint32_t simagecnt;
	VkImage* simages;
	VkQueue queue;
	union {
		struct CBuffs* cb;
		VkCommandBuffer* cbuffs;
	};
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
void createSChain();
void destroySChain();
void createCBuffs();
void destroyCBuffs();
void loadCBuffs();

#endif // H_common
