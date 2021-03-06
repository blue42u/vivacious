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

static VkPresentModeKHR choosePM(uint32_t cnt, VkPresentModeKHR* pms) {
	for(int i=0; i<cnt; i++)
		if(pms[i] == VK_PRESENT_MODE_IMMEDIATE_KHR) return pms[i];
	for(int i=0; i<cnt; i++)
		if(pms[i] == VK_PRESENT_MODE_FIFO_RELAXED_KHR) return pms[i];
	for(int i=0; i<cnt; i++)
		if(pms[i] == VK_PRESENT_MODE_MAILBOX_KHR) return pms[i];
	return VK_PRESENT_MODE_FIFO_KHR;
}

void createSChain() {
	VkSurfaceCapabilitiesKHR sc;
	VkResult r = vVvk_GetPhysicalDeviceSurfaceCapabilitiesKHR(com.pdev,
		com.surf, &sc);
	if(r<0) error("Error getting surface caps: %d!\n", r);

	uint32_t cnt = 0;

	vVvk_GetPhysicalDeviceSurfaceFormatsKHR(com.pdev, com.surf, &cnt, NULL);
	VkSurfaceFormatKHR* sfs = malloc(cnt*sizeof(VkSurfaceFormatKHR));
	vVvk_GetPhysicalDeviceSurfaceFormatsKHR(com.pdev, com.surf, &cnt, sfs);

	vVvk_GetPhysicalDeviceSurfacePresentModesKHR(com.pdev, com.surf,
		&cnt, NULL);
	VkPresentModeKHR* pms = malloc(cnt*sizeof(VkPresentModeKHR));
	vVvk_GetPhysicalDeviceSurfacePresentModesKHR(com.pdev, com.surf,
		&cnt, pms);
	VkPresentModeKHR pm = choosePM(cnt, pms);
	free(pms);

	VkSwapchainCreateInfoKHR sci = {
		VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR, NULL, 0,
		com.surf, sc.minImageCount, sfs[0].format, sfs[0].colorSpace,
		sc.currentExtent, 1,
		VK_IMAGE_USAGE_TRANSFER_DST_BIT,
		VK_SHARING_MODE_EXCLUSIVE,
		0, NULL,
		sc.currentTransform, VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
		pm, VK_TRUE,
		NULL,
	};
	r = vVvk_CreateSwapchainKHR(com.dev, &sci, NULL, &com.schain);
	if(r<0) error("Error creating swapchain: %d!\n", r);

	free(sfs);

	r = vVvk_GetSwapchainImagesKHR(com.dev, com.schain,
		&com.simagecnt, NULL);
	if(r<0) error("Error getting swapchain images: %d!\n", r);
	com.simages = malloc(com.simagecnt*sizeof(VkImage));
	r = vVvk_GetSwapchainImagesKHR(com.dev, com.schain,
		&com.simagecnt, com.simages);
	if(r<0) error("Error getting swapchain images: %d!\n", r);
}

void destroySChain() {
	free(com.simages);
	vVvk_DestroySwapchainKHR(com.dev, com.schain, NULL);
}
