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

-- There's no good way to find errors in the self-guesser, so we just write them
-- all out as a massive table. See human.self below for details.
local selves = {
	vkCreateInstance = true,
	vkDestroyInstance = {1, 'self.real'},
	vkEnumeratePhysicalDevices = {1, 'self.real'},
	vkGetDeviceProcAddr = {1, 'self.real'},
	vkGetInstanceProcAddr = {1, 'self.real'},
	vkGetPhysicalDeviceProperties = {1, 'self.real'},
	vkGetPhysicalDeviceQueueFamilyProperties = {1, 'self.real'},
	vkGetPhysicalDeviceMemoryProperties = {1, 'self.real'},
	vkGetPhysicalDeviceFeatures = {1, 'self.real'},
	vkGetPhysicalDeviceFormatProperties = {1, 'self.real'},
	vkGetPhysicalDeviceImageFormatProperties = {1, 'self.real'},
	vkCreateDevice = {1, 'self.real'},
	vkDestroyDevice = {1, 'self.real'},
	vkEnumerateInstanceVersion = true,
	vkEnumerateInstanceLayerProperties = true,
	vkEnumerateInstanceExtensionProperties = true,
	vkEnumerateDeviceLayerProperties = {1, 'self.real'},
	vkEnumerateDeviceExtensionProperties = {1, 'self.real'},
	vkGetDeviceQueue = {1, 'self.real'},
	vkQueueSubmit = {1, 'self.real'},
	vkQueueWaitIdle = {1, 'self.real'},
	vkDeviceWaitIdle = {1, 'self.real'},
	vkAllocateMemory = {1, 'self.real'},
	vkFreeMemory = {2, 'self.parent.real', 'self.real'},
	vkMapMemory = {2, 'self.parent.real', 'self.real'},
	vkUnmapMemory = {2, 'self.parent.real', 'self.real'},
	vkFlushMappedMemoryRanges = {1, 'self.real'}, -- (device, memoryRangeCount, pMemoryRanges, return)
	vkInvalidateMappedMemoryRanges = {1, 'self.real'}, -- (device, memoryRangeCount, pMemoryRanges, return)
	vkGetDeviceMemoryCommitment = {2, 'self.parent.real', 'self.real'}, -- (device, memory, pCommittedMemoryInBytes)
	vkGetBufferMemoryRequirements = {2, 'self.parent.real', 'self.real'}, -- (device, buffer, pMemoryRequirements)
	vkBindBufferMemory = {2, 'self.parent.real', 'self.real'}, -- (device, buffer, memory, memoryOffset, return)
	vkGetImageMemoryRequirements = {2, 'self.parent.real', 'self.real'}, -- (device, image, pMemoryRequirements)
	vkBindImageMemory = {2, 'self.parent.real', 'self.real'}, -- (device, image, memory, memoryOffset, return)
	vkGetImageSparseMemoryRequirements = {2, 'self.parent.real', 'self.real'}, -- (device, image, pSparseMemoryRequirementCount, pSparseMemoryRequirements)
	vkGetPhysicalDeviceSparseImageFormatProperties = {1, 'self.real'}, -- (physicalDevice, format, type, samples, usage, tiling, pPropertyCount, pProperties)
	vkQueueBindSparse = {1, 'self.real'}, -- (queue, bindInfoCount, pBindInfo, fence, return)
	vkCreateFence = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pFence, return)
	vkDestroyFence = {2, 'self.parent.real', 'self.real'}, -- (device, fence, pAllocator)
	vkResetFences = {1, 'self.real'}, -- (device, fenceCount, pFences, return)
	vkGetFenceStatus = {2, 'self.parent.real', 'self.real'}, -- (device, fence, return)
	vkWaitForFences = {1, 'self.real'}, -- (device, fenceCount, pFences, waitAll, timeout, return)
	vkCreateSemaphore = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pSemaphore, return)
	vkDestroySemaphore = {2, 'self.parent.real', 'self.real'}, -- (device, semaphore, pAllocator)
	vkCreateEvent = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pEvent, return)
	vkDestroyEvent = {2, 'self.parent.real', 'self.real'}, -- (device, event, pAllocator)
	vkGetEventStatus = {2, 'self.parent.real', 'self.real'}, -- (device, event, return)
	vkSetEvent = {2, 'self.parent.real', 'self.real'}, -- (device, event, return)
	vkResetEvent = {2, 'self.parent.real', 'self.real'}, -- (device, event, return)
	vkCreateQueryPool = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pQueryPool, return)
	vkDestroyQueryPool = {2, 'self.parent.real', 'self.real'}, -- (device, queryPool, pAllocator)
	vkGetQueryPoolResults = {2, 'self.parent.real', 'self.real'}, -- (device, queryPool, firstQuery, queryCount, dataSize, pData, stride, flags, return)
	vkCreateBuffer = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pBuffer, return)
	vkDestroyBuffer = {2, 'self.parent.real', 'self.real'}, -- (device, buffer, pAllocator)
	vkCreateBufferView = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pView, return)
	vkDestroyBufferView = {2, 'self.parent.real', 'self.real'}, -- (device, bufferView, pAllocator)
	vkCreateImage = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pImage, return)
	vkDestroyImage = {2, 'self.parent.real', 'self.real'}, -- (device, image, pAllocator)
	vkGetImageSubresourceLayout = {2, 'self.parent.real', 'self.real'}, -- (device, image, pSubresource, pLayout)
	vkCreateImageView = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pView, return)
	vkDestroyImageView = {2, 'self.parent.real', 'self.real'}, -- (device, imageView, pAllocator)
	vkCreateShaderModule = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pShaderModule, return)
	vkDestroyShaderModule = {2, 'self.parent.real', 'self.real'}, -- (device, shaderModule, pAllocator)
	vkCreatePipelineCache = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pPipelineCache, return)
	vkDestroyPipelineCache = {2, 'self.parent.real', 'self.real'}, -- (device, pipelineCache, pAllocator)
	vkGetPipelineCacheData = {2, 'self.parent.real', 'self.real'}, -- (device, pipelineCache, pDataSize, pData, return)
	vkMergePipelineCaches = {2, 'self.parent.real', 'self.real'}, -- (device, dstCache, srcCacheCount, pSrcCaches, return)
	vkCreateGraphicsPipelines = {2, 'self.parent.real', 'self.real'}, -- (device, pipelineCache, createInfoCount, pCreateInfos, pAllocator, pPipelines, return)
	vkCreateComputePipelines = {2, 'self.parent.real', 'self.real'}, -- (device, pipelineCache, createInfoCount, pCreateInfos, pAllocator, pPipelines, return)
	vkDestroyPipeline = {2, 'self.parent.real', 'self.real'}, -- (device, pipeline, pAllocator)
	vkCreatePipelineLayout = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pPipelineLayout, return)
	vkDestroyPipelineLayout = {2, 'self.parent.real', 'self.real'}, -- (device, pipelineLayout, pAllocator)
	vkCreateSampler = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pSampler, return)
	vkDestroySampler = {2, 'self.parent.real', 'self.real'}, -- (device, sampler, pAllocator)
	vkCreateDescriptorSetLayout = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pSetLayout, return)
	vkDestroyDescriptorSetLayout = {2, 'self.parent.real', 'self.real'}, -- (device, descriptorSetLayout, pAllocator)
	vkCreateDescriptorPool = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pDescriptorPool, return)
	vkDestroyDescriptorPool = {2, 'self.parent.real', 'self.real'}, -- (device, descriptorPool, pAllocator)
	vkResetDescriptorPool = {2, 'self.parent.real', 'self.real'}, -- (device, descriptorPool, flags, return)
	vkAllocateDescriptorSets = {1, 'self.real'}, -- (device, pAllocateInfo, pDescriptorSets, return)
	vkFreeDescriptorSets = {2, 'self.parent.real', 'self.real'}, -- (device, descriptorPool, descriptorSetCount, pDescriptorSets, return)
	vkUpdateDescriptorSets = {1, 'self.real'}, -- (device, descriptorWriteCount, pDescriptorWrites, descriptorCopyCount, pDescriptorCopies)
	vkCreateFramebuffer = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pFramebuffer, return)
	vkDestroyFramebuffer = {2, 'self.parent.real', 'self.real'}, -- (device, framebuffer, pAllocator)
	vkCreateRenderPass = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pRenderPass, return)
	vkDestroyRenderPass = {2, 'self.parent.real', 'self.real'}, -- (device, renderPass, pAllocator)
	vkGetRenderAreaGranularity = {2, 'self.parent.real', 'self.real'}, -- (device, renderPass, pGranularity)
	vkCreateCommandPool = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pCommandPool, return)
	vkDestroyCommandPool = {2, 'self.parent.real', 'self.real'}, -- (device, commandPool, pAllocator)
	vkResetCommandPool = {2, 'self.parent.real', 'self.real'}, -- (device, commandPool, flags, return)
	vkAllocateCommandBuffers = {1, 'self.real'}, -- (device, pAllocateInfo, pCommandBuffers, return)
	vkFreeCommandBuffers = {2, 'self.parent.real', 'self.real'}, -- (device, commandPool, commandBufferCount, pCommandBuffers)
	vkBeginCommandBuffer = {1, 'self.real'}, -- (commandBuffer, pBeginInfo, return)
	vkEndCommandBuffer = {1, 'self.real'}, -- (commandBuffer, return)
	vkResetCommandBuffer = {1, 'self.real'}, -- (commandBuffer, flags, return)
	vkCmdBindPipeline = {1, 'self.real'}, -- (commandBuffer, pipelineBindPoint, pipeline)
	vkCmdSetViewport = {1, 'self.real'}, -- (commandBuffer, firstViewport, viewportCount, pViewports)
	vkCmdSetScissor = {1, 'self.real'}, -- (commandBuffer, firstScissor, scissorCount, pScissors)
	vkCmdSetLineWidth = {1, 'self.real'}, -- (commandBuffer, lineWidth)
	vkCmdSetDepthBias = {1, 'self.real'}, -- (commandBuffer, depthBiasConstantFactor, depthBiasClamp, depthBiasSlopeFactor)
	vkCmdSetBlendConstants = {1, 'self.real'}, -- (commandBuffer, blendConstants)
	vkCmdSetDepthBounds = {1, 'self.real'}, -- (commandBuffer, minDepthBounds, maxDepthBounds)
	vkCmdSetStencilCompareMask = {1, 'self.real'}, -- (commandBuffer, faceMask, compareMask)
	vkCmdSetStencilWriteMask = {1, 'self.real'}, -- (commandBuffer, faceMask, writeMask)
	vkCmdSetStencilReference = {1, 'self.real'}, -- (commandBuffer, faceMask, reference)
	vkCmdBindDescriptorSets = {1, 'self.real'}, -- (commandBuffer, pipelineBindPoint, layout, firstSet, descriptorSetCount, pDescriptorSets, dynamicOffsetCount, pDynamicOffsets)
	vkCmdBindIndexBuffer = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, buffer, offset, indexType)
	vkCmdBindVertexBuffers = {1, 'self.real'}, -- (commandBuffer, firstBinding, bindingCount, pBuffers, pOffsets)
	vkCmdDraw = {1, 'self.real'}, -- (commandBuffer, vertexCount, instanceCount, firstVertex, firstInstance)
	vkCmdDrawIndexed = {1, 'self.real'}, -- (commandBuffer, indexCount, instanceCount, firstIndex, vertexOffset, firstInstance)
	vkCmdDrawIndirect = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, buffer, offset, drawCount, stride)
	vkCmdDrawIndexedIndirect = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, buffer, offset, drawCount, stride)
	vkCmdDispatch = {1, 'self.real'}, -- (commandBuffer, groupCountX, groupCountY, groupCountZ)
	vkCmdDispatchIndirect = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, buffer, offset)
	vkCmdCopyBuffer = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, srcBuffer, dstBuffer, regionCount, pRegions)
	vkCmdCopyImage = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, srcImage, srcImageLayout, dstImage, dstImageLayout, regionCount, pRegions)
	vkCmdBlitImage = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, srcImage, srcImageLayout, dstImage, dstImageLayout, regionCount, pRegions, filter)
	vkCmdCopyBufferToImage = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, srcBuffer, dstImage, dstImageLayout, regionCount, pRegions)
	vkCmdCopyImageToBuffer = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, srcImage, srcImageLayout, dstBuffer, regionCount, pRegions)
	vkCmdUpdateBuffer = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, dstBuffer, dstOffset, dataSize, pData)
	vkCmdFillBuffer = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, dstBuffer, dstOffset, size, data)
	vkCmdClearColorImage = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, image, imageLayout, pColor, rangeCount, pRanges)
	vkCmdClearDepthStencilImage = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, image, imageLayout, pDepthStencil, rangeCount, pRanges)
	vkCmdClearAttachments = {1, 'self.real'}, -- (commandBuffer, attachmentCount, pAttachments, rectCount, pRects)
	vkCmdResolveImage = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, srcImage, srcImageLayout, dstImage, dstImageLayout, regionCount, pRegions)
	vkCmdSetEvent = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, event, stageMask)
	vkCmdResetEvent = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, event, stageMask)
	vkCmdWaitEvents = {1, 'self.real'}, -- (commandBuffer, eventCount, pEvents, srcStageMask, dstStageMask, memoryBarrierCount, pMemoryBarriers, bufferMemoryBarrierCount, pBufferMemoryBarriers, imageMemoryBarrierCount, pImageMemoryBarriers)
	vkCmdPipelineBarrier = {1, 'self.real'}, -- (commandBuffer, srcStageMask, dstStageMask, dependencyFlags, memoryBarrierCount, pMemoryBarriers, bufferMemoryBarrierCount, pBufferMemoryBarriers, imageMemoryBarrierCount, pImageMemoryBarriers)
	vkCmdBeginQuery = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, queryPool, query, flags)
	vkCmdEndQuery = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, queryPool, query)
	vkCmdResetQueryPool = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, queryPool, firstQuery, queryCount)
	vkCmdWriteTimestamp = {1, 'self.real'}, -- (commandBuffer, pipelineStage, queryPool, query)
	vkCmdCopyQueryPoolResults = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, queryPool, firstQuery, queryCount, dstBuffer, dstOffset, stride, flags)
	vkCmdPushConstants = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, layout, stageFlags, offset, size, pValues)
	vkCmdBeginRenderPass = {1, 'self.real'}, -- (commandBuffer, pRenderPassBegin, contents)
	vkCmdNextSubpass = {1, 'self.real'}, -- (commandBuffer, contents)
	vkCmdEndRenderPass = {1, 'self.real'}, -- (commandBuffer)
	vkCmdExecuteCommands = {1, 'self.real'}, -- (commandBuffer, commandBufferCount, pCommandBuffers)
	vkCreateAndroidSurfaceKHR = {1, 'self.real'}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkGetPhysicalDeviceDisplayPropertiesKHR = {1, 'self.real'}, -- (physicalDevice, pPropertyCount, pProperties, return)
	vkGetPhysicalDeviceDisplayPlanePropertiesKHR = {1, 'self.real'}, -- (physicalDevice, pPropertyCount, pProperties, return)
	vkGetDisplayPlaneSupportedDisplaysKHR = {1, 'self.real'}, -- (physicalDevice, planeIndex, pDisplayCount, pDisplays, return)
	vkGetDisplayModePropertiesKHR = {2, 'self.parent.real', 'self.real'}, -- (physicalDevice, display, pPropertyCount, pProperties, return)
	vkCreateDisplayModeKHR = {2, 'self.parent.real', 'self.real'}, -- (physicalDevice, display, pCreateInfo, pAllocator, pMode, return)
	vkGetDisplayPlaneCapabilitiesKHR = {2, 'self.parent.real', 'self.real'}, -- (physicalDevice, mode, planeIndex, pCapabilities, return)
	vkCreateDisplayPlaneSurfaceKHR = {1, 'self.real'}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkCreateSharedSwapchainsKHR = {1, 'self.real'}, -- (device, swapchainCount, pCreateInfos, pAllocator, pSwapchains, return)
	vkCreateMirSurfaceKHR = {1, 'self.real'}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkGetPhysicalDeviceMirPresentationSupportKHR = {1, 'self.real'}, -- (physicalDevice, queueFamilyIndex, connection, return)
	vkDestroySurfaceKHR = {2, 'self.parent.real', 'self.real'}, -- (instance, surface, pAllocator)
	vkGetPhysicalDeviceSurfaceSupportKHR = {1, 'self.real'}, -- (physicalDevice, queueFamilyIndex, surface, pSupported, return)
	vkGetPhysicalDeviceSurfaceCapabilitiesKHR = {2, 'self.parent.real', 'self.real'}, -- (physicalDevice, surface, pSurfaceCapabilities, return)
	vkGetPhysicalDeviceSurfaceFormatsKHR = {2, 'self.parent.real', 'self.real'}, -- (physicalDevice, surface, pSurfaceFormatCount, pSurfaceFormats, return)
	vkGetPhysicalDeviceSurfacePresentModesKHR = {2, 'self.parent.real', 'self.real'}, -- (physicalDevice, surface, pPresentModeCount, pPresentModes, return)
	vkCreateSwapchainKHR = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pSwapchain, return)
	vkDestroySwapchainKHR = {2, 'self.parent.real', 'self.real'}, -- (device, swapchain, pAllocator)
	vkGetSwapchainImagesKHR = {2, 'self.parent.real', 'self.real'}, -- (device, swapchain, pSwapchainImageCount, pSwapchainImages, return)
	vkAcquireNextImageKHR = {2, 'self.parent.real', 'self.real'}, -- (device, swapchain, timeout, semaphore, fence, pImageIndex, return)
	vkQueuePresentKHR = {1, 'self.real'}, -- (queue, pPresentInfo, return)
	vkCreateViSurfaceNN = {1, 'self.real'}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkCreateWaylandSurfaceKHR = {1, 'self.real'}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkGetPhysicalDeviceWaylandPresentationSupportKHR = {1, 'self.real'}, -- (physicalDevice, queueFamilyIndex, display, return)
	vkCreateWin32SurfaceKHR = {1, 'self.real'}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkGetPhysicalDeviceWin32PresentationSupportKHR = {1, 'self.real'}, -- (physicalDevice, queueFamilyIndex, return)
	vkCreateXlibSurfaceKHR = {1, 'self.real'}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkGetPhysicalDeviceXlibPresentationSupportKHR = {1, 'self.real'}, -- (physicalDevice, queueFamilyIndex, dpy, visualID, return)
	vkCreateXcbSurfaceKHR = {1, 'self.real'}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkGetPhysicalDeviceXcbPresentationSupportKHR = {1, 'self.real'}, -- (physicalDevice, queueFamilyIndex, connection, visual_id, return)
	vkCreateDebugReportCallbackEXT = {1, 'self.real'}, -- (instance, pCreateInfo, pAllocator, pCallback, return)
	vkDestroyDebugReportCallbackEXT = {2, 'self.parent.real', 'self.real'}, -- (instance, callback, pAllocator)
	vkDebugReportMessageEXT = {1, 'self.real'}, -- (instance, flags, objectType, object, location, messageCode, pLayerPrefix, pMessage)
	vkDebugMarkerSetObjectNameEXT = {1, 'self.real'}, -- (device, pNameInfo, return)
	vkDebugMarkerSetObjectTagEXT = {1, 'self.real'}, -- (device, pTagInfo, return)
	vkCmdDebugMarkerBeginEXT = {1, 'self.real'}, -- (commandBuffer, pMarkerInfo)
	vkCmdDebugMarkerEndEXT = {1, 'self.real'}, -- (commandBuffer)
	vkCmdDebugMarkerInsertEXT = {1, 'self.real'}, -- (commandBuffer, pMarkerInfo)
	vkGetPhysicalDeviceExternalImageFormatPropertiesNV = {1, 'self.real'}, -- (physicalDevice, format, type, tiling, usage, flags, externalHandleType, pExternalImageFormatProperties, return)
	vkGetMemoryWin32HandleNV = {2, 'self.parent.real', 'self.real'}, -- (device, memory, handleType, pHandle, return)
	vkCmdDrawIndirectCountAMD = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, buffer, offset, countBuffer, countBufferOffset, maxDrawCount, stride)
	vkCmdDrawIndexedIndirectCountAMD = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, buffer, offset, countBuffer, countBufferOffset, maxDrawCount, stride)
	vkCmdProcessCommandsNVX = {1, 'self.real'}, -- (commandBuffer, pProcessCommandsInfo)
	vkCmdReserveSpaceForCommandsNVX = {1, 'self.real'}, -- (commandBuffer, pReserveSpaceInfo)
	vkCreateIndirectCommandsLayoutNVX = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pIndirectCommandsLayout, return)
	vkDestroyIndirectCommandsLayoutNVX = {2, 'self.parent.real', 'self.real'}, -- (device, indirectCommandsLayout, pAllocator)
	vkCreateObjectTableNVX = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pObjectTable, return)
	vkDestroyObjectTableNVX = {2, 'self.parent.real', 'self.real'}, -- (device, objectTable, pAllocator)
	vkRegisterObjectsNVX = {2, 'self.parent.real', 'self.real'}, -- (device, objectTable, objectCount, ppObjectTableEntries, pObjectIndices, return)
	vkUnregisterObjectsNVX = {2, 'self.parent.real', 'self.real'}, -- (device, objectTable, objectCount, pObjectEntryTypes, pObjectIndices, return)
	vkGetPhysicalDeviceGeneratedCommandsPropertiesNVX = {1, 'self.real'}, -- (physicalDevice, pFeatures, pLimits)
	vkGetPhysicalDeviceFeatures2 = {1, 'self.real'}, -- (physicalDevice, pFeatures)
	vkGetPhysicalDeviceProperties2 = {1, 'self.real'}, -- (physicalDevice, pProperties)
	vkGetPhysicalDeviceFormatProperties2 = {1, 'self.real'}, -- (physicalDevice, format, pFormatProperties)
	vkGetPhysicalDeviceImageFormatProperties2 = {1, 'self.real'}, -- (physicalDevice, pImageFormatInfo, pImageFormatProperties, return)
	vkGetPhysicalDeviceQueueFamilyProperties2 = {1, 'self.real'}, -- (physicalDevice, pQueueFamilyPropertyCount, pQueueFamilyProperties)
	vkGetPhysicalDeviceMemoryProperties2 = {1, 'self.real'}, -- (physicalDevice, pMemoryProperties)
	vkGetPhysicalDeviceSparseImageFormatProperties2 = {1, 'self.real'}, -- (physicalDevice, pFormatInfo, pPropertyCount, pProperties)
	vkCmdPushDescriptorSetKHR = {1, 'self.real'}, -- (commandBuffer, pipelineBindPoint, layout, set, descriptorWriteCount, pDescriptorWrites)
	vkTrimCommandPool = {2, 'self.parent.real', 'self.real'}, -- (device, commandPool, flags)
	vkGetPhysicalDeviceExternalBufferProperties = {1, 'self.real'}, -- (physicalDevice, pExternalBufferInfo, pExternalBufferProperties)
	vkGetMemoryWin32HandleKHR = {1, 'self.real'}, -- (device, pGetWin32HandleInfo, pHandle, return)
	vkGetMemoryWin32HandlePropertiesKHR = {1, 'self.real'}, -- (device, handleType, handle, pMemoryWin32HandleProperties, return)
	vkGetMemoryFdKHR = {1, 'self.real'}, -- (device, pGetFdInfo, pFd, return)
	vkGetMemoryFdPropertiesKHR = {1, 'self.real'}, -- (device, handleType, fd, pMemoryFdProperties, return)
	vkGetPhysicalDeviceExternalSemaphoreProperties = {1, 'self.real'}, -- (physicalDevice, pExternalSemaphoreInfo, pExternalSemaphoreProperties)
	vkGetSemaphoreWin32HandleKHR = {1, 'self.real'}, -- (device, pGetWin32HandleInfo, pHandle, return)
	vkImportSemaphoreWin32HandleKHR = {1, 'self.real'}, -- (device, pImportSemaphoreWin32HandleInfo, return)
	vkGetSemaphoreFdKHR = {1, 'self.real'}, -- (device, pGetFdInfo, pFd, return)
	vkImportSemaphoreFdKHR = {1, 'self.real'}, -- (device, pImportSemaphoreFdInfo, return)
	vkGetPhysicalDeviceExternalFenceProperties = {1, 'self.real'}, -- (physicalDevice, pExternalFenceInfo, pExternalFenceProperties)
	vkGetFenceWin32HandleKHR = {1, 'self.real'}, -- (device, pGetWin32HandleInfo, pHandle, return)
	vkImportFenceWin32HandleKHR = {1, 'self.real'}, -- (device, pImportFenceWin32HandleInfo, return)
	vkGetFenceFdKHR = {1, 'self.real'}, -- (device, pGetFdInfo, pFd, return)
	vkImportFenceFdKHR = {1, 'self.real'}, -- (device, pImportFenceFdInfo, return)
	vkReleaseDisplayEXT = {2, 'self.parent.real', 'self.real'}, -- (physicalDevice, display, return)
	vkAcquireXlibDisplayEXT = {1, 'self.real'}, -- (physicalDevice, dpy, display, return)
	vkGetRandROutputDisplayEXT = {1, 'self.real'}, -- (physicalDevice, dpy, rrOutput, pDisplay, return)
	vkDisplayPowerControlEXT = {2, 'self.parent.real', 'self.real'}, -- (device, display, pDisplayPowerInfo, return)
	vkRegisterDeviceEventEXT = {1, 'self.real'}, -- (device, pDeviceEventInfo, pAllocator, pFence, return)
	vkRegisterDisplayEventEXT = {2, 'self.parent.real', 'self.real'}, -- (device, display, pDisplayEventInfo, pAllocator, pFence, return)
	vkGetSwapchainCounterEXT = {2, 'self.parent.real', 'self.real'}, -- (device, swapchain, counter, pCounterValue, return)
	vkGetPhysicalDeviceSurfaceCapabilities2EXT = {2, 'self.parent.real', 'self.real'}, -- (physicalDevice, surface, pSurfaceCapabilities, return)
	vkEnumeratePhysicalDeviceGroups = {1, 'self.real'}, -- (instance, pPhysicalDeviceGroupCount, pPhysicalDeviceGroupProperties, return)
	vkGetDeviceGroupPeerMemoryFeatures = {1, 'self.real'}, -- (device, heapIndex, localDeviceIndex, remoteDeviceIndex, pPeerMemoryFeatures)
	vkBindBufferMemory2 = {1, 'self.real'}, -- (device, bindInfoCount, pBindInfos, return)
	vkBindImageMemory2 = {1, 'self.real'}, -- (device, bindInfoCount, pBindInfos, return)
	vkCmdSetDeviceMask = {1, 'self.real'}, -- (commandBuffer, deviceMask)
	vkGetDeviceGroupPresentCapabilitiesKHR = {1, 'self.real'}, -- (device, pDeviceGroupPresentCapabilities, return)
	vkGetDeviceGroupSurfacePresentModesKHR = {2, 'self.parent.real', 'self.real'}, -- (device, surface, pModes, return)
	vkAcquireNextImage2KHR = {1, 'self.real'}, -- (device, pAcquireInfo, pImageIndex, return)
	vkCmdDispatchBase = {1, 'self.real'}, -- (commandBuffer, baseGroupX, baseGroupY, baseGroupZ, groupCountX, groupCountY, groupCountZ)
	vkGetPhysicalDevicePresentRectanglesKHR = {2, 'self.parent.real', 'self.real'}, -- (physicalDevice, surface, pRectCount, pRects, return)
	vkCreateDescriptorUpdateTemplate = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pDescriptorUpdateTemplate, return)
	vkDestroyDescriptorUpdateTemplate = {2, 'self.parent.real', 'self.real'}, -- (device, descriptorUpdateTemplate, pAllocator)
	vkUpdateDescriptorSetWithTemplate = {2, 'self.parent.real', 'self.real'}, -- (device, descriptorSet, descriptorUpdateTemplate, pData)
	vkCmdPushDescriptorSetWithTemplateKHR = {2, 'self.parent.real', 'self.real'}, -- (commandBuffer, descriptorUpdateTemplate, layout, set, pData)
	vkSetHdrMetadataEXT = {1, 'self.real'}, -- (device, swapchainCount, pSwapchains, pMetadata)
	vkGetSwapchainStatusKHR = {2, 'self.parent.real', 'self.real'}, -- (device, swapchain, return)
	vkGetRefreshCycleDurationGOOGLE = {2, 'self.parent.real', 'self.real'}, -- (device, swapchain, pDisplayTimingProperties, return)
	vkGetPastPresentationTimingGOOGLE = {2, 'self.parent.real', 'self.real'}, -- (device, swapchain, pPresentationTimingCount, pPresentationTimings, return)
	vkCreateIOSSurfaceMVK = {1, 'self.real'}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkCreateMacOSSurfaceMVK = {1, 'self.real'}, -- (instance, pCreateInfo, pAllocator, pSurface, return)
	vkCmdSetViewportWScalingNV = {1, 'self.real'}, -- (commandBuffer, firstViewport, viewportCount, pViewportWScalings)
	vkCmdSetDiscardRectangleEXT = {1, 'self.real'}, -- (commandBuffer, firstDiscardRectangle, discardRectangleCount, pDiscardRectangles)
	vkCmdSetSampleLocationsEXT = {1, 'self.real'}, -- (commandBuffer, pSampleLocationsInfo)
	vkGetPhysicalDeviceMultisamplePropertiesEXT = {1, 'self.real'}, -- (physicalDevice, samples, pMultisampleProperties)
	vkGetPhysicalDeviceSurfaceCapabilities2KHR = {1, 'self.real'}, -- (physicalDevice, pSurfaceInfo, pSurfaceCapabilities, return)
	vkGetPhysicalDeviceSurfaceFormats2KHR = {1, 'self.real'}, -- (physicalDevice, pSurfaceInfo, pSurfaceFormatCount, pSurfaceFormats, return)
	vkGetBufferMemoryRequirements2 = {1, 'self.real'}, -- (device, pInfo, pMemoryRequirements)
	vkGetImageMemoryRequirements2 = {1, 'self.real'}, -- (device, pInfo, pMemoryRequirements)
	vkGetImageSparseMemoryRequirements2 = {1, 'self.real'}, -- (device, pInfo, pSparseMemoryRequirementCount, pSparseMemoryRequirements)
	vkCreateSamplerYcbcrConversion = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pYcbcrConversion, return)
	vkDestroySamplerYcbcrConversion = {2, 'self.parent.real', 'self.real'}, -- (device, ycbcrConversion, pAllocator)
	vkGetDeviceQueue2 = {1, 'self.real'}, -- (device, pQueueInfo, pQueue)
	vkCreateValidationCacheEXT = {1, 'self.real'}, -- (device, pCreateInfo, pAllocator, pValidationCache, return)
	vkDestroyValidationCacheEXT = {2, 'self.parent.real', 'self.real'}, -- (device, validationCache, pAllocator)
	vkGetValidationCacheDataEXT = {2, 'self.parent.real', 'self.real'}, -- (device, validationCache, pDataSize, pData, return)
	vkMergeValidationCachesEXT = {2, 'self.parent.real', 'self.real'}, -- (device, dstCache, srcCacheCount, pSrcCaches, return)
	vkGetDescriptorSetLayoutSupport = {1, 'self.real'}, -- (device, pCreateInfo, pSupport)
	vkGetSwapchainGrallocUsageANDROID = {1, 'self.real'}, -- (device, format, imageUsage, grallocUsage, return)
	vkAcquireImageANDROID = {2, 'self.parent.real', 'self.real'}, -- (device, image, nativeFenceFd, semaphore, fence, return)
	vkQueueSignalReleaseImageANDROID = {1, 'self.real'}, -- (queue, waitSemaphoreCount, pWaitSemaphores, image, pNativeFenceFd, return)
	vkGetShaderInfoAMD = {2, 'self.parent.real', 'self.real'}, -- (device, pipeline, shaderStage, infoType, pInfoSize, pInfo, return)
	vkSetDebugUtilsObjectNameEXT = {1, 'self.real'}, -- (device, pNameInfo, return)
	vkSetDebugUtilsObjectTagEXT = {1, 'self.real'}, -- (device, pTagInfo, return)
	vkQueueBeginDebugUtilsLabelEXT = {1, 'self.real'}, -- (queue, pLabelInfo)
	vkQueueEndDebugUtilsLabelEXT = {1, 'self.real'}, -- (queue)
	vkQueueInsertDebugUtilsLabelEXT = {1, 'self.real'}, -- (queue, pLabelInfo)
	vkCmdBeginDebugUtilsLabelEXT = {1, 'self.real'}, -- (commandBuffer, pLabelInfo)
	vkCmdEndDebugUtilsLabelEXT = {1, 'self.real'}, -- (commandBuffer)
	vkCmdInsertDebugUtilsLabelEXT = {1, 'self.real'}, -- (commandBuffer, pLabelInfo)
	vkCreateDebugUtilsMessengerEXT = {1, 'self.real'}, -- (instance, pCreateInfo, pAllocator, pMessenger, return)
	vkDestroyDebugUtilsMessengerEXT = {2, 'self.parent.real', 'self.real'}, -- (instance, messenger, pAllocator)
	vkSubmitDebugUtilsMessageEXT = {1, 'self.real'}, -- (instance, messageSeverity, messageTypes, pCallbackData)
	vkGetMemoryHostPointerPropertiesEXT = {1, 'self.real'}, -- (device, handleType, pHostPointer, pMemoryHostPointerProperties, return)
	vkCmdWriteBufferMarkerAMD = {1, 'self.real'}, -- (commandBuffer, pipelineStage, dstBuffer, dstOffset, marker)
	vkGetAndroidHardwareBufferPropertiesANDROID = {1, 'self.real'}, -- (device, buffer, pProperties, return)
	vkGetMemoryAndroidHardwareBufferANDROID = {1, 'self.real'}, -- (device, pInfo, pBuffer, return)
}

-- Handles are connected by a parenting scheme, but it doesn't always work right...
human.parent = {
	VkInstance = false,	-- Parent is Vk
	VkDisplayKHR = 'PhysicalDevice',
	VkDisplayModeKHR = 'DisplayKHR',
}

-- Commands in Vulkan are not associated with any particular handle, but most
-- only make sense within the context of one, so we make the association ourselves.
-- `entries` is the raw argument list to work with
-- `name` is the name of the command in question.
local function ishandle(t)
	return not t.__index and not t.__mask and not t.__enum and t.__raw and t.__raw:match '^Vk'
end
function human.self(entries, name)
	local s = selves[name]
	if not s then
		local guess = "true"
		if entries[2] and ishandle(entries[2].type) then
			guess = "{2, 'self.parent.real', 'self.real'}"
		elseif entries[1] and ishandle(entries[1].type) then
			guess = "{1, 'self.real'}"
		end
		local names = {}
		for _,e in ipairs(entries) do names[#names+1] = e.name end
		return human.herror('\t'..name..' = '..guess..', -- ('..table.concat(names,', ')..')')
	elseif s ~= true then return entries[s[1]].type, table.unpack(s, 2) end
end

return human
