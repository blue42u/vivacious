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
		self = {1, 'self.real'},
	}, -- (instance, pAllocator)
	vkEnumeratePhysicalDevices = {
		self = {1, 'self.real'},
	}, -- (instance, pPhysicalDeviceCount, pPhysicalDevices, return)
	vkGetDeviceProcAddr = {
		self = {1, 'self.real'},
	}, -- (device, pName, return)
	vkGetInstanceProcAddr = {
		self = {1, 'self.real'},
	}, -- (instance, pName, return)
	vkGetPhysicalDeviceProperties = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pProperties)
	vkGetPhysicalDeviceQueueFamilyProperties = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pQueueFamilyPropertyCount, pQueueFamilyProperties)
	vkGetPhysicalDeviceMemoryProperties = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pMemoryProperties)
	vkGetPhysicalDeviceFeatures = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pFeatures)
	vkGetPhysicalDeviceFormatProperties = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, format, pFormatProperties)
	vkGetPhysicalDeviceImageFormatProperties = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, format, type, tiling, usage, flags, pImageFormatProperties, return)
	vkCreateDevice = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pCreateInfo, pAllocator, pDevice, return)
	vkDestroyDevice = {
		self = {1, 'self.real'},
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
		self = {1, 'self.real'},
	}, -- (physicalDevice, pPropertyCount, pProperties, return)
	vkEnumerateDeviceExtensionProperties = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pLayerName, pPropertyCount, pProperties, return)
	vkGetDeviceQueue = {
		self = {1, 'self.real'},
	}, -- (device, queueFamilyIndex, queueIndex, pQueue)
	vkQueueSubmit = {
		self = {1, 'self.real'},
	}, -- (queue, submitCount, pSubmits, fence, return)
	vkQueueWaitIdle = {
		self = {1, 'self.real'},
	}, -- (queue, return)
	vkDeviceWaitIdle = {
		self = {1, 'self.real'},
	}, -- (device, return)
	vkAllocateMemory = {
		self = {1, 'self.real'},
	}, -- (device, pAllocateInfo, pAllocator, pMemory, return)
	vkFreeMemory = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, memory, pAllocator)
	vkMapMemory = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, memory, offset, size, flags, ppData, return)
	vkUnmapMemory = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, memory)
	vkFlushMappedMemoryRanges = {
		self = {1, 'self.real'},
	}, -- (device, memoryRangeCount, pMemoryRanges, return)
	vkInvalidateMappedMemoryRanges = {
		self = {1, 'self.real'},
	}, -- (device, memoryRangeCount, pMemoryRanges, return)
	vkGetDeviceMemoryCommitment = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, memory, pCommittedMemoryInBytes)
	vkGetBufferMemoryRequirements = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, buffer, pMemoryRequirements)
	vkBindBufferMemory = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, buffer, memory, memoryOffset, return)
	vkGetImageMemoryRequirements = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, image, pMemoryRequirements)
	vkBindImageMemory = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, image, memory, memoryOffset, return)
	vkGetImageSparseMemoryRequirements = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, image, pSparseMemoryRequirementCount, pSparseMemoryRequirements)
	vkGetPhysicalDeviceSparseImageFormatProperties = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, format, type, samples, usage, tiling, pPropertyCount, pProperties)
	vkQueueBindSparse = {
		self = {1, 'self.real'},
	}, -- (queue, bindInfoCount, pBindInfo, fence, return)
	vkCreateFence = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pFence, return)
	vkDestroyFence = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, fence, pAllocator)
	vkResetFences = {
		self = {1, 'self.real'},
	}, -- (device, fenceCount, pFences, return)
	vkGetFenceStatus = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, fence, return)
	vkWaitForFences = {
		self = {1, 'self.real'},
	}, -- (device, fenceCount, pFences, waitAll, timeout, return)
	vkCreateSemaphore = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pSemaphore, return)
	vkDestroySemaphore = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, semaphore, pAllocator)
	vkCreateEvent = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pEvent, return)
	vkDestroyEvent = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, event, pAllocator)
	vkGetEventStatus = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, event, return)
	vkSetEvent = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, event, return)
	vkResetEvent = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, event, return)
	vkCreateQueryPool = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pQueryPool, return)
	vkDestroyQueryPool = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, queryPool, pAllocator)
	vkGetQueryPoolResults = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, queryPool, firstQuery, queryCount, dataSize, pData, stride, flags, return)
	vkCreateBuffer = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pBuffer, return)
	vkDestroyBuffer = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, buffer, pAllocator)
	vkCreateBufferView = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pView, return)
	vkDestroyBufferView = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, bufferView, pAllocator)
	vkCreateImage = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pImage, return)
	vkDestroyImage = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, image, pAllocator)
	vkGetImageSubresourceLayout = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, image, pSubresource, pLayout)
	vkCreateImageView = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pView, return)
	vkDestroyImageView = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, imageView, pAllocator)
	vkCreateShaderModule = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pShaderModule, return)
	vkDestroyShaderModule = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, shaderModule, pAllocator)
	vkCreatePipelineCache = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pPipelineCache, return)
	vkDestroyPipelineCache = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, pipelineCache, pAllocator)
	vkGetPipelineCacheData = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, pipelineCache, pDataSize, pData, return)
	vkMergePipelineCaches = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, dstCache, srcCacheCount, pSrcCaches, return)
	vkCreateGraphicsPipelines = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, pipelineCache, createInfoCount, pCreateInfos, pAllocator, pPipelines, return)
	vkCreateComputePipelines = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, pipelineCache, createInfoCount, pCreateInfos, pAllocator, pPipelines, return)
	vkDestroyPipeline = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, pipeline, pAllocator)
	vkCreatePipelineLayout = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pPipelineLayout, return)
	vkDestroyPipelineLayout = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, pipelineLayout, pAllocator)
	vkCreateSampler = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pSampler, return)
	vkDestroySampler = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, sampler, pAllocator)
	vkCreateDescriptorSetLayout = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pSetLayout, return)
	vkDestroyDescriptorSetLayout = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, descriptorSetLayout, pAllocator)
	vkCreateDescriptorPool = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pDescriptorPool, return)
	vkDestroyDescriptorPool = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, descriptorPool, pAllocator)
	vkResetDescriptorPool = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, descriptorPool, flags, return)
	vkAllocateDescriptorSets = {
		self = {1, 'self.real'},
	}, -- (device, pAllocateInfo, pDescriptorSets, return)
	vkFreeDescriptorSets = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, descriptorPool, descriptorSetCount, pDescriptorSets, return)
	vkUpdateDescriptorSets = {
		self = {1, 'self.real'},
	}, -- (device, descriptorWriteCount, pDescriptorWrites, descriptorCopyCount, pDescriptorCopies)
	vkCreateFramebuffer = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pFramebuffer, return)
	vkDestroyFramebuffer = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, framebuffer, pAllocator)
	vkCreateRenderPass = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pRenderPass, return)
	vkDestroyRenderPass = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, renderPass, pAllocator)
	vkGetRenderAreaGranularity = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, renderPass, pGranularity)
	vkCreateCommandPool = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pCommandPool, return)
	vkDestroyCommandPool = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, commandPool, pAllocator)
	vkResetCommandPool = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, commandPool, flags, return)
	vkAllocateCommandBuffers = {
		self = {1, 'self.real'},
	}, -- (device, pAllocateInfo, pCommandBuffers, return)
	vkFreeCommandBuffers = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, commandPool, commandBufferCount, pCommandBuffers)
	vkBeginCommandBuffer = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, pBeginInfo, return)
	vkEndCommandBuffer = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, return)
	vkResetCommandBuffer = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, flags, return)
	vkCmdBindPipeline = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, pipelineBindPoint, pipeline)
	vkCmdSetViewport = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, firstViewport, viewportCount, pViewports)
	vkCmdSetScissor = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, firstScissor, scissorCount, pScissors)
	vkCmdSetLineWidth = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, lineWidth)
	vkCmdSetDepthBias = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, depthBiasConstantFactor, depthBiasClamp, depthBiasSlopeFactor)
	vkCmdSetBlendConstants = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, blendConstants)
	vkCmdSetDepthBounds = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, minDepthBounds, maxDepthBounds)
	vkCmdSetStencilCompareMask = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, faceMask, compareMask)
	vkCmdSetStencilWriteMask = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, faceMask, writeMask)
	vkCmdSetStencilReference = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, faceMask, reference)
	vkCmdBindDescriptorSets = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, pipelineBindPoint, layout, firstSet, descriptorSetCount, pDescriptorSets, dynamicOffsetCount, pDynamicOffsets)
	vkCmdBindIndexBuffer = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, buffer, offset, indexType)
	vkCmdBindVertexBuffers = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, firstBinding, bindingCount, pBuffers, pOffsets)
	vkCmdDraw = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, vertexCount, instanceCount, firstVertex, firstInstance)
	vkCmdDrawIndexed = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, indexCount, instanceCount, firstIndex, vertexOffset, firstInstance)
	vkCmdDrawIndirect = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, buffer, offset, drawCount, stride)
	vkCmdDrawIndexedIndirect = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, buffer, offset, drawCount, stride)
	vkCmdDispatch = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, groupCountX, groupCountY, groupCountZ)
	vkCmdDispatchIndirect = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, buffer, offset)
	vkCmdCopyBuffer = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, srcBuffer, dstBuffer, regionCount, pRegions)
	vkCmdCopyImage = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, srcImage, srcImageLayout, dstImage, dstImageLayout, regionCount, pRegions)
	vkCmdBlitImage = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, srcImage, srcImageLayout, dstImage, dstImageLayout, regionCount, pRegions, filter)
	vkCmdCopyBufferToImage = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, srcBuffer, dstImage, dstImageLayout, regionCount, pRegions)
	vkCmdCopyImageToBuffer = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, srcImage, srcImageLayout, dstBuffer, regionCount, pRegions)
	vkCmdUpdateBuffer = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, dstBuffer, dstOffset, dataSize, pData)
	vkCmdFillBuffer = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, dstBuffer, dstOffset, size, data)
	vkCmdClearColorImage = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, image, imageLayout, pColor, rangeCount, pRanges)
	vkCmdClearDepthStencilImage = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, image, imageLayout, pDepthStencil, rangeCount, pRanges)
	vkCmdClearAttachments = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, attachmentCount, pAttachments, rectCount, pRects)
	vkCmdResolveImage = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, srcImage, srcImageLayout, dstImage, dstImageLayout, regionCount, pRegions)
	vkCmdSetEvent = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, event, stageMask)
	vkCmdResetEvent = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, event, stageMask)
	vkCmdWaitEvents = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, eventCount, pEvents, srcStageMask, dstStageMask, memoryBarrierCount, pMemoryBarriers, bufferMemoryBarrierCount, pBufferMemoryBarriers, imageMemoryBarrierCount, pImageMemoryBarriers)
	vkCmdPipelineBarrier = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, srcStageMask, dstStageMask, dependencyFlags, memoryBarrierCount, pMemoryBarriers, bufferMemoryBarrierCount, pBufferMemoryBarriers, imageMemoryBarrierCount, pImageMemoryBarriers)
	vkCmdBeginQuery = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, queryPool, query, flags)
	vkCmdEndQuery = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, queryPool, query)
	vkCmdResetQueryPool = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, queryPool, firstQuery, queryCount)
	vkCmdWriteTimestamp = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, pipelineStage, queryPool, query)
	vkCmdCopyQueryPoolResults = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, queryPool, firstQuery, queryCount, dstBuffer, dstOffset, stride, flags)
	vkCmdPushConstants = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, layout, stageFlags, offset, size, pValues)
	vkCmdBeginRenderPass = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, pRenderPassBegin, contents)
	vkCmdNextSubpass = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, contents)
	vkCmdEndRenderPass = {
		self = {1, 'self.real'},
	}, -- (commandBuffer)
	vkCmdExecuteCommands = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, commandBufferCount, pCommandBuffers)
	vkCreateAndroidSurfaceKHR = {
		self = {1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkGetPhysicalDeviceDisplayPropertiesKHR = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pPropertyCount, pProperties, return)
	vkGetPhysicalDeviceDisplayPlanePropertiesKHR = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pPropertyCount, pProperties, return)
	vkGetDisplayPlaneSupportedDisplaysKHR = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, planeIndex, pDisplayCount, pDisplays, return)
	vkGetDisplayModePropertiesKHR = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (physicalDevice, display, pPropertyCount, pProperties, return)
	vkCreateDisplayModeKHR = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (physicalDevice, display, pCreateInfo, pAllocator, pMode, return)
	vkGetDisplayPlaneCapabilitiesKHR = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (physicalDevice, mode, planeIndex, pCapabilities, return)
	vkCreateDisplayPlaneSurfaceKHR = {
		self = {1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkCreateSharedSwapchainsKHR = {
		self = {1, 'self.real'},
	}, -- (device, swapchainCount, pCreateInfos, pAllocator, pSwapchains, return)
	vkCreateMirSurfaceKHR = {
		self = {1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkGetPhysicalDeviceMirPresentationSupportKHR = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, queueFamilyIndex, connection, return)
	vkDestroySurfaceKHR = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (instance, surface, pAllocator)
	vkGetPhysicalDeviceSurfaceSupportKHR = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, queueFamilyIndex, surface, pSupported, return)
	vkGetPhysicalDeviceSurfaceCapabilitiesKHR = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (physicalDevice, surface, pSurfaceCapabilities, return)
	vkGetPhysicalDeviceSurfaceFormatsKHR = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (physicalDevice, surface, pSurfaceFormatCount, pSurfaceFormats, return)
	vkGetPhysicalDeviceSurfacePresentModesKHR = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (physicalDevice, surface, pPresentModeCount, pPresentModes, return)
	vkCreateSwapchainKHR = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pSwapchain, return)
	vkDestroySwapchainKHR = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, swapchain, pAllocator)
	vkGetSwapchainImagesKHR = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, swapchain, pSwapchainImageCount, pSwapchainImages, return)
	vkAcquireNextImageKHR = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, swapchain, timeout, semaphore, fence, pImageIndex, return)
	vkQueuePresentKHR = {
		self = {1, 'self.real'},
	}, -- (queue, pPresentInfo, return)
	vkCreateViSurfaceNN = {
		self = {1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkCreateWaylandSurfaceKHR = {
		self = {1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkGetPhysicalDeviceWaylandPresentationSupportKHR = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, queueFamilyIndex, display, return)
	vkCreateWin32SurfaceKHR = {
		self = {1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkGetPhysicalDeviceWin32PresentationSupportKHR = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, queueFamilyIndex, return)
	vkCreateXlibSurfaceKHR = {
		self = {1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkGetPhysicalDeviceXlibPresentationSupportKHR = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, queueFamilyIndex, dpy, visualID, return)
	vkCreateXcbSurfaceKHR = {
		self = {1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkGetPhysicalDeviceXcbPresentationSupportKHR = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, queueFamilyIndex, connection, visual_id, return)
	vkCreateDebugReportCallbackEXT = {
		self = {1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pCallback, return)
	vkDestroyDebugReportCallbackEXT = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (instance, callback, pAllocator)
	vkDebugReportMessageEXT = {
		self = {1, 'self.real'},
	}, -- (instance, flags, objectType, object, location, messageCode, pLayerPrefix, pMessage)
	vkDebugMarkerSetObjectNameEXT = {
		self = {1, 'self.real'},
	}, -- (device, pNameInfo, return)
	vkDebugMarkerSetObjectTagEXT = {
		self = {1, 'self.real'},
	}, -- (device, pTagInfo, return)
	vkCmdDebugMarkerBeginEXT = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, pMarkerInfo)
	vkCmdDebugMarkerEndEXT = {
		self = {1, 'self.real'},
	}, -- (commandBuffer)
	vkCmdDebugMarkerInsertEXT = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, pMarkerInfo)
	vkGetPhysicalDeviceExternalImageFormatPropertiesNV = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, format, type, tiling, usage, flags, externalHandleType, pExternalImageFormatProperties, return)
	vkGetMemoryWin32HandleNV = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, memory, handleType, pHandle, return)
	vkCmdDrawIndirectCountAMD = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, buffer, offset, countBuffer, countBufferOffset, maxDrawCount, stride)
	vkCmdDrawIndexedIndirectCountAMD = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, buffer, offset, countBuffer, countBufferOffset, maxDrawCount, stride)
	vkCmdProcessCommandsNVX = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, pProcessCommandsInfo)
	vkCmdReserveSpaceForCommandsNVX = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, pReserveSpaceInfo)
	vkCreateIndirectCommandsLayoutNVX = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pIndirectCommandsLayout, return)
	vkDestroyIndirectCommandsLayoutNVX = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, indirectCommandsLayout, pAllocator)
	vkCreateObjectTableNVX = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pObjectTable, return)
	vkDestroyObjectTableNVX = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, objectTable, pAllocator)
	vkRegisterObjectsNVX = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, objectTable, objectCount, ppObjectTableEntries, pObjectIndices, return)
	vkUnregisterObjectsNVX = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, objectTable, objectCount, pObjectEntryTypes, pObjectIndices, return)
	vkGetPhysicalDeviceGeneratedCommandsPropertiesNVX = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pFeatures, pLimits)
	vkGetPhysicalDeviceFeatures2 = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pFeatures)
	vkGetPhysicalDeviceProperties2 = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pProperties)
	vkGetPhysicalDeviceFormatProperties2 = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, format, pFormatProperties)
	vkGetPhysicalDeviceImageFormatProperties2 = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pImageFormatInfo, pImageFormatProperties, return)
	vkGetPhysicalDeviceQueueFamilyProperties2 = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pQueueFamilyPropertyCount, pQueueFamilyProperties)
	vkGetPhysicalDeviceMemoryProperties2 = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pMemoryProperties)
	vkGetPhysicalDeviceSparseImageFormatProperties2 = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pFormatInfo, pPropertyCount, pProperties)
	vkCmdPushDescriptorSetKHR = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, pipelineBindPoint, layout, set, descriptorWriteCount, pDescriptorWrites)
	vkTrimCommandPool = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, commandPool, flags)
	vkGetPhysicalDeviceExternalBufferProperties = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pExternalBufferInfo, pExternalBufferProperties)
	vkGetMemoryWin32HandleKHR = {
		self = {1, 'self.real'},
	}, -- (device, pGetWin32HandleInfo, pHandle, return)
	vkGetMemoryWin32HandlePropertiesKHR = {
		self = {1, 'self.real'},
	}, -- (device, handleType, handle, pMemoryWin32HandleProperties, return)
	vkGetMemoryFdKHR = {
		self = {1, 'self.real'},
	}, -- (device, pGetFdInfo, pFd, return)
	vkGetMemoryFdPropertiesKHR = {
		self = {1, 'self.real'},
	}, -- (device, handleType, fd, pMemoryFdProperties, return)
	vkGetPhysicalDeviceExternalSemaphoreProperties = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pExternalSemaphoreInfo, pExternalSemaphoreProperties)
	vkGetSemaphoreWin32HandleKHR = {
		self = {1, 'self.real'},
	}, -- (device, pGetWin32HandleInfo, pHandle, return)
	vkImportSemaphoreWin32HandleKHR = {
		self = {1, 'self.real'},
	}, -- (device, pImportSemaphoreWin32HandleInfo, return)
	vkGetSemaphoreFdKHR = {
		self = {1, 'self.real'},
	}, -- (device, pGetFdInfo, pFd, return)
	vkImportSemaphoreFdKHR = {
		self = {1, 'self.real'},
	}, -- (device, pImportSemaphoreFdInfo, return)
	vkGetPhysicalDeviceExternalFenceProperties = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pExternalFenceInfo, pExternalFenceProperties)
	vkGetFenceWin32HandleKHR = {
		self = {1, 'self.real'},
	}, -- (device, pGetWin32HandleInfo, pHandle, return)
	vkImportFenceWin32HandleKHR = {
		self = {1, 'self.real'},
	}, -- (device, pImportFenceWin32HandleInfo, return)
	vkGetFenceFdKHR = {
		self = {1, 'self.real'},
	}, -- (device, pGetFdInfo, pFd, return)
	vkImportFenceFdKHR = {
		self = {1, 'self.real'},
	}, -- (device, pImportFenceFdInfo, return)
	vkReleaseDisplayEXT = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (physicalDevice, display, return)
	vkAcquireXlibDisplayEXT = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, dpy, display, return)
	vkGetRandROutputDisplayEXT = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, dpy, rrOutput, pDisplay, return)
	vkDisplayPowerControlEXT = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, display, pDisplayPowerInfo, return)
	vkRegisterDeviceEventEXT = {
		self = {1, 'self.real'},
	}, -- (device, pDeviceEventInfo, pAllocator, pFence, return)
	vkRegisterDisplayEventEXT = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, display, pDisplayEventInfo, pAllocator, pFence, return)
	vkGetSwapchainCounterEXT = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, swapchain, counter, pCounterValue, return)
	vkGetPhysicalDeviceSurfaceCapabilities2EXT = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (physicalDevice, surface, pSurfaceCapabilities, return)
	vkEnumeratePhysicalDeviceGroups = {
		self = {1, 'self.real'},
	}, -- (instance, pPhysicalDeviceGroupCount, pPhysicalDeviceGroupProperties, return)
	vkGetDeviceGroupPeerMemoryFeatures = {
		self = {1, 'self.real'},
	}, -- (device, heapIndex, localDeviceIndex, remoteDeviceIndex, pPeerMemoryFeatures)
	vkBindBufferMemory2 = {
		self = {1, 'self.real'},
	}, -- (device, bindInfoCount, pBindInfos, return)
	vkBindImageMemory2 = {
		self = {1, 'self.real'},
	}, -- (device, bindInfoCount, pBindInfos, return)
	vkCmdSetDeviceMask = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, deviceMask)
	vkGetDeviceGroupPresentCapabilitiesKHR = {
		self = {1, 'self.real'},
	}, -- (device, pDeviceGroupPresentCapabilities, return)
	vkGetDeviceGroupSurfacePresentModesKHR = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, surface, pModes, return)
	vkAcquireNextImage2KHR = {
		self = {1, 'self.real'},
	}, -- (device, pAcquireInfo, pImageIndex, return)
	vkCmdDispatchBase = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, baseGroupX, baseGroupY, baseGroupZ, groupCountX, groupCountY, groupCountZ)
	vkGetPhysicalDevicePresentRectanglesKHR = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (physicalDevice, surface, pRectCount, pRects, return)
	vkCreateDescriptorUpdateTemplate = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pDescriptorUpdateTemplate, return)
	vkDestroyDescriptorUpdateTemplate = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, descriptorUpdateTemplate, pAllocator)
	vkUpdateDescriptorSetWithTemplate = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, descriptorSet, descriptorUpdateTemplate, pData)
	vkCmdPushDescriptorSetWithTemplateKHR = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (commandBuffer, descriptorUpdateTemplate, layout, set, pData)
	vkSetHdrMetadataEXT = {
		self = {1, 'self.real'},
	}, -- (device, swapchainCount, pSwapchains, pMetadata)
	vkGetSwapchainStatusKHR = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, swapchain, return)
	vkGetRefreshCycleDurationGOOGLE = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, swapchain, pDisplayTimingProperties, return)
	vkGetPastPresentationTimingGOOGLE = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, swapchain, pPresentationTimingCount, pPresentationTimings, return)
	vkCreateIOSSurfaceMVK = {
		self = {1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkCreateMacOSSurfaceMVK = {
		self = {1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkCmdSetViewportWScalingNV = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, firstViewport, viewportCount, pViewportWScalings)
	vkCmdSetDiscardRectangleEXT = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, firstDiscardRectangle, discardRectangleCount, pDiscardRectangles)
	vkCmdSetSampleLocationsEXT = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, pSampleLocationsInfo)
	vkGetPhysicalDeviceMultisamplePropertiesEXT = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, samples, pMultisampleProperties)
	vkGetPhysicalDeviceSurfaceCapabilities2KHR = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pSurfaceInfo, pSurfaceCapabilities, return)
	vkGetPhysicalDeviceSurfaceFormats2KHR = {
		self = {1, 'self.real'},
	}, -- (physicalDevice, pSurfaceInfo, pSurfaceFormatCount, pSurfaceFormats, return)
	vkGetBufferMemoryRequirements2 = {
		self = {1, 'self.real'},
	}, -- (device, pInfo, pMemoryRequirements)
	vkGetImageMemoryRequirements2 = {
		self = {1, 'self.real'},
	}, -- (device, pInfo, pMemoryRequirements)
	vkGetImageSparseMemoryRequirements2 = {
		self = {1, 'self.real'},
	}, -- (device, pInfo, pSparseMemoryRequirementCount, pSparseMemoryRequirements)
	vkCreateSamplerYcbcrConversion = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pYcbcrConversion, return)
	vkDestroySamplerYcbcrConversion = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, ycbcrConversion, pAllocator)
	vkGetDeviceQueue2 = {
		self = {1, 'self.real'},
	}, -- (device, pQueueInfo, pQueue)
	vkCreateValidationCacheEXT = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pAllocator, pValidationCache, return)
	vkDestroyValidationCacheEXT = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, validationCache, pAllocator)
	vkGetValidationCacheDataEXT = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, validationCache, pDataSize, pData, return)
	vkMergeValidationCachesEXT = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, dstCache, srcCacheCount, pSrcCaches, return)
	vkGetDescriptorSetLayoutSupport = {
		self = {1, 'self.real'},
	}, -- (device, pCreateInfo, pSupport)
	vkGetSwapchainGrallocUsageANDROID = {
		self = {1, 'self.real'},
	}, -- (device, format, imageUsage, grallocUsage, return)
	vkAcquireImageANDROID = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, image, nativeFenceFd, semaphore, fence, return)
	vkQueueSignalReleaseImageANDROID = {
		self = {1, 'self.real'},
	}, -- (queue, waitSemaphoreCount, pWaitSemaphores, image, pNativeFenceFd, return)
	vkGetShaderInfoAMD = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (device, pipeline, shaderStage, infoType, pInfoSize, pInfo, return)
	vkSetDebugUtilsObjectNameEXT = {
		self = {1, 'self.real'},
	}, -- (device, pNameInfo, return)
	vkSetDebugUtilsObjectTagEXT = {
		self = {1, 'self.real'},
	}, -- (device, pTagInfo, return)
	vkQueueBeginDebugUtilsLabelEXT = {
		self = {1, 'self.real'},
	}, -- (queue, pLabelInfo)
	vkQueueEndDebugUtilsLabelEXT = {
		self = {1, 'self.real'},
	}, -- (queue)
	vkQueueInsertDebugUtilsLabelEXT = {
		self = {1, 'self.real'},
	}, -- (queue, pLabelInfo)
	vkCmdBeginDebugUtilsLabelEXT = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, pLabelInfo)
	vkCmdEndDebugUtilsLabelEXT = {
		self = {1, 'self.real'},
	}, -- (commandBuffer)
	vkCmdInsertDebugUtilsLabelEXT = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, pLabelInfo)
	vkCreateDebugUtilsMessengerEXT = {
		self = {1, 'self.real'},
	}, -- (instance, pCreateInfo, pAllocator, pMessenger, return)
	vkDestroyDebugUtilsMessengerEXT = {
		self = {2, 'self.parent.real', 'self.real'},
	}, -- (instance, messenger, pAllocator)
	vkSubmitDebugUtilsMessageEXT = {
		self = {1, 'self.real'},
	}, -- (instance, messageSeverity, messageTypes, pCallbackData)
	vkGetMemoryHostPointerPropertiesEXT = {
		self = {1, 'self.real'},
	}, -- (device, handleType, pHostPointer, pMemoryHostPointerProperties, return)
	vkCmdWriteBufferMarkerAMD = {
		self = {1, 'self.real'},
	}, -- (commandBuffer, pipelineStage, dstBuffer, dstOffset, marker)
	vkGetAndroidHardwareBufferPropertiesANDROID = {
		self = {1, 'self.real'},
	}, -- (device, buffer, pProperties, return)
	vkGetMemoryAndroidHardwareBufferANDROID = {
		self = {1, 'self.real'},
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
	local val = assert(load('return ('..elem._len:gsub('::', '.')..')', nil, 't', new(parent)))()
	if type(val) == 'table' then
		if elem.canbenil then
			local k = partype.__raw..'_'..elem.name
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
	return not t.__index and not t.__mask and not t.__enum and t.__raw and t.__raw:match '^Vk'
end
local function guess(entries, name)
	local out = "false"
	if entries[2] and ishandle(entries[2].type) then
		out = "{2, 'self.parent.real', 'self.real'}"
	elseif entries[1] and ishandle(entries[1].type) then
		out = "{1, 'self.real'}"
	end
	local names = {}
	for _,e in ipairs(entries) do names[#names+1] = e.name end
	human.herror('\t'..name..' = {\n\t\tself = '..out..',\n\t}, -- ('..table.concat(names,', ')..')')
end

-- Commands in Vulkan are not associated with any particular handle, but most
-- only make sense within the context of one, so we make the association ourselves.
-- `entries` is the raw argument list to work with
-- `name` is the name of the command in question.
function human.self(entries, name)
	local s = cmdinfo[name]
	if not s then guess(entries, name)
	elseif s.self then return entries[s.self[1]].type, table.unpack(s.self, 2) end
end

return human
