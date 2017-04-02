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

#include <vivacious/vkpipeline.h>
#include <vivacious/vkbplate.h>
#include <vivacious/vkmemory.h>
#include <stdio.h>
#include <stdlib.h>

#define vkp vVvkp_test		// Choose our imp.
#define vkb vVvkb_test		// Helpers for the test
#define vkm vVvkm_test
#define vVvk vVvk_lib

// Stuff from debug.c
void startDebug(const VvVk_Binding*, VkInstance);
void endDebug(VkInstance);
void error(const char* m, VkResult r);

extern VvVk_Binding vkbind;
extern VvVk_1_0* vk;
extern VvVk_KHR_swapchain* vkc;
extern VkInstance inst;
extern VkPhysicalDevice pdev;
extern VkDevice dev;
extern VkQueue q;
extern uint32_t qfam;

void setupVk();
void cleanupVk();

extern VkSurfaceKHR surf;

void setupWin();
void cleanupWin();

extern VkFormat format;
extern VkSwapchainKHR schain;
extern uint32_t imageCount;
extern VkImage* images;
extern VkExtent2D extent;

void setupSChain();
void cleanupSChain();

extern VkCommandPool cpool;
extern VkCommandBuffer* cbs;
extern VkCommandBuffer* cbi;

void setupCb();
void cleanupCb();

// This is from main.c
extern VkRenderPass rpass;

extern VkFramebuffer* fbuffs;

void setupFBuff();
void cleanupFBuff();

extern VkPipeline pipeline;
extern VkPipelineLayout playout;

void setupPipeline();
void cleanupPipeline();

#endif
