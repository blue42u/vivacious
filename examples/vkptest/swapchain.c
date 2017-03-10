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

#include "common.h"

VkFormat format;
VkImage image;
VkExtent2D extent;
VkSwapchainKHR schain;

static VvVk_KHR_surface* vks;
static VvVk_KHR_swapchain* vkc;

static VkPresentModeKHR choosePM(uint32_t cnt, VkPresentModeKHR* pms) {
	for(int i=0; i<cnt; i++)
		if(pms[i] == VK_PRESENT_MODE_IMMEDIATE_KHR) return pms[i];
	for(int i=0; i<cnt; i++)
		if(pms[i] == VK_PRESENT_MODE_FIFO_RELAXED_KHR) return pms[i];
	for(int i=0; i<cnt; i++)
		if(pms[i] == VK_PRESENT_MODE_MAILBOX_KHR) return pms[i];
	return VK_PRESENT_MODE_FIFO_KHR;
}

void setupSChain() {
	vks = vkbind.ext->KHR_surface;
	vkc = vkbind.ext->KHR_swapchain;

	VkBool32 supported;
	VkResult r = vks->GetPhysicalDeviceSurfaceSupportKHR(pdev, qfam, surf,
		&supported);
	if(r<0) error("reading surface support", r);
	if(!supported) error("surface not supported", 0);

	VkSurfaceCapabilitiesKHR sc;
	r = vks->GetPhysicalDeviceSurfaceCapabilitiesKHR(pdev, surf, &sc);
	if(r<0) error("getting surface caps", r);

	uint32_t cnt = 0;

	vks->GetPhysicalDeviceSurfaceFormatsKHR(pdev, surf, &cnt, NULL);
	VkSurfaceFormatKHR* sfs = malloc(cnt*sizeof(VkSurfaceFormatKHR));
	vks->GetPhysicalDeviceSurfaceFormatsKHR(pdev, surf, &cnt, sfs);

	vks->GetPhysicalDeviceSurfacePresentModesKHR(pdev, surf, &cnt, NULL);
	VkPresentModeKHR* pms = malloc(cnt*sizeof(VkPresentModeKHR));
	vks->GetPhysicalDeviceSurfacePresentModesKHR(pdev, surf, &cnt, pms);
	VkPresentModeKHR pm = choosePM(cnt, pms);
	free(pms);

	format = sfs[0].format;
	extent = sc.currentExtent;
	VkSwapchainCreateInfoKHR sci = {
		VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR, NULL, 0,
		surf, sc.minImageCount, format, sfs[0].colorSpace,
		extent, 1,
		VK_IMAGE_USAGE_TRANSFER_DST_BIT,
		VK_SHARING_MODE_EXCLUSIVE,
		0, NULL,
		sc.currentTransform, VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
		pm, VK_TRUE,
		NULL,
	};
	r = vkc->CreateSwapchainKHR(dev, &sci, NULL, &schain);
	if(r<0) error("Error creating swapchain: %d!\n", r);

	free(sfs);

	r = vkc->GetSwapchainImagesKHR(dev, schain, &cnt, NULL);
	if(r<0) error("Error getting swapchain images: %d!\n", r);
	cnt = 1;
	r = vkc->GetSwapchainImagesKHR(dev, schain, &cnt, &image);
	if(r<0) error("Error getting swapchain images: %d!\n", r);
}

void cleanupSChain() {
	vkc->DestroySwapchainKHR(dev, schain, NULL);
}
