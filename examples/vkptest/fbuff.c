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

static VkImageView* iviews;
VkFramebuffer* fbuffs;

void setupFBuff() {
	VkResult r;

	iviews = malloc(imageCount*sizeof(VkImageView));
	for(int i=0; i<imageCount; i++) {
		r = vVvk10_CreateImageView(dev, &(VkImageViewCreateInfo){
			VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO, NULL,
			.image = images[i],
			.viewType = VK_IMAGE_VIEW_TYPE_2D,
			.format = format,
			.components = {},	// Identity map
			.subresourceRange = {
				VK_IMAGE_ASPECT_COLOR_BIT,
				0, 1,
				0, 1,
			},
		}, NULL, &iviews[i]);
		if(r<0) error("creating image view", r);
	}

	fbuffs = malloc(imageCount*sizeof(VkFramebuffer));
	for(int i=0; i<imageCount; i++) {
		r = vVvk10_CreateFramebuffer(dev, &(VkFramebufferCreateInfo){
			VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO, NULL,
			.renderPass = rpass,
			.attachmentCount = 1, .pAttachments = &iviews[i],
			.width = extent.width, .height = extent.height,
			.layers = 1,
		}, NULL, &fbuffs[i]);
		if(r<0) error("creating framebuffer", r);
	}
}

void cleanupFBuff() {
	for(int i=0; i<imageCount; i++) {
		vVvk10_DestroyFramebuffer(dev, fbuffs[i], NULL);
		vVvk10_DestroyImageView(dev, iviews[i], NULL);
	}
	free(fbuffs);
	free(iviews);
}
