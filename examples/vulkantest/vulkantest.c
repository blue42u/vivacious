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

#include <vivacious/vulkan.h>
#include <vivacious/window.h>
#include <stdio.h>
#include <stdarg.h>

// TMP
#include <unistd.h>

int error(const char* format, ...) {
	va_list list;
	va_start(list, format);
	vfprintf(stderr, format, list);
	va_end(list);
	return 1;
}

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
	case VK_DEBUG_REPORT_INFORMATION_BIT_EXT: printf("32"); break;
	case VK_DEBUG_REPORT_WARNING_BIT_EXT: printf("1;35"); break;
	case VK_DEBUG_REPORT_PERFORMANCE_WARNING_BIT_EXT: printf("35"); break;
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

int main() {
	const VvVulkan* vkapi = vVloadVulkan_lib();
	if(!vkapi) return error("Error loading VvVulkan!\n");
	VvVulkanBinding* vkb = vkapi->Create();
	const VvVulkan_1_0* vk = vkapi->core->vk_1_0(vkb);
	const VvVulkan_EXT_debug_report* vkdr
		= vkapi->ext->EXT_debug_report(vkb);

	VkInstance inst;
	const char* exts[] = { "VK_EXT_debug_report" };
	const char* lays[] = { "VK_LAYER_LUNARG_standard_validation" };
	VkInstanceCreateInfo ico = {
		VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
		NULL, 0,
		NULL,
		1, lays,
		1, exts
	};
	VkResult r = vk->CreateInstance(&ico, NULL, &inst);
	vkapi->LoadInstance(vkb, inst, VK_FALSE);
	if(r<0) error("Error creating instance: %d!\n", r);

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
	VkDebugReportCallbackEXT drc;
	vkdr->CreateDebugReportCallbackEXT(inst, &drcci, NULL, &drc);

	uint32_t cnt = 1;
	VkPhysicalDevice pdev;
	r = vk->EnumeratePhysicalDevices(inst, &cnt, &pdev);
	if(r<0) error("Error enum'ing PDevs: %d!\n", r);

	VkPhysicalDeviceProperties pdp;
	vk->GetPhysicalDeviceProperties(pdev, &pdp);
	printf("Vk version loaded: %d.%d.%d!\n",
		VK_VERSION_MAJOR(pdp.apiVersion),
		VK_VERSION_MINOR(pdp.apiVersion),
		VK_VERSION_PATCH(pdp.apiVersion));

	const float pris[] = { 0 };
	VkDeviceQueueCreateInfo dqci = {
		VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
		NULL, 0,
		0, 1, pris
	};
	VkDeviceCreateInfo dci = {
		VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
		NULL, 0,
		1, &dqci,
		1, lays,
		0, NULL,
		NULL
	};
	VkDevice dev;
	r = vk->CreateDevice(pdev, &dci, NULL, &dev);
	vkapi->LoadDevice(vkb, dev, VK_TRUE);
	if(r<0) error("Error creating device: %d!\n", r);

	const VvWindow* winapi = vVloadWindow_X();
	VvWiConnection* conn = winapi->Connect();

	int ext[2] = {0,0};
	winapi->GetScreenSize(conn, ext);
	printf("Screen size?: %d,%d\n", ext[0], ext[1]);

	VvWiWindow* win = winapi->CreateWindow(conn, ext[0], ext[1], 0);
	winapi->SetTitle(conn, win, "Example Vulkan Thing!");
	winapi->ShowWindow(conn, win);

	winapi->AddVulkan(conn, vkapi, vkb, inst);
	VkSurfaceKHR surf = winapi->CreateVkSurface(conn, win);

	sleep(2);

	winapi->DestroyWindow(conn, win);
	vk->DestroyDevice(dev, NULL);
	vkdr->DestroyDebugReportCallbackEXT(inst, drc, NULL);
	vk->DestroyInstance(inst, NULL);
	vkapi->Destroy(vkb);

	return 0;
}
