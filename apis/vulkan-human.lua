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
			error('Attempt to get field '..k..' of '..(self._setvar or '(env)'))
		end
	end
	local val = assert(load('return ('..elem._len:gsub('::', '.')..')', nil, 't', new(parent)))()
	if type(val) == 'table' then
		if elem.canbenil then
			local k = partype.__raw..'_'..elem.name
			assert(optionallens[k] ~= nil, 'Unhandled op/len: '..k..' = nil!')
			if not optionallens[k] then return end
		end
		return val._setvar, val._setto
	end
end

return human
