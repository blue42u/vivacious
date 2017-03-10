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

static VkImageView iview;
VkFramebuffer fbuff;

void setupFBuff() {
	VkResult r;

	r = vk->CreateImageView(dev, &(VkImageViewCreateInfo){
		VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO, NULL,
		.image = image,
		.viewType = VK_IMAGE_VIEW_TYPE_2D,
		.format = format,
		.components = {},	// Identity map
		.subresourceRange = {
			VK_IMAGE_ASPECT_COLOR_BIT,
			0, 1,
			0, 1,
		},
	}, NULL, &iview);
	if(r<0) error("creating image view", r);

	r = vk->CreateFramebuffer(dev, &(VkFramebufferCreateInfo){
		VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO, NULL,
		.renderPass = rpass,
		.attachmentCount = 1, .pAttachments = &iview,
		.width = extent.width, .height = extent.height,
		.layers = 1,
	}, NULL, &fbuff);
	if(r<0) error("creating framebuffer", r);
}

void cleanupFBuff() {
	vk->DestroyFramebuffer(dev, fbuff, NULL);
	vk->DestroyImageView(dev, iview, NULL);
}
