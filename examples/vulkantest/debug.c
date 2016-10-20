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

#include "common.h"

VkBool32 debugFunc(
	VkDebugReportFlagsEXT flag,
	VkDebugReportObjectTypeEXT type,
	uint64_t obj,
	size_t loc,
	int32_t code,
	const char* lay,
	const char* mess,
	void* udata) {

	printf("\e[");
	switch(flag) {
	// Normal green
	case VK_DEBUG_REPORT_INFORMATION_BIT_EXT: printf("32"); break;
	// Bold magenta
	case VK_DEBUG_REPORT_WARNING_BIT_EXT: printf("1;35"); break;
	// Normal magenta
	case VK_DEBUG_REPORT_PERFORMANCE_WARNING_BIT_EXT: printf("35"); break;
	// Bold red
	case VK_DEBUG_REPORT_ERROR_BIT_EXT: printf("1;31"); break;
	default: printf("");
	}
	printf("mDEBUG (");
	switch(type) {
	case VK_DEBUG_REPORT_OBJECT_TYPE_UNKNOWN_EXT: printf("unknown"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_INSTANCE_EXT: printf("instance"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_PHYSICAL_DEVICE_EXT: printf("physical device"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_DEVICE_EXT: printf("device"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_QUEUE_EXT: printf("queue"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_SEMAPHORE_EXT: printf("semaphore"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_COMMAND_BUFFER_EXT: printf("command buffer"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_FENCE_EXT: printf("fence"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_DEVICE_MEMORY_EXT: printf("device memory"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_BUFFER_EXT: printf("buffer"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_IMAGE_EXT: printf("image"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_EVENT_EXT: printf("event"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_QUERY_POOL_EXT: printf("query pool"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_BUFFER_VIEW_EXT: printf("buffer view"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_IMAGE_VIEW_EXT: printf("image view"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_SHADER_MODULE_EXT: printf("shader module"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_PIPELINE_CACHE_EXT: printf("pipeline cache"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_PIPELINE_LAYOUT_EXT: printf("pipeline layout"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_RENDER_PASS_EXT: printf("render pass"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_PIPELINE_EXT: printf("pipeline"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_DESCRIPTOR_SET_LAYOUT_EXT: printf("descriptor set layout"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_SAMPLER_EXT: printf("sampler"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_DESCRIPTOR_POOL_EXT: printf("descriptor pool"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_DESCRIPTOR_SET_EXT: printf("descriptor set"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_FRAMEBUFFER_EXT: printf("framebuffer"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_COMMAND_POOL_EXT: printf("command pool"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_SURFACE_KHR_EXT: printf("surface"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_SWAPCHAIN_KHR_EXT: printf("swapchain"); break;
	case VK_DEBUG_REPORT_OBJECT_TYPE_DEBUG_REPORT_EXT: printf("debug report"); break;
	default: printf("?????");
	}
	printf(":%lx @ %s): %s\e[m\n", obj, lay, mess);

	return VK_FALSE;
}

static const VvVk_EXT_debug_report* vkdr;
static VkDebugReportCallbackEXT drc;

void startDebug() {
	vkdr = vkapi.ext->EXT_debug_report(vkb);
	VkDebugReportCallbackCreateInfoEXT drcci = {
		VK_STRUCTURE_TYPE_DEBUG_REPORT_CALLBACK_CREATE_INFO_EXT,
		NULL,
		VK_DEBUG_REPORT_ERROR_BIT_EXT |
			VK_DEBUG_REPORT_WARNING_BIT_EXT |
			VK_DEBUG_REPORT_PERFORMANCE_WARNING_BIT_EXT |
//			VK_DEBUG_REPORT_INFORMATION_BIT_EXT |
			0,
		debugFunc,
		NULL
	};
	vkdr->CreateDebugReportCallbackEXT(com.inst, &drcci, NULL, &drc);
}

void endDebug() {
	vkdr->DestroyDebugReportCallbackEXT(com.inst, drc, NULL);
}
