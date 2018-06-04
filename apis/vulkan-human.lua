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
		self = false,
	}, -- (pCreateInfo, pAllocator, pInstance, return)
	vkDestroyInstance = {
		self = {owner = 1, 'self.real'},
	}, -- (instance, pAllocator)
	vkEnumeratePhysicalDevices = {
		self = {owner = 1, 'self.real'},
	}, -- (instance, pPhysicalDeviceCount, pPhysicalDevices, return)
	vkGetDeviceProcAddr = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pName, return)
	vkGetInstanceProcAddr = {
		self = {owner = 1, 'self.real'},
	}, -- (instance, pName, return)
	vkGetPhysicalDeviceProperties = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pProperties)
	vkGetPhysicalDeviceQueueFamilyProperties = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pQueueFamilyPropertyCount, pQueueFamilyProperties)
	vkGetPhysicalDeviceMemoryProperties = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pMemoryProperties)
	vkGetPhysicalDeviceFeatures = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pFeatures)
	vkGetPhysicalDeviceFormatProperties = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, format, pFormatProperties)
	vkGetPhysicalDeviceImageFormatProperties = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, format, type, tiling, usage, flags, pImageFormatProperties, return)
	vkCreateDevice = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pCreateInfo, pAllocator, pDevice, return)
	vkDestroyDevice = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pAllocator)
	vkEnumerateInstanceVersion = {
		self = false,
	}, -- (pApiVersion, return)
	vkEnumerateInstanceLayerProperties = {
		self = false,
	}, -- (pPropertyCount, pProperties, return)
	vkEnumerateInstanceExtensionProperties = {
		self = false,
	}, -- (pLayerName, pPropertyCount, pProperties, return)
	vkEnumerateDeviceLayerProperties = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pPropertyCount, pProperties, return)
	vkEnumerateDeviceExtensionProperties = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pLayerName, pPropertyCount, pProperties, return)
	vkGetDeviceQueue = {
		self = {owner = 1, 'self.real'},
	}, -- (device, queueFamilyIndex, queueIndex, pQueue)
	vkQueueSubmit = {
		self = {owner = 1, 'self.real'},
	}, -- (queue, submitCount, pSubmits, fence, return)
	vkQueueWaitIdle = {
		self = {owner = 1, 'self.real'},
	}, -- (queue, return)
	vkDeviceWaitIdle = {
		self = {owner = 1, 'self.real'},
	}, -- (device, return)
	vkAllocateMemory = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pAllocateInfo, pAllocator, pMemory, return)
	vkFreeMemory = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, memory, pAllocator)
	vkMapMemory = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, memory, offset, size, flags, ppData, return)
	vkUnmapMemory = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, memory)
	vkFlushMappedMemoryRanges = {
		self = {owner = 1, 'self.real'},
	}, -- (device, memoryRangeCount, pMemoryRanges, return)
	vkInvalidateMappedMemoryRanges = {
		self = {owner = 1, 'self.real'},
	}, -- (device, memoryRangeCount, pMemoryRanges, return)
	vkGetDeviceMemoryCommitment = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, memory, pCommittedMemoryInBytes)
	vkGetBufferMemoryRequirements = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, buffer, pMemoryRequirements)
	vkBindBufferMemory = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, buffer, memory, memoryOffset, return)
	vkGetImageMemoryRequirements = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, image, pMemoryRequirements)
	vkBindImageMemory = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, image, memory, memoryOffset, return)
	vkGetImageSparseMemoryRequirements = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, image, pSparseMemoryRequirementCount, pSparseMemoryRequirements)
	vkGetPhysicalDeviceSparseImageFormatProperties = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, format, type, samples, usage, tiling, pPropertyCount, pProperties)
	vkQueueBindSparse = {
		self = {owner = 1, 'self.real'},
	}, -- (queue, bindInfoCount, pBindInfo, fence, return)
	vkCreateFence = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pFence, return)
	vkDestroyFence = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, fence, pAllocator)
	vkResetFences = {
		self = {owner = 1, 'self.real'},
	}, -- (device, fenceCount, pFences, return)
	vkGetFenceStatus = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, fence, return)
	vkWaitForFences = {
		self = {owner = 1, 'self.real'},
	}, -- (device, fenceCount, pFences, waitAll, timeout, return)
	vkCreateSemaphore = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pSemaphore, return)
	vkDestroySemaphore = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, semaphore, pAllocator)
	vkCreateEvent = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pEvent, return)
	vkDestroyEvent = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, event, pAllocator)
	vkGetEventStatus = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, event, return)
	vkSetEvent = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, event, return)
	vkResetEvent = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, event, return)
	vkCreateQueryPool = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pQueryPool, return)
	vkDestroyQueryPool = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, queryPool, pAllocator)
	vkGetQueryPoolResults = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, queryPool, firstQuery, queryCount, dataSize, pData, stride, flags, return)
	vkCreateBuffer = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pBuffer, return)
	vkDestroyBuffer = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, buffer, pAllocator)
	vkCreateBufferView = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pView, return)
	vkDestroyBufferView = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, bufferView, pAllocator)
	vkCreateImage = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pImage, return)
	vkDestroyImage = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, image, pAllocator)
	vkGetImageSubresourceLayout = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, image, pSubresource, pLayout)
	vkCreateImageView = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pView, return)
	vkDestroyImageView = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, imageView, pAllocator)
	vkCreateShaderModule = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pShaderModule, return)
	vkDestroyShaderModule = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, shaderModule, pAllocator)
	vkCreatePipelineCache = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pPipelineCache, return)
	vkDestroyPipelineCache = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, pipelineCache, pAllocator)
	vkGetPipelineCacheData = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, pipelineCache, pDataSize, pData, return)
	vkMergePipelineCaches = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, dstCache, srcCacheCount, pSrcCaches, return)
	vkCreateGraphicsPipelines = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, pipelineCache, createInfoCount, pCreateInfos, pAllocator, pPipelines, return)
	vkCreateComputePipelines = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, pipelineCache, createInfoCount, pCreateInfos, pAllocator, pPipelines, return)
	vkDestroyPipeline = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, pipeline, pAllocator)
	vkCreatePipelineLayout = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pPipelineLayout, return)
	vkDestroyPipelineLayout = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, pipelineLayout, pAllocator)
	vkCreateSampler = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pSampler, return)
	vkDestroySampler = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, sampler, pAllocator)
	vkCreateDescriptorSetLayout = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pSetLayout, return)
	vkDestroyDescriptorSetLayout = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, descriptorSetLayout, pAllocator)
	vkCreateDescriptorPool = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pDescriptorPool, return)
	vkDestroyDescriptorPool = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, descriptorPool, pAllocator)
	vkResetDescriptorPool = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, descriptorPool, flags, return)
	vkAllocateDescriptorSets = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pAllocateInfo, pDescriptorSets, return)
	vkFreeDescriptorSets = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, descriptorPool, descriptorSetCount, pDescriptorSets, return)
	vkUpdateDescriptorSets = {
		self = {owner = 1, 'self.real'},
	}, -- (device, descriptorWriteCount, pDescriptorWrites, descriptorCopyCount, pDescriptorCopies)
	vkCreateFramebuffer = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pFramebuffer, return)
	vkDestroyFramebuffer = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, framebuffer, pAllocator)
	vkCreateRenderPass = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pRenderPass, return)
	vkDestroyRenderPass = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, renderPass, pAllocator)
	vkGetRenderAreaGranularity = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, renderPass, pGranularity)
	vkCreateCommandPool = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pCommandPool, return)
	vkDestroyCommandPool = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, commandPool, pAllocator)
	vkResetCommandPool = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, commandPool, flags, return)
	vkAllocateCommandBuffers = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pAllocateInfo, pCommandBuffers, return)
	vkFreeCommandBuffers = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, commandPool, commandBufferCount, pCommandBuffers)
	vkBeginCommandBuffer = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, pBeginInfo, return)
	vkEndCommandBuffer = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, return)
	vkResetCommandBuffer = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, flags, return)
	vkCmdBindPipeline = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, pipelineBindPoint, pipeline)
	vkCmdSetViewport = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, firstViewport, viewportCount, pViewports)
	vkCmdSetScissor = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, firstScissor, scissorCount, pScissors)
	vkCmdSetLineWidth = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, lineWidth)
	vkCmdSetDepthBias = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, depthBiasConstantFactor, depthBiasClamp, depthBiasSlopeFactor)
	vkCmdSetBlendConstants = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, blendConstants)
	vkCmdSetDepthBounds = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, minDepthBounds, maxDepthBounds)
	vkCmdSetStencilCompareMask = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, faceMask, compareMask)
	vkCmdSetStencilWriteMask = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, faceMask, writeMask)
	vkCmdSetStencilReference = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, faceMask, reference)
	vkCmdBindDescriptorSets = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, pipelineBindPoint, layout, firstSet, descriptorSetCount, pDescriptorSets, dynamicOffsetCount, pDynamicOffsets)
	vkCmdBindIndexBuffer = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, buffer, offset, indexType)
	vkCmdBindVertexBuffers = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, firstBinding, bindingCount, pBuffers, pOffsets)
	vkCmdDraw = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, vertexCount, instanceCount, firstVertex, firstInstance)
	vkCmdDrawIndexed = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, indexCount, instanceCount, firstIndex, vertexOffset, firstInstance)
	vkCmdDrawIndirect = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, buffer, offset, drawCount, stride)
	vkCmdDrawIndexedIndirect = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, buffer, offset, drawCount, stride)
	vkCmdDispatch = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, groupCountX, groupCountY, groupCountZ)
	vkCmdDispatchIndirect = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, buffer, offset)
	vkCmdCopyBuffer = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, srcBuffer, dstBuffer, regionCount, pRegions)
	vkCmdCopyImage = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, srcImage, srcImageLayout, dstImage, dstImageLayout, regionCount, pRegions)
	vkCmdBlitImage = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, srcImage, srcImageLayout, dstImage, dstImageLayout, regionCount, pRegions, filter)
	vkCmdCopyBufferToImage = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, srcBuffer, dstImage, dstImageLayout, regionCount, pRegions)
	vkCmdCopyImageToBuffer = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, srcImage, srcImageLayout, dstBuffer, regionCount, pRegions)
	vkCmdUpdateBuffer = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, dstBuffer, dstOffset, dataSize, pData)
	vkCmdFillBuffer = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, dstBuffer, dstOffset, size, data)
	vkCmdClearColorImage = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, image, imageLayout, pColor, rangeCount, pRanges)
	vkCmdClearDepthStencilImage = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, image, imageLayout, pDepthStencil, rangeCount, pRanges)
	vkCmdClearAttachments = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, attachmentCount, pAttachments, rectCount, pRects)
	vkCmdResolveImage = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, srcImage, srcImageLayout, dstImage, dstImageLayout, regionCount, pRegions)
	vkCmdSetEvent = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, event, stageMask)
	vkCmdResetEvent = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, event, stageMask)
	vkCmdWaitEvents = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, eventCount, pEvents, srcStageMask, dstStageMask, memoryBarrierCount, pMemoryBarriers, bufferMemoryBarrierCount, pBufferMemoryBarriers, imageMemoryBarrierCount, pImageMemoryBarriers)
	vkCmdPipelineBarrier = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, srcStageMask, dstStageMask, dependencyFlags, memoryBarrierCount, pMemoryBarriers, bufferMemoryBarrierCount, pBufferMemoryBarriers, imageMemoryBarrierCount, pImageMemoryBarriers)
	vkCmdBeginQuery = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, queryPool, query, flags)
	vkCmdEndQuery = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, queryPool, query)
	vkCmdResetQueryPool = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, queryPool, firstQuery, queryCount)
	vkCmdWriteTimestamp = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, pipelineStage, queryPool, query)
	vkCmdCopyQueryPoolResults = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, queryPool, firstQuery, queryCount, dstBuffer, dstOffset, stride, flags)
	vkCmdPushConstants = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, layout, stageFlags, offset, size, pValues)
	vkCmdBeginRenderPass = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, pRenderPassBegin, contents)
	vkCmdNextSubpass = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, contents)
	vkCmdEndRenderPass = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer)
	vkCmdExecuteCommands = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, commandBufferCount, pCommandBuffers)
	vkCreateAndroidSurfaceKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkGetPhysicalDeviceDisplayPropertiesKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pPropertyCount, pProperties, return)
	vkGetPhysicalDeviceDisplayPlanePropertiesKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pPropertyCount, pProperties, return)
	vkGetDisplayPlaneSupportedDisplaysKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, planeIndex, pDisplayCount, pDisplays, return)
	vkGetDisplayModePropertiesKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (physicalDevice, display, pPropertyCount, pProperties, return)
	vkCreateDisplayModeKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (physicalDevice, display, pCreateInfo, pAllocator, pMode, return)
	vkGetDisplayPlaneCapabilitiesKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (physicalDevice, mode, planeIndex, pCapabilities, return)
	vkCreateDisplayPlaneSurfaceKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkCreateSharedSwapchainsKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, swapchainCount, pCreateInfos, pAllocator, pSwapchains, return)
	vkCreateMirSurfaceKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkGetPhysicalDeviceMirPresentationSupportKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, queueFamilyIndex, connection, return)
	vkDestroySurfaceKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (instance, surface, pAllocator)
	vkGetPhysicalDeviceSurfaceSupportKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, queueFamilyIndex, surface, pSupported, return)
	vkGetPhysicalDeviceSurfaceCapabilitiesKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (physicalDevice, surface, pSurfaceCapabilities, return)
	vkGetPhysicalDeviceSurfaceFormatsKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (physicalDevice, surface, pSurfaceFormatCount, pSurfaceFormats, return)
	vkGetPhysicalDeviceSurfacePresentModesKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (physicalDevice, surface, pPresentModeCount, pPresentModes, return)
	vkCreateSwapchainKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pSwapchain, return)
	vkDestroySwapchainKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, swapchain, pAllocator)
	vkGetSwapchainImagesKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, swapchain, pSwapchainImageCount, pSwapchainImages, return)
	vkAcquireNextImageKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, swapchain, timeout, semaphore, fence, pImageIndex, return)
	vkQueuePresentKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (queue, pPresentInfo, return)
	vkCreateViSurfaceNN = {
		self = {owner = 1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkCreateWaylandSurfaceKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkGetPhysicalDeviceWaylandPresentationSupportKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, queueFamilyIndex, display, return)
	vkCreateWin32SurfaceKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkGetPhysicalDeviceWin32PresentationSupportKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, queueFamilyIndex, return)
	vkCreateXlibSurfaceKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkGetPhysicalDeviceXlibPresentationSupportKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, queueFamilyIndex, dpy, visualID, return)
	vkCreateXcbSurfaceKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkGetPhysicalDeviceXcbPresentationSupportKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, queueFamilyIndex, connection, visual_id, return)
	vkCreateDebugReportCallbackEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pCallback, return)
	vkDestroyDebugReportCallbackEXT = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (instance, callback, pAllocator)
	vkDebugReportMessageEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (instance, flags, objectType, object, location, messageCode, pLayerPrefix, pMessage)
	vkDebugMarkerSetObjectNameEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pNameInfo, return)
	vkDebugMarkerSetObjectTagEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pTagInfo, return)
	vkCmdDebugMarkerBeginEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, pMarkerInfo)
	vkCmdDebugMarkerEndEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer)
	vkCmdDebugMarkerInsertEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, pMarkerInfo)
	vkGetPhysicalDeviceExternalImageFormatPropertiesNV = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, format, type, tiling, usage, flags, externalHandleType, pExternalImageFormatProperties, return)
	vkGetMemoryWin32HandleNV = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, memory, handleType, pHandle, return)
	vkCmdDrawIndirectCountAMD = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, buffer, offset, countBuffer, countBufferOffset, maxDrawCount, stride)
	vkCmdDrawIndexedIndirectCountAMD = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, buffer, offset, countBuffer, countBufferOffset, maxDrawCount, stride)
	vkCmdProcessCommandsNVX = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, pProcessCommandsInfo)
	vkCmdReserveSpaceForCommandsNVX = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, pReserveSpaceInfo)
	vkCreateIndirectCommandsLayoutNVX = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pIndirectCommandsLayout, return)
	vkDestroyIndirectCommandsLayoutNVX = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, indirectCommandsLayout, pAllocator)
	vkCreateObjectTableNVX = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pObjectTable, return)
	vkDestroyObjectTableNVX = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, objectTable, pAllocator)
	vkRegisterObjectsNVX = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, objectTable, objectCount, ppObjectTableEntries, pObjectIndices, return)
	vkUnregisterObjectsNVX = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, objectTable, objectCount, pObjectEntryTypes, pObjectIndices, return)
	vkGetPhysicalDeviceGeneratedCommandsPropertiesNVX = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pFeatures, pLimits)
	vkGetPhysicalDeviceFeatures2 = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pFeatures)
	vkGetPhysicalDeviceProperties2 = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pProperties)
	vkGetPhysicalDeviceFormatProperties2 = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, format, pFormatProperties)
	vkGetPhysicalDeviceImageFormatProperties2 = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pImageFormatInfo, pImageFormatProperties, return)
	vkGetPhysicalDeviceQueueFamilyProperties2 = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pQueueFamilyPropertyCount, pQueueFamilyProperties)
	vkGetPhysicalDeviceMemoryProperties2 = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pMemoryProperties)
	vkGetPhysicalDeviceSparseImageFormatProperties2 = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pFormatInfo, pPropertyCount, pProperties)
	vkCmdPushDescriptorSetKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, pipelineBindPoint, layout, set, descriptorWriteCount, pDescriptorWrites)
	vkTrimCommandPool = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, commandPool, flags)
	vkGetPhysicalDeviceExternalBufferProperties = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pExternalBufferInfo, pExternalBufferProperties)
	vkGetMemoryWin32HandleKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pGetWin32HandleInfo, pHandle, return)
	vkGetMemoryWin32HandlePropertiesKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, handleType, handle, pMemoryWin32HandleProperties, return)
	vkGetMemoryFdKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pGetFdInfo, pFd, return)
	vkGetMemoryFdPropertiesKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, handleType, fd, pMemoryFdProperties, return)
	vkGetPhysicalDeviceExternalSemaphoreProperties = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pExternalSemaphoreInfo, pExternalSemaphoreProperties)
	vkGetSemaphoreWin32HandleKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pGetWin32HandleInfo, pHandle, return)
	vkImportSemaphoreWin32HandleKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pImportSemaphoreWin32HandleInfo, return)
	vkGetSemaphoreFdKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pGetFdInfo, pFd, return)
	vkImportSemaphoreFdKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pImportSemaphoreFdInfo, return)
	vkGetPhysicalDeviceExternalFenceProperties = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pExternalFenceInfo, pExternalFenceProperties)
	vkGetFenceWin32HandleKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pGetWin32HandleInfo, pHandle, return)
	vkImportFenceWin32HandleKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pImportFenceWin32HandleInfo, return)
	vkGetFenceFdKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pGetFdInfo, pFd, return)
	vkImportFenceFdKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pImportFenceFdInfo, return)
	vkReleaseDisplayEXT = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (physicalDevice, display, return)
	vkAcquireXlibDisplayEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, dpy, display, return)
	vkGetRandROutputDisplayEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, dpy, rrOutput, pDisplay, return)
	vkDisplayPowerControlEXT = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, display, pDisplayPowerInfo, return)
	vkRegisterDeviceEventEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pDeviceEventInfo, pAllocator, pFence, return)
	vkRegisterDisplayEventEXT = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, display, pDisplayEventInfo, pAllocator, pFence, return)
	vkGetSwapchainCounterEXT = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, swapchain, counter, pCounterValue, return)
	vkGetPhysicalDeviceSurfaceCapabilities2EXT = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (physicalDevice, surface, pSurfaceCapabilities, return)
	vkEnumeratePhysicalDeviceGroups = {
		self = {owner = 1, 'self.real'},
	}, -- (instance, pPhysicalDeviceGroupCount, pPhysicalDeviceGroupProperties, return)
	vkGetDeviceGroupPeerMemoryFeatures = {
		self = {owner = 1, 'self.real'},
	}, -- (device, heapIndex, localDeviceIndex, remoteDeviceIndex, pPeerMemoryFeatures)
	vkBindBufferMemory2 = {
		self = {owner = 1, 'self.real'},
	}, -- (device, bindInfoCount, pBindInfos, return)
	vkBindImageMemory2 = {
		self = {owner = 1, 'self.real'},
	}, -- (device, bindInfoCount, pBindInfos, return)
	vkCmdSetDeviceMask = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, deviceMask)
	vkGetDeviceGroupPresentCapabilitiesKHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pDeviceGroupPresentCapabilities, return)
	vkGetDeviceGroupSurfacePresentModesKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, surface, pModes, return)
	vkAcquireNextImage2KHR = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pAcquireInfo, pImageIndex, return)
	vkCmdDispatchBase = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, baseGroupX, baseGroupY, baseGroupZ, groupCountX, groupCountY, groupCountZ)
	vkGetPhysicalDevicePresentRectanglesKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (physicalDevice, surface, pRectCount, pRects, return)
	vkCreateDescriptorUpdateTemplate = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pDescriptorUpdateTemplate, return)
	vkDestroyDescriptorUpdateTemplate = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, descriptorUpdateTemplate, pAllocator)
	vkUpdateDescriptorSetWithTemplate = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, descriptorSet, descriptorUpdateTemplate, pData)
	vkCmdPushDescriptorSetWithTemplateKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, descriptorUpdateTemplate, layout, set, pData)
	vkSetHdrMetadataEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (device, swapchainCount, pSwapchains, pMetadata)
	vkGetSwapchainStatusKHR = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, swapchain, return)
	vkGetRefreshCycleDurationGOOGLE = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, swapchain, pDisplayTimingProperties, return)
	vkGetPastPresentationTimingGOOGLE = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, swapchain, pPresentationTimingCount, pPresentationTimings, return)
	vkCreateIOSSurfaceMVK = {
		self = {owner = 1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkCreateMacOSSurfaceMVK = {
		self = {owner = 1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkCmdSetViewportWScalingNV = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, firstViewport, viewportCount, pViewportWScalings)
	vkCmdSetDiscardRectangleEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, firstDiscardRectangle, discardRectangleCount, pDiscardRectangles)
	vkCmdSetSampleLocationsEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, pSampleLocationsInfo)
	vkGetPhysicalDeviceMultisamplePropertiesEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, samples, pMultisampleProperties)
	vkGetPhysicalDeviceSurfaceCapabilities2KHR = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pSurfaceInfo, pSurfaceCapabilities, return)
	vkGetPhysicalDeviceSurfaceFormats2KHR = {
		self = {owner = 1, 'self.real'},
	}, -- (physicalDevice, pSurfaceInfo, pSurfaceFormatCount, pSurfaceFormats, return)
	vkGetBufferMemoryRequirements2 = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pInfo, pMemoryRequirements)
	vkGetImageMemoryRequirements2 = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pInfo, pMemoryRequirements)
	vkGetImageSparseMemoryRequirements2 = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pInfo, pSparseMemoryRequirementCount, pSparseMemoryRequirements)
	vkCreateSamplerYcbcrConversion = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pYcbcrConversion, return)
	vkDestroySamplerYcbcrConversion = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, ycbcrConversion, pAllocator)
	vkGetDeviceQueue2 = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pQueueInfo, pQueue)
	vkCreateValidationCacheEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pValidationCache, return)
	vkDestroyValidationCacheEXT = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, validationCache, pAllocator)
	vkGetValidationCacheDataEXT = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, validationCache, pDataSize, pData, return)
	vkMergeValidationCachesEXT = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, dstCache, srcCacheCount, pSrcCaches, return)
	vkGetDescriptorSetLayoutSupport = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pCreateInfo, pSupport)
	vkGetSwapchainGrallocUsageANDROID = {
		self = {owner = 1, 'self.real'},
	}, -- (device, format, imageUsage, grallocUsage, return)
	vkAcquireImageANDROID = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, image, nativeFenceFd, semaphore, fence, return)
	vkQueueSignalReleaseImageANDROID = {
		self = {owner = 1, 'self.real'},
	}, -- (queue, waitSemaphoreCount, pWaitSemaphores, image, pNativeFenceFd, return)
	vkGetShaderInfoAMD = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (device, pipeline, shaderStage, infoType, pInfoSize, pInfo, return)
	vkSetDebugUtilsObjectNameEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pNameInfo, return)
	vkSetDebugUtilsObjectTagEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pTagInfo, return)
	vkQueueBeginDebugUtilsLabelEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (queue, pLabelInfo)
	vkQueueEndDebugUtilsLabelEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (queue)
	vkQueueInsertDebugUtilsLabelEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (queue, pLabelInfo)
	vkCmdBeginDebugUtilsLabelEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, pLabelInfo)
	vkCmdEndDebugUtilsLabelEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer)
	vkCmdInsertDebugUtilsLabelEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, pLabelInfo)
	vkCreateDebugUtilsMessengerEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pMessenger, return)
	vkDestroyDebugUtilsMessengerEXT = {
		self = {owner = 2, 'self.parent.real', 'self.real'},
	}, -- (instance, messenger, pAllocator)
	vkSubmitDebugUtilsMessageEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (instance, messageSeverity, messageTypes, pCallbackData)
	vkGetMemoryHostPointerPropertiesEXT = {
		self = {owner = 1, 'self.real'},
	}, -- (device, handleType, pHostPointer, pMemoryHostPointerProperties, return)
	vkCmdWriteBufferMarkerAMD = {
		self = {owner = 1, 'self.real'},
	}, -- (commandBuffer, pipelineStage, dstBuffer, dstOffset, marker)
	vkGetAndroidHardwareBufferPropertiesANDROID = {
		self = {owner = 1, 'self.real'},
	}, -- (device, buffer, pProperties, return)
	vkGetMemoryAndroidHardwareBufferANDROID = {
		self = {owner = 1, 'self.real'},
	}, -- (device, pInfo, pBuffer, return)
}

-- The "len" attribute of <member> and <param> tags are, generally speaking,
-- a big pain. They are something like a bit of C++ code, but for math its
-- close enough to Lua that we use metatables to read in the expression.
-- `elem` is the __index or __call field to get a length equation for.
-- `partype` is the type that contains `elem`.
-- `forvar` is an expression that represents the length of the field.
-- `parent` is the the __index or __call sequence from which names may come.
-- Returns the variable reference and value to assign the length.
function human.length(elem, partype, lenvar, parent)
	local meta = {}
	local function new(base)
		local names = {}
		for _,e in ipairs(base) do names[e.name] = e end
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
			local out = self._base[k].type.__index and new(self._base[k].type.__index) or {}
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

-- Handles are connected by a parenting scheme, but it doesn't always work right...
human.parent = {
	VkInstance = false,	-- Parent is Vk
	VkDisplayKHR = 'PhysicalDevice',
	VkDisplayModeKHR = 'DisplayKHR',
}

-- When there is no info on a particular command, we try and guess its properties.
-- These functions here do the guessing. They are designed to handle about 90%.
local function ishandle(t)	-- Guess whether the type is a handle or not.
	return not t.__index and not t.__enum and t.__raw and t.__raw.C:match '^Vk'
end
local function guess(entries, name)
	local out = "self = false"
	if entries[2] and ishandle(entries[2].type) then
		out = "self = {owner = 2, 'self.parent.real', 'self.real'}"
	elseif entries[1] and ishandle(entries[1].type) then
		out = "self = {owner = 1, 'self.real'}"
	end
	local names = {}
	for _,e in ipairs(entries) do names[#names+1] = e.name end
	human.herror('\t'..name..' = {\n\t\t'..out..',\n\t}, -- ('
		..table.concat(names,', ')..')')
end

-- Commands in Vulkan are not associated with any particular handle, but most
-- only make sense within the context of one, so we make the association ourselves.
-- `entries` is the raw argument list to work with
-- `name` is the name of the command in question.
function human.self(args, raws, name)
	local c = cmdinfo[name]
	if not c then guess(args, name) elseif c.self then
		for i,s in ipairs(c.self) do raws[args[i].name].value = s end
		return args[c.self.owner].type
	end
end

return human
