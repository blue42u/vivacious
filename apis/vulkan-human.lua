--[========================================================================[
   Copyright 2016-2018 Jonathon Anderson

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
--]========================================================================]

local human = {}

-- Some enums don't have enough entries to figure out their prefixes.
human.enumprefixes = {
	VkDeviceEventTypeEXT = 'VK_DEVICE_EVENT_TYPE',
	VkCommandBufferResetFlagBits = 'VK_COMMAND_BUFFER_RESET',
	VkInternalAllocationType = 'VK_INTERNAL_ALLOCATION_TYPE',
	VkCommandPoolResetFlagBits = 'VK_COMMAND_POOL_RESET',
	VkQueryControlFlagBits = 'VK_QUERY_CONTROL',
	VkAttachmentDescriptionFlagBits = 'VK_ATTACHMENT_DESCRIPTION',
	VkSurfaceCounterFlagBitsEXT = 'VK_SURFACE_COUNTER',
	VkValidationCacheHeaderVersionEXT = 'VK_VALIDATION_CACHE_HEADER_VERSION',
	VkDisplayEventTypeEXT = 'VK_DISPLAY_EVENT_TYPE',
	VkSparseMemoryBindFlagBits = 'VK_SPARSE_MEMORY_BIND',
	VkPipelineCacheHeaderVersion = 'VK_PIPELINE_CACHE_HEADER_VERSION',
	VkFenceCreateFlagBits = 'VK_FENCE_CREATE',
	VkDeviceQueueCreateFlagBits = 'VK_DEVICE_QUEUE_CREATE',
}

-- Sometimes a field will be marked as optional, but still have a length field
-- attached to it. Since there is no consistent way to check whether they should
-- be connected or not, we force a human's approval.
local optionallens = {
	VkPipelineViewportStateCreateInfo_pViewports = true,
	VkPipelineViewportSwizzleStateCreateInfoNV_pViewportSwizzles = true,
	VkDebugUtilsMessengerCallbackDataEXT_pQueueLabels = true,
	VkDebugUtilsMessengerCallbackDataEXT_pCmdBufLabels = true,
	VkPresentRegionsKHR_pRegions = false,
	VkPipelineMultisampleStateCreateInfo_pSampleMask = false,
	VkPresentTimesInfoGOOGLE_pTimes = false,
	VkDescriptorSetLayoutBinding_pImmutableSamplers = false,
	VkPresentInfoKHR_pResults = false,
	VkD3D12FenceSubmitInfoKHR_pWaitSemaphoreValues = true,
	VkD3D12FenceSubmitInfoKHR_pSignalSemaphoreValues = true,
	VkPipelineDiscardRectangleStateCreateInfoEXT_pDiscardRectangles = true,
	VkPipelineViewportStateCreateInfo_pScissors = true,
	VkPipelineCoverageModulationStateCreateInfoNV_pCoverageModulationTable = true,
	VkPresentRegionKHR_pRectangles = true,
	VkSubpassDescription_pResolveAttachments = true,
}

-- Some of the commands return arrays, which in Vulkan are done by calling the
-- command twice: once for the size, once to fill the data.
local enumerators = {
	vkEnumeratePhysicalDevices_pPhysicalDevices = true,
	vkGetPhysicalDeviceQueueFamilyProperties_pQueueFamilyProperties = true,
	vkEnumerateInstanceLayerProperties_pProperties = true,
	vkEnumerateInstanceExtensionProperties_pProperties = true,
	vkEnumerateDeviceLayerProperties_pProperties = true,
	vkEnumerateDeviceExtensionProperties_pProperties = true,
	vkGetImageSparseMemoryRequirements_pSparseMemoryRequirements = true,
	vkGetPhysicalDeviceSparseImageFormatProperties_pProperties = true,
	vkGetPipelineCacheData_pData = true,
	vkGetPhysicalDeviceDisplayPropertiesKHR_pProperties = true,
	vkGetPhysicalDeviceDisplayPlanePropertiesKHR_pProperties = true,
	vkGetDisplayPlaneSupportedDisplaysKHR_pDisplays = true,
	vkGetDisplayModePropertiesKHR_pProperties = true,
	vkGetPhysicalDeviceSurfaceFormatsKHR_pSurfaceFormats = true,
	vkGetPhysicalDeviceSurfacePresentModesKHR_pPresentModes = true,
	vkGetSwapchainImagesKHR_pSwapchainImages = true,
	vkGetPhysicalDeviceQueueFamilyProperties2_pQueueFamilyProperties = true,
	vkGetPhysicalDeviceSparseImageFormatProperties2_pProperties = true,
	vkEnumeratePhysicalDeviceGroups_pPhysicalDeviceGroupProperties = true,
	vkGetPhysicalDevicePresentRectanglesKHR_pRects = true,
	vkGetPastPresentationTimingGOOGLE_pPresentationTimings = true,
	vkGetPhysicalDeviceSurfaceFormats2KHR_pSurfaceFormats = true,
	vkGetImageSparseMemoryRequirements2_pSparseMemoryRequirements = true,
	vkGetValidationCacheDataEXT_pData = true,
	vkGetShaderInfoAMD_pInfo = true,
}
setmetatable(optionallens, {__index=function(_,k)
	return enumerators[k:match '^PFN_(.+)']
end})

-- We can guess some of the info about commands, but most of them are not able
-- to be checked for errors, thus requiring Human intervention. We just write it
-- out as a massive table, and put correct guessed entries here. See human.self.
local cmdinfo = {
	vkCreateInstance = {
		self = false, ret = 'pInstance',
	},
	vkDestroyInstance = {
		self = {owner = 1, 'self.real'},
	},
	vkEnumeratePhysicalDevices = {
		self = {owner = 1, 'self.real'}, ret = 'pPhysicalDevices',
	},
	vkGetDeviceProcAddr = {
		self = {owner = 1, 'self.real'},
	},
	vkGetInstanceProcAddr = {
		self = {owner = 1, 'self.real'},
	},
	vkGetPhysicalDeviceProperties = {
		self = {owner = 1, 'self.real'}, ret = 'pProperties',
	},
	vkGetPhysicalDeviceQueueFamilyProperties = {
		self = {owner = 1, 'self.real'}, ret = 'pQueueFamilyProperties',
	},
	vkGetPhysicalDeviceMemoryProperties = {
		self = {owner = 1, 'self.real'}, ret = 'pMemoryProperties',
	},
	vkGetPhysicalDeviceFeatures = {
		self = {owner = 1, 'self.real'}, ret = 'pFeatures',
	},
	vkGetPhysicalDeviceFormatProperties = {
		self = {owner = 1, 'self.real'}, ret = 'pFormatProperties',
	},
	vkGetPhysicalDeviceImageFormatProperties = {
		self = {owner = 1, 'self.real'}, ret = 'pImageFormatProperties',
	},
	vkCreateDevice = {
		self = {owner = 1, 'self.real'}, ret = 'pDevice',
	},
	vkDestroyDevice = {
		self = {owner = 1, 'self.real'},
	},
	vkEnumerateInstanceVersion = {
		self = false, ret = 'pApiVersion',
	},
	vkEnumerateInstanceLayerProperties = {
		self = false, ret = 'pProperties',
	},
	vkEnumerateInstanceExtensionProperties = {
		self = false, ret = 'pProperties',
	},
	vkEnumerateDeviceLayerProperties = {
		self = {owner = 1, 'self.real'}, ret = 'pProperties',
	},
	vkEnumerateDeviceExtensionProperties = {
		self = {owner = 1, 'self.real'}, ret = 'pProperties',
	},
	vkGetDeviceQueue = {
		self = {owner = 1, 'self.real'}, ret = 'pQueue',
	},
	vkQueueSubmit = {
		self = {owner = 1, 'self.real'},
	},
	vkQueueWaitIdle = {
		self = {owner = 1, 'self.real'},
	},
	vkDeviceWaitIdle = {
		self = {owner = 1, 'self.real'},
	},
	vkAllocateMemory = {
		self = {owner = 1, 'self.real'}, ret = 'pMemory',
	},
	vkFreeMemory = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkMapMemory = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'ppData',
	},
	vkUnmapMemory = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkFlushMappedMemoryRanges = {
		self = {owner = 1, 'self.real'},
	},
	vkInvalidateMappedMemoryRanges = {
		self = {owner = 1, 'self.real'},
	},
	vkGetDeviceMemoryCommitment = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'pCommittedMemoryInBytes',
	},
	vkGetBufferMemoryRequirements = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'pMemoryRequirements',
	},
	vkBindBufferMemory = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkGetImageMemoryRequirements = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'pMemoryRequirements',
	},
	vkBindImageMemory = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkGetImageSparseMemoryRequirements = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'pSparseMemoryRequirements',
	},
	vkGetPhysicalDeviceSparseImageFormatProperties = {
		self = {owner = 1, 'self.real'}, ret = 'pProperties',
	},
	vkQueueBindSparse = {
		self = {owner = 1, 'self.real'},
	},
	vkCreateFence = {
		self = {owner = 1, 'self.real'}, ret = 'pFence',
	},
	vkDestroyFence = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkResetFences = {
		self = {owner = 1, 'self.real'},
	},
	vkGetFenceStatus = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkWaitForFences = {
		self = {owner = 1, 'self.real'},
	},
	vkCreateSemaphore = {
		self = {owner = 1, 'self.real'}, ret = 'pSemaphore',
	},
	vkDestroySemaphore = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkCreateEvent = {
		self = {owner = 1, 'self.real'}, ret = 'pEvent',
	},
	vkDestroyEvent = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkGetEventStatus = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkSetEvent = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkResetEvent = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkCreateQueryPool = {
		self = {owner = 1, 'self.real'}, ret = 'pQueryPool',
	},
	vkDestroyQueryPool = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkGetQueryPoolResults = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'pData',
	},
	vkCreateBuffer = {
		self = {owner = 1, 'self.real'}, ret = 'pBuffer',
	},
	vkDestroyBuffer = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkCreateBufferView = {
		self = {owner = 1, 'self.real'}, ret = 'pView',
	},
	vkDestroyBufferView = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkCreateImage = {
		self = {owner = 1, 'self.real'}, ret = 'pImage',
	},
	vkDestroyImage = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkGetImageSubresourceLayout = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'pLayout',
	},
	vkCreateImageView = {
		self = {owner = 1, 'self.real'}, ret = 'pView',
	},
	vkDestroyImageView = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkCreateShaderModule = {
		self = {owner = 1, 'self.real'}, ret = 'pShaderModule',
	},
	vkDestroyShaderModule = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkCreatePipelineCache = {
		self = {owner = 1, 'self.real'}, ret = 'pPipelineCache',
	},
	vkDestroyPipelineCache = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkGetPipelineCacheData = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'pData',
	},
	vkMergePipelineCaches = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkCreateGraphicsPipelines = {
		self = {owner = 1, 'self.real'}, ret = 'pPipelines',
	},
	vkCreateComputePipelines = {
		self = {owner = 1, 'self.real'}, ret = 'pPipelines',
	},
	vkDestroyPipeline = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkCreatePipelineLayout = {
		self = {owner = 1, 'self.real'}, ret = 'pPipelineLayout',
	},
	vkDestroyPipelineLayout = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkCreateSampler = {
		self = {owner = 1, 'self.real'}, ret = 'pSampler',
	},
	vkDestroySampler = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkCreateDescriptorSetLayout = {
		self = {owner = 1, 'self.real'}, ret = 'pSetLayout',
	},
	vkDestroyDescriptorSetLayout = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkCreateDescriptorPool = {
		self = {owner = 1, 'self.real'}, ret = 'pDescriptorPool',
	},
	vkDestroyDescriptorPool = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkResetDescriptorPool = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkAllocateDescriptorSets = {
		self = {owner = 1, 'self.real'}, ret = 'pDescriptorSets',
	}, -- (device, pAllocateInfo, pDescriptorSets)
	vkFreeDescriptorSets = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkUpdateDescriptorSets = {
		self = {owner = 1, 'self.real'},
	},
	vkCreateFramebuffer = {
		self = {owner = 1, 'self.real'}, ret = 'pFramebuffer',
	},
	vkDestroyFramebuffer = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkCreateRenderPass = {
		self = {owner = 1, 'self.real'}, ret = 'pRenderPass',
	},
	vkDestroyRenderPass = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkGetRenderAreaGranularity = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'pGranularity',
	},
	vkCreateCommandPool = {
		self = {owner = 1, 'self.real'}, ret = 'pCommandPool',
	},
	vkDestroyCommandPool = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkResetCommandPool = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkAllocateCommandBuffers = {
		self = {owner = 1, 'self.real'}, ret = 'pCommandBuffers',
	}, -- (device, pAllocateInfo, pCommandBuffers)
	vkFreeCommandBuffers = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkBeginCommandBuffer = {
		self = {owner = 1, 'self.real'},
	},
	vkEndCommandBuffer = {
		self = {owner = 1, 'self.real'},
	},
	vkResetCommandBuffer = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdBindPipeline = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdSetViewport = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdSetScissor = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdSetLineWidth = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdSetDepthBias = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdSetBlendConstants = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdSetDepthBounds = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdSetStencilCompareMask = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdSetStencilWriteMask = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdSetStencilReference = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdBindDescriptorSets = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdBindIndexBuffer = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdBindVertexBuffers = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdDraw = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdDrawIndexed = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdDrawIndirect = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdDrawIndexedIndirect = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdDispatch = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdDispatchIndirect = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdCopyBuffer = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdCopyImage = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdBlitImage = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdCopyBufferToImage = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdCopyImageToBuffer = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdUpdateBuffer = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdFillBuffer = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdClearColorImage = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdClearDepthStencilImage = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdClearAttachments = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdResolveImage = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdSetEvent = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdResetEvent = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdWaitEvents = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdPipelineBarrier = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdBeginQuery = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdEndQuery = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdResetQueryPool = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdWriteTimestamp = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdCopyQueryPoolResults = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdPushConstants = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdBeginRenderPass = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdNextSubpass = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdEndRenderPass = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdExecuteCommands = {
		self = {owner = 1, 'self.real'},
	},
	vkCreateAndroidSurfaceKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pSurface',
	},
	vkGetPhysicalDeviceDisplayPropertiesKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pProperties',
	},
	vkGetPhysicalDeviceDisplayPlanePropertiesKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pProperties',
	},
	vkGetDisplayPlaneSupportedDisplaysKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pDisplays',
	},
	vkGetDisplayModePropertiesKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'pProperties',
	},
	vkCreateDisplayModeKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'pMode',
	},
	vkGetDisplayPlaneCapabilitiesKHR = {
		self = {owner = 2, 'self.parent.parent.real', 'self.real'}, ret = 'pCapabilities',
	},
	vkCreateDisplayPlaneSurfaceKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pSurface',
	},
	vkCreateSharedSwapchainsKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pSwapchains',
	},
	vkCreateMirSurfaceKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pSurface',
	},
	vkGetPhysicalDeviceMirPresentationSupportKHR = {
		self = {owner = 1, 'self.real'},
	},
	vkDestroySurfaceKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkGetPhysicalDeviceSurfaceSupportKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pSupported',
	},
	vkGetPhysicalDeviceSurfaceCapabilitiesKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pSurfaceCapabilities',
	},
	vkGetPhysicalDeviceSurfaceFormatsKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pSurfaceFormats',
	},
	vkGetPhysicalDeviceSurfacePresentModesKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pPresentModes',
	},
	vkCreateSwapchainKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pSwapchain',
	},
	vkDestroySwapchainKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkGetSwapchainImagesKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'pSwapchainImages',
	},
	vkAcquireNextImageKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'pImageIndex',
	},
	vkQueuePresentKHR = {
		self = {owner = 1, 'self.real'},
	},
	vkCreateViSurfaceNN = {
		self = {owner = 1, 'self.real'}, ret = 'pSurface',
	},
	vkCreateWaylandSurfaceKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pSurface',
	},
	vkGetPhysicalDeviceWaylandPresentationSupportKHR = {
		self = {owner = 1, 'self.real'},
	},
	vkCreateWin32SurfaceKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pSurface',
	},
	vkGetPhysicalDeviceWin32PresentationSupportKHR = {
		self = {owner = 1, 'self.real'},
	},
	vkCreateXlibSurfaceKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pSurface',
	},
	vkGetPhysicalDeviceXlibPresentationSupportKHR = {
		self = {owner = 1, 'self.real'},
	},
	vkCreateXcbSurfaceKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pSurface',
	},
	vkGetPhysicalDeviceXcbPresentationSupportKHR = {
		self = {owner = 1, 'self.real'},
	},
	vkCreateDebugReportCallbackEXT = {
		self = {owner = 1, 'self.real'}, ret = 'pCallback',
	},
	vkDestroyDebugReportCallbackEXT = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkDebugReportMessageEXT = {
		self = {owner = 1, 'self.real'},
	},
	vkDebugMarkerSetObjectNameEXT = {
		self = {owner = 1, 'self.real'},
	},
	vkDebugMarkerSetObjectTagEXT = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdDebugMarkerBeginEXT = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdDebugMarkerEndEXT = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdDebugMarkerInsertEXT = {
		self = {owner = 1, 'self.real'},
	},
	vkGetPhysicalDeviceExternalImageFormatPropertiesNV = {
		self = {owner = 1, 'self.real'}, ret = 'pExternalImageFormatProperties',
	},
	vkGetMemoryWin32HandleNV = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'pHandle',
	},
	vkCmdDrawIndirectCountAMD = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdDrawIndexedIndirectCountAMD = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdProcessCommandsNVX = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdReserveSpaceForCommandsNVX = {
		self = {owner = 1, 'self.real'},
	},
	vkCreateIndirectCommandsLayoutNVX = {
		self = {owner = 1, 'self.real'}, ret = 'pIndirectCommandsLayout',
	},
	vkDestroyIndirectCommandsLayoutNVX = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkCreateObjectTableNVX = {
		self = {owner = 1, 'self.real'}, ret = 'pObjectTable',
	},
	vkDestroyObjectTableNVX = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkRegisterObjectsNVX = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkUnregisterObjectsNVX = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkGetPhysicalDeviceGeneratedCommandsPropertiesNVX = {
		self = {owner = 1, 'self.real'}, ret = {'pFeatures', 'pLimits'},
	},
	vkGetPhysicalDeviceFeatures2 = {
		self = {owner = 1, 'self.real'}, ret = 'pFeatures',
	},
	vkGetPhysicalDeviceProperties2 = {
		self = {owner = 1, 'self.real'}, ret = 'pProperties',
	},
	vkGetPhysicalDeviceFormatProperties2 = {
		self = {owner = 1, 'self.real'}, ret = 'pFormatProperties',
	},
	vkGetPhysicalDeviceImageFormatProperties2 = {
		self = {owner = 1, 'self.real'}, ret = 'pImageFormatProperties',
	},
	vkGetPhysicalDeviceQueueFamilyProperties2 = {
		self = {owner = 1, 'self.real'}, ret = 'pQueueFamilyProperties',
	},
	vkGetPhysicalDeviceMemoryProperties2 = {
		self = {owner = 1, 'self.real'}, ret = 'pMemoryProperties',
	},
	vkGetPhysicalDeviceSparseImageFormatProperties2 = {
		self = {owner = 1, 'self.real'}, ret = 'pProperties',
	},
	vkCmdPushDescriptorSetKHR = {
		self = {owner = 1, 'self.real'},
	},
	vkTrimCommandPool = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkGetPhysicalDeviceExternalBufferProperties = {
		self = {owner = 1, 'self.real'}, ret = 'pExternalBufferProperties',
	},
	vkGetMemoryWin32HandleKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pHandle',
	},
	vkGetMemoryWin32HandlePropertiesKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pMemoryWin32HandleProperties',
	},
	vkGetMemoryFdKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pFd',
	},
	vkGetMemoryFdPropertiesKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pMemoryFdProperties',
	},
	vkGetPhysicalDeviceExternalSemaphoreProperties = {
		self = {owner = 1, 'self.real'}, ret = 'pExternalSemaphoreProperties',
	},
	vkGetSemaphoreWin32HandleKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pHandle',
	},
	vkImportSemaphoreWin32HandleKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pImportSemaphoreWin32HandleInfo)
	vkGetSemaphoreFdKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pFd',
	},
	vkImportSemaphoreFdKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pImportSemaphoreFdInfo)
	vkGetPhysicalDeviceExternalFenceProperties = {
		self = {owner = 1, 'self.real'}, ret = 'pExternalFenceProperties',
	},
	vkGetFenceWin32HandleKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pHandle',
	},
	vkImportFenceWin32HandleKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pImportFenceWin32HandleInfo)
	vkGetFenceFdKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pFd',
	},
	vkImportFenceFdKHR = {
		self = {owner = 1, 'self.real'},
	},
	vkReleaseDisplayEXT = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkAcquireXlibDisplayEXT = {
		self = {owner = 3, 'self.parent.real', nil, 'self.real'},
	}, -- (physicalDevice, dpy, display)
	vkGetRandROutputDisplayEXT = {
		self = {owner = 1, 'self.real'}, ret = 'pDisplay',
	},
	vkDisplayPowerControlEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (TODO)
	vkRegisterDeviceEventEXT = {
		self = {owner = 1, 'self.real'}, ret = 'pFence',
	},
	vkRegisterDisplayEventEXT = {
		self = {owner = 1, 'self.real'}, ret = 'pFence',
	}, -- (TODO)
	vkGetSwapchainCounterEXT = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'pCounterValue',
	},
	vkGetPhysicalDeviceSurfaceCapabilities2EXT = {
		self = {owner = 1, 'self.real'}, ret = 'pSurfaceCapabilities',
	},
	vkEnumeratePhysicalDeviceGroups = {
		self = {owner = 1, 'self.real'}, ret = 'pPhysicalDeviceGroupProperties',
	},
	vkGetDeviceGroupPeerMemoryFeatures = {
		self = {owner = 1, 'self.real'}, ret = 'pPeerMemoryFeatures',
	},
	vkBindBufferMemory2 = {
		self = {owner = 1, 'self.real'},
	},
	vkBindImageMemory2 = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdSetDeviceMask = {
		self = {owner = 1, 'self.real'},
	},
	vkGetDeviceGroupPresentCapabilitiesKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pDeviceGroupPresentCapabilities',
	},
	vkGetDeviceGroupSurfacePresentModesKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pModes',
	},
	vkAcquireNextImage2KHR = {
		self = {owner = 1, 'self.real'}, ret = 'pImageIndex',
	},
	vkCmdDispatchBase = {
		self = {owner = 1, 'self.real'},
	},
	vkGetPhysicalDevicePresentRectanglesKHR = {
		self = {owner = 1, 'self.real'}, ret = 'pRects',
	},
	vkCreateDescriptorUpdateTemplate = {
		self = {owner = 1, 'self.real'}, ret = 'pDescriptorUpdateTemplate',
	},
	vkDestroyDescriptorUpdateTemplate = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkUpdateDescriptorSetWithTemplate = {
		self = {owner = 2, 'self.parent.parent.real', 'self.real'},
	},
	vkCmdPushDescriptorSetWithTemplateKHR = {
		self = {owner = 1, 'self.real'},
	},
	vkSetHdrMetadataEXT = {
		self = {owner = 1, 'self.real'},
	},
	vkGetSwapchainStatusKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkGetRefreshCycleDurationGOOGLE = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'pDisplayTimingProperties',
	},
	vkGetPastPresentationTimingGOOGLE = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'pPresentationTimings',
	},
	vkCreateIOSSurfaceMVK = {
		self = {owner = 1, 'self.real'}, ret = 'pSurface',
	},
	vkCreateMacOSSurfaceMVK = {
		self = {owner = 1, 'self.real'}, ret = 'pSurface',
	},
	vkCmdSetViewportWScalingNV = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdSetDiscardRectangleEXT = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdSetSampleLocationsEXT = {
		self = {owner = 1, 'self.real'},
	},
	vkGetPhysicalDeviceMultisamplePropertiesEXT = {
		self = {owner = 1, 'self.real'}, ret = 'pMultisampleProperties',
	},
	vkGetPhysicalDeviceSurfaceCapabilities2KHR = {
		self = {owner = 1, 'self.real'}, ret = 'pSurfaceCapabilities',
	},
	vkGetPhysicalDeviceSurfaceFormats2KHR = {
		self = {owner = 1, 'self.real'}, ret = 'pSurfaceFormats',
	},
	vkGetBufferMemoryRequirements2 = {
		self = {owner = 1, 'self.real'}, ret = 'pMemoryRequirements',
	},
	vkGetImageMemoryRequirements2 = {
		self = {owner = 1, 'self.real'}, ret = 'pMemoryRequirements',
	},
	vkGetImageSparseMemoryRequirements2 = {
		self = {owner = 1, 'self.real'}, ret = 'pSparseMemoryRequirements',
	},
	vkCreateSamplerYcbcrConversion = {
		self = {owner = 1, 'self.real'}, ret = 'pYcbcrConversion',
	},
	vkDestroySamplerYcbcrConversion = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkGetDeviceQueue2 = {
		self = {owner = 1, 'self.real'}, ret = 'pQueue',
	},
	vkCreateValidationCacheEXT = {
		self = {owner = 1, 'self.real'}, ret = 'pValidationCache',
	},
	vkDestroyValidationCacheEXT = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkGetValidationCacheDataEXT = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'pData',
	},
	vkMergeValidationCachesEXT = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkGetDescriptorSetLayoutSupport = {
		self = {owner = 1, 'self.real'}, ret = 'pSupport',
	},
	vkGetSwapchainGrallocUsageANDROID = {
		self = {owner = 1, 'self.real'}, ret = 'grallocUsage',
	},
	vkAcquireImageANDROID = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkQueueSignalReleaseImageANDROID = {
		self = {owner = 1, 'self.real'}, ret = 'pNativeFenceFd',
	},
	vkGetShaderInfoAMD = {
		self = {owner = 2, 'self.parent.real', 'self.real'}, ret = 'pInfo',
	},
	vkSetDebugUtilsObjectNameEXT = {
		self = {owner = 1, 'self.real'},
	},
	vkSetDebugUtilsObjectTagEXT = {
		self = {owner = 1, 'self.real'},
	},
	vkQueueBeginDebugUtilsLabelEXT = {
		self = {owner = 1, 'self.real'},
	},
	vkQueueEndDebugUtilsLabelEXT = {
		self = {owner = 1, 'self.real'},
	},
	vkQueueInsertDebugUtilsLabelEXT = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdBeginDebugUtilsLabelEXT = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdEndDebugUtilsLabelEXT = {
		self = {owner = 1, 'self.real'},
	},
	vkCmdInsertDebugUtilsLabelEXT = {
		self = {owner = 1, 'self.real'},
	},
	vkCreateDebugUtilsMessengerEXT = {
		self = {owner = 1, 'self.real'}, ret = 'pMessenger',
	},
	vkDestroyDebugUtilsMessengerEXT = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	},
	vkSubmitDebugUtilsMessageEXT = {
		self = {owner = 1, 'self.real'},
	},
	vkGetMemoryHostPointerPropertiesEXT = {
		self = {owner = 1, 'self.real'}, ret = 'pMemoryHostPointerProperties',
	},
	vkCmdWriteBufferMarkerAMD = {
		self = {owner = 1, 'self.real'},
	},
	vkGetAndroidHardwareBufferPropertiesANDROID = {
		self = {owner = 1, 'self.real'}, ret = 'pProperties',
	},
	vkGetMemoryAndroidHardwareBufferANDROID = {
		self = {owner = 1, 'self.real'}, ret = 'pBuffer',
	},
}

-- The "len" attribute of <member> and <param> tags are, generally speaking,
-- a big pain. They are something like a bit of C++ code, but for math its
-- close enough to Lua that we use metatables to read in the expression.
-- `elem` is the __newindex or __call field to get a length equation for.
-- `partype` is the type that contains `elem`.
-- `lenvar` is an expression that represents the length of the field.
-- `parent` is the the __newindex or __call sequence from which names may come.
-- Returns the variable reference and value to assign the length.
function human.length(elem, partype, lenvar, parent)
	local meta = {}
	local function new(base)
		local names = {}
		for _,e in ipairs(base) do if e.name then names[e.name] = e end end
		return setmetatable({_base=names}, meta)
	end
	local function math(op, rop)
		return function(a, b)
			local out = {}
			if getmetatable(a) == meta then out._setvar, a = a._setvar, a._setto end
			if getmetatable(b) == meta then out._setvar, b = b._setvar, b._setto end
			out._setto = ('(%s)%s(%s)'):format(a, rop, b)
			return setmetatable(out, meta)
		end
	end
	meta.__add, meta.__sub = math('+', '-'), math('-', '+')
	meta.__mul, meta.__div = math('*', '/'), math('/', '*')
	function meta:__index(k)
		if k:match '^_' then return
		elseif self._base[k] then
			local out = self._base[k].type.__newindex and new(self._base[k].type.__newindex) or {}
			out._setto = lenvar
			out._setvar = (self._setvar and self._setvar..'.' or '')..k
			return setmetatable(out, meta)
		elseif k:match 'VK_[%u_]+' then
			return setmetatable({_setto=k}, meta)
		else
			human.herror('Attempt to get field '..k..' of '..(self._setvar or '(env)'))
		end
	end
	local val = assert(load('return ('..elem._len:gsub('::', '.')..')',
		nil, 't', new(parent)))()
	if type(val) == 'table' then
		if elem.canbenil then
			local k = partype.__raw.C..'_'..elem.name
			human.hassert(optionallens[k] ~= nil, 'Unhandled op/len: '..k..' = nil!')
			if not optionallens[k] then return end
		end
		return val._setvar, val._setto
	end
end

-- Human-certified nearly correct parent links
local parents = {
	VkInstance = false,
	VkDisplayKHR = 'PhysicalDevice',
	VkDisplayModeKHR = 'DisplayKHR',
	VkSurfaceKHR = true, -- VkInstance
	VkPhysicalDevice = true, -- VkInstance
	VkDebugReportCallbackEXT = true, -- VkInstance
	VkDebugUtilsMessengerEXT = true, -- VkInstance
	VkSwapchainKHR = 'Device',
	VkDevice = true, -- VkPhysicalDevice
	VkCommandPool = true, -- VkDevice
	VkDescriptorPool = true, -- VkDevice
	VkSemaphore = true, -- VkDevice
	VkImageView = true, -- VkDevice
	VkQueryPool = true, -- VkDevice
	VkPipeline = true, -- VkDevice
	VkRenderPass = true, -- VkDevice
	VkSampler = true, -- VkDevice
	VkQueue = true, -- VkDevice
	VkDescriptorSetLayout = true, -- VkDevice
	VkSamplerYcbcrConversion = true, -- VkDevice
	VkDeviceMemory = true, -- VkDevice
	VkBuffer = true, -- VkDevice
	VkFence = true, -- VkDevice
	VkImage = true, -- VkDevice
	VkEvent = true, -- VkDevice
	VkShaderModule = true, -- VkDevice
	VkFramebuffer = true, -- VkDevice
	VkPipelineLayout = true, -- VkDevice
	VkPipelineCache = true, -- VkDevice
	VkBufferView = true, -- VkDevice
	VkValidationCacheEXT = true, -- VkDevice
	VkObjectTableNVX = true, -- VkDevice
	VkIndirectCommandsLayoutNVX = true, -- VkDevice
	VkDescriptorUpdateTemplate = true, -- VkDevice
	VkDescriptorSet = true, -- VkDescriptorPool
	VkCommandBuffer = true, -- VkCommandPool
}

-- Every non-dispatchable handle (and all but one dispatchable one) has a "parent"
-- that creates them, and they often use their parent in commands. The XML has
-- a "parent" entry a lot of the time, and its often correct, but not always...
-- `par` is the parent entry in the XML, and `name` is the name of this handle.
-- Returns the name (without the Vk) of the parent of this handle, or false-y
function human.parent(par, name)
	if parents[name] == false or type(parents[name]) == 'string' then
		return parents[name]
	elseif par then
		human.hassert(parents[name], '\t'..name..' = true, -- '..par)
		return par:gsub('^Vk', '')
	else human.herror("Missing info on parent for "..name) end
end

-- When there is no info on a particular command, we try and guess its properties.
-- These functions here do the guessing. They are designed to handle about 90%.
local function ishandle(t)	-- Guess whether the type is a handle or not.
	return not t.__index and not t.__newindex and not t.__enum and t.__raw and t.__raw.C:match '^Vk'
end
local guessed = {}
local function guess(entries, name)
	if guessed[name] then return else guessed[name] = true end
	local out = "self = false"
	if entries[2] and ishandle(entries[2].type) and not name:find '^vkCmd' then
		out = "self = {owner = 2, 'self.parent.real', 'self.real'}"
	elseif entries[1] and ishandle(entries[1].type) then
		out = "self = {owner = 1, 'self.real'}"
	end

	-- There isn't often more than one.
	if entries[#entries]._len or entries[#entries]._extraptr then
		out = out..', ret = 1'
	end

	local names = {}
	for _,e in ipairs(entries) do names[#names+1] = e.name end
	human.herror('\t'..name..' = {\n\t\t'..out..',\n\t}, -- ('
		..table.concat(names,', ')..')')
end

-- Commands in Vulkan are not associated with any particular handle, but most
-- only make sense within the context of one, so we make the association ourselves.
-- `args` is the raw argument list to work with
-- `name` is the name of the command in question.
function human.self(args, name)
	local c = cmdinfo[name]
	if not c then guess(args, name) elseif c.self then
		return args[c.self.owner].type, table.unpack(c.self)
	end
end

-- Commands in Vulkan often return their data through a pointer, which is passed
-- as an argument. This matches up with the general scheme for vV, but similarly
-- to the 'self' arguments there's no way without a Human's help to find them.
-- Returns the number of return values (**in Lua's version**) in the args.
function human.rets(args, name)
	local c = cmdinfo[name]
	if not c then guess(args, name) elseif c.ret then
		if type(c.ret) == 'table' then return table.unpack(c.ret)
		else return c.ret end
	end
end

return human
