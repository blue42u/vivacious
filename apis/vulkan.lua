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

-- luacheck: globals array method callable versioned
require 'core.common'

-- Load up the Vulkan registry data
local Vk = require 'external.vulkan'
local vk = {__index={}}

vk.Vk = {__name = 'Vk',
	__doc = [[
		Loader for the Vulkan loader, and manager of the Vulkan-vV object
	]],
	__directives = {'define VK_NO_PROTOTYPES', 'include <vulkan/vulkan.h>'},
	__index = {},
}
table.insert(vk.__index, {name='createVk', version='0.0.0',
	type={__call={method=true,
		{name='return', type=vk.Vk, canbenil=true},
		{name='return', type='string', canbenil=true},
	}},
})

do
	local handles = {}
	for n,t in pairs(Vk.types) do
		if t.category == 'handle' then handles[n] = t end
	end

	repeat
		local stuck = true
		for n,t in pairs(handles) do
			local go = true
			if t.parent then for p in t.parent:gmatch('[^,]+') do
				if not vk[p:match 'Vk(.+)'] then
					go = false
					break
				end
			end end
			if go then
				local vn = n:match'Vk(.*)'
				vk[vn] = {__name=n,
					__index = {
						{name='real', version='0.0.0',
							type={__raw=n, __name='lightuserdata/'..n}, readonly=true},
					},
				}
				-- This isn't correct, but there's only one case so...
				if t.parent then for p in t.parent:gmatch '[^,]+' do
					local pn = p:match 'Vk(.+)'
					table.insert(vk[vn].__index,
						{name=pn:gsub('^.', string.lower), type=vk[pn], readonly=true, version='0.0.0'})
				end end
				handles[n] = nil
				stuck = false
			end
		end
		if stuck then
			for n,t in pairs(handles) do print('>>', n, t.parent) end
			error("Got stuck converting the handles!")
		end
	until not next(handles)
end

local enumfixes = {
	VkAndroidSurfaceCreateFlagBitsKHR = 0,
	VkAttachmentDescriptionFlagBits = {'VK_ATTACHMENT_DESCRIPTION_', '_BIT'},
	VkBufferViewCreateFlagBits = 0,
	VkCommandBufferResetFlagBits = {'VK_COMMAND_BUFFER_RESET_', '_BIT'},
	VkCommandPoolResetFlagBits = {'VK_COMMAND_POOL_RESET_', '_BIT'},
	VkCommandPoolTrimFlagBitsKHR = 0,
	VkDescriptorPoolCreateFlagBits = {'VK_DESCRIPTOR_POOL_CREATE_', '_BIT'},
	VkDescriptorPoolResetFlagBits = 0,
	VkDescriptorSetLayoutCreateFlagBits = {'VK_DESCRIPTOR_SET_LAYOUT_CREATE_', '_BIT'},
	VkDescriptorUpdateTemplateCreateFlagBitsKHR = 0,
	VkDeviceCreateFlagBits = 0,
	VkDeviceEventTypeEXT = {'VK_DEVICE_EVENT_TYPE_', ''},
	VkDeviceQueueCreateFlagBits = 0,
	VkDisplayEventTypeEXT = {'VK_DISPLAY_EVENT_TYPE_', ''},
	VkDisplayModeCreateFlagBitsKHR = 0,
	VkDisplaySurfaceCreateFlagBitsKHR = 0,
	VkEventCreateFlagBits = 0,
	VkFenceCreateFlagBits = {'VK_FENCE_CREATE_', '_BIT'},
	VkFenceImportFlagBitsKHR = {'VK_FENCE_IMPORT_', '_BIT'},
	VkFramebufferCreateFlagBits = 0,
	VkImageViewCreateFlagBits = 0,
	VkInstanceCreateFlagBits = 0,
	VkInternalAllocationType = {'VK_INTERNAL_ALLOCATION_TYPE_', ''},
	VkIOSSurfaceCreateFlagBitsMVK = 0,
	VkMacOSSurfaceCreateFlagBitsMVK = 0,
	VkMemoryAllocateFlagBitsKHX = {'VK_MEMORY_ALLOCATE_', '_BIT'},
	VkMemoryMapFlagBits = 0,
	VkMirSurfaceCreateFlagBitsKHR = 0,
	VkPipelineCacheCreateFlagBits = 0,
	VkPipelineCacheHeaderVersion = {'VK_PIPELINE_CACHE_HEADER_VERSION_', ''},
	VkPipelineColorBlendStateCreateFlagBits = 0,
	VkPipelineCoverageModulationStateCreateFlagBitsNV = 0,
	VkPipelineCoverageToColorStateCreateFlagBitsNV = 0,
	VkPipelineDepthStencilStateCreateFlagBits = 0,
	VkPipelineDiscardRectangleStateCreateFlagBitsEXT = 0,
	VkPipelineDynamicStateCreateFlagBits = 0,
	VkPipelineInputAssemblyStateCreateFlagBits = 0,
	VkPipelineLayoutCreateFlagBits = 0,
	VkPipelineMultisampleStateCreateFlagBits = 0,
	VkPipelineRasterizationStateCreateFlagBits = 0,
	VkPipelineShaderStageCreateFlagBits = 0,
	VkPipelineTessellationStateCreateFlagBits = 0,
	VkPipelineVertexInputStateCreateFlagBits = 0,
	VkPipelineViewportStateCreateFlagBits = 0,
	VkPipelineViewportSwizzleStateCreateFlagBitsNV = 0,
	VkQueryControlFlagBits = {'VK_QUERY_CONTROL_', '_BIT'},
	VkQueryPoolCreateFlagBits = 0,
	VkRenderPassCreateFlagBits = 0,
	VkSamplerCreateFlagBits = 0,
	VkSemaphoreCreateFlagBits = 0,
	VkSemaphoreImportFlagBitsKHR = {'VK_SEMAPHORE_IMPORT_', '_BIT'},
	VkShaderModuleCreateFlagBits = 0,
	VkSparseMemoryBindFlagBits = {'VK_SPARSE_MEMORY_BIND_', '_BIT'},
	VkSurfaceCounterFlagBitsEXT = {'VK_SURFACE_COUNTER_', ''},
	VkSwapchainCreateFlagBitsKHR = {'VK_SWAPCHAIN_CREATE_', '_BIT'},
	VkValidationCacheCreateFlagBitsEXT = 0,
	VkValidationCacheHeaderVersionEXT = {'VK_VALIDATION_CACHE_HEADER_VERSION_', ''},
	VkViSurfaceCreateFlagBitsNN = 0,
	VkWaylandSurfaceCreateFlagBitsKHR = 0,
	VkWin32SurfaceCreateFlagBitsKHR = 0,
	VkXcbSurfaceCreateFlagBitsKHR = 0,
	VkXlibSurfaceCreateFlagBitsKHR = 0,
}

for n,t in pairs(Vk.types) do
	if t.category == 'enum' or t.category == 'bitmask' then
		local vn = n:match 'Vk(.+)'
		vk[vn] = {__raw=n, __name=n}

		local vals,rvals = {},{}
		for rn in pairs(t.values) do
			table.insert(rvals, rn)
			for v in pairs(Vk.vids) do rn = rn:gsub('_'..v..'$', '') end
			table.insert(vals, (rn:gsub('_BIT$', '')))
		end

		if t.category == 'bitmask' and not t.requires then
			t.requires = n:gsub('Flags', 'FlagBits')
		end

		local pre
		if #vals <= 1 then
			local ef = enumfixes[n] or enumfixes[t.requires]
			local fn = n
			if t.requires then fn = fn..'('..t.requires..')' end
			if ef then
				if #vals == 0 then
					assert(ef == 0, "Outdated 'fixes override for "..fn..", has no examples!")
					pre = ''
				else
					assert(ef ~= 0, "Outdated 'fixes override for "..fn..", now has an example!")
					pre = ef[1]
					assert(pre, "'fixes override for "..n.." is missing a 'fix!")
					for _,v in ipairs(vals) do
						assert(v:match('^'..pre),
							"Outdated 'fixes override for "..n..", prefix does not match! ("..v.." ~= "..pre..")")
					end
				end
			else
				if #vals == 0 then error("No examples for "..fn)
				else error("One example for "..fn.." ("..vals[1]..")") end
			end
		else
			-- Find the max-length val
			local mlen = 0
			for _,v in ipairs(vals) do mlen = math.max(mlen, #v) end

			-- Find the largest common prefix
			for i=mlen,0,-1 do
				pre = vals[1]:sub(1,i)
				if pre:match '_$' then
					for _,v in ipairs(vals) do if not v:match('^'..pre) then
						pre = nil
						break
					end end
					if pre then break end
				else pre = nil end
			end

			pre = pre or ''
		end

		-- Replace the entries with the proper settings
		for i,v in ipairs(vals) do
			local en = v:match('^'..pre..'(.+)$')
			assert(en, "Bad 'fixes: "..pre.." for "..v)
			en = en:lower():gsub('^%a', string.upper):gsub('%A%a', string.upper):gsub('_', '')
			vals[i] = {name=en, raw=rvals[i]}
		end

		if t.category == 'enum' then
			vk[vn].__enum = vals
		else
			vk[vn].__mask = vals
			for _,e in ipairs(vals) do
				e.flag = e.name:gsub('%l', ''):lower():gsub('^.', string.upper)
			end
		end
	end
end

vk.version = {
	__name = "'M.m.p'",
	__raw = 'uint32_t',
--	__format = 'VK_MAKE_VERSION(%u,%u,%u)',
--	__frommatch = '^(%d+)%.(%d+)%.(%d+)$',
--	__fromtable = {'M', 'm', 'p'},
--	__fromnil = {0, 0, 0},
}

local rawtypes = {}
rawtypes.void = 'lightuserdata'
rawtypes.VkBool32 = 'boolean'

rawtypes.uint64_t = 'integer'
rawtypes.uint32_t = 'integer'
rawtypes.uint8_t = 'integer'
rawtypes.int = 'integer'
rawtypes.int32_t = 'integer'
rawtypes.float = 'number'
rawtypes.size_t = 'integer'
rawtypes.VkDeviceSize = 'integer'

rawtypes.string = 'string'

rawtypes.vksamplemask = {__raw='VkSampleMask*', __name='VkSampleMask'}

rawtypes.PFN_vkInternalAllocationNotification = {
	__raw = 'PFN_vkInternalAllocationNotification',
	__call={
		{name='size', type='integer'},
		{name='type', type=vk.InternalAllocationType},
		{name='scope', type=vk.SystemAllocationScope}
	}}
rawtypes.PFN_vkInternalFreeNotification = {
	__raw = 'PFN_vkInternalFreeNotification',
	__call = {
		{name='size', type='integer'},
		{name='type', type=vk.InternalAllocationType},
		{name='scope', type=vk.SystemAllocationScope}
	}}
rawtypes.PFN_vkReallocationFunction = {
	__raw = 'PFN_vkReallocationFunction',
	__call = {
		{name='return', type='lightuserdata'},
		{name='original', type='lightuserdata'},
		{name='size', type='integer'},
		{name='alignment', type='integer'},
		{name='scope', type=vk.SystemAllocationScope}
	}}
rawtypes.PFN_vkAllocationFunction = {
	__raw = 'PFN_vkAllocationFunction',
	__call = {
		{name='return', type='lightuserdata'},
		{name='size', type='integer'},
		{name='alignment', type='integer'},
		{name='allocationScope', type=vk.SystemAllocationScope},
	}}
rawtypes.PFN_vkFreeFunction = {
	__raw = 'PFN_vkFreeFunction',
	__call = {
		{name='mem', type='lightuserdata'}
	}}

rawtypes.PFN_vkDebugReportCallbackEXT = {
	__raw = 'PFN_vkDebugReportCallbackEXT',
	__udataatend = true,	-- For the Lua binding. This is annoying.
	__call = {
		{name='return', type=rawtypes.VkBool32},
		{name='flags', type=vk.DebugReportFlagsEXT},
		{name='objectType', type=vk.DebugReportObjectTypeEXT},
		{name='object', type=rawtypes.uint64_t},
		{name='location', type='index'},
		{name='mCode', type='integer'},
		{name='layerPrefix', type='string'},
		{name='message', type='string'}
	}}

for n in pairs{
	Display=true, VisualID=true, Window=true,	-- Xlib.h
	RROutput=true,	-- Xrandr.h
	ANativeWindow=true,	--android/native_window.h
	MirConnection=true, MirSurface=true,	-- mir_toolkit/client_types.h
	wl_display=true, wl_surface=true,	-- wayland-client.h
	HANDLE=true, LPCWSTR=true, DWORD=true, SECURITY_ATTRIBUTES=true,
	HINSTANCE=true, HWND=true, -- windows.h
	xcb_connection_t=true, xcb_visualid_t=true, xcb_window_t=true,	-- xcb.h
} do rawtypes[n] = {__raw=n, __name='lightuserdata/'..n} end

local struct_overrides = {
	VkShaderModuleCreateInfo_pCode = {name='pCode', type='string', len='codeSize'},
	VkPipelineMultisampleStateCreateInfo_pSampleMask = {name='pSampleMask',
		type='vksamplemask', len='rasterizationSamples'}
}

do
	for n,t in pairs(Vk.types) do
		if t.category == 'struct' or t.category == 'union' then
			local vn = n:match '^Vk(.*)$'

			vk[vn] = vk[vn] or {}
			vk[vn].__name, vk[vn].__raw, vk[vn].__index = n, n, {}
			for i,m in ipairs(t.members) do
				m = struct_overrides[n..'_'..m.name] or m
				local mn = m.type:match 'Vk(.*)'
				local ty = vk[mn] or rawtypes[m.type]

				if m.type == 'void' then
					assert(m.arr == 1, 'Voids "should" only have one pointer (void*). '..m.name)
					m.arr, ty = m.arr-1, 'lightuserdata'
				elseif m.type == 'char' then
					if m.len then m.len = m.len:gsub(',?null%-terminated$', '') end
					m.arr, ty = m.arr-1, 'string'
				end

				if not ty then
					assert(mn, 'Odd type name '..m.type)
					ty = {}
					vk[mn] = ty
				end

				if ty.__name and ty.__name:match '^lightuserdata' then
					m.arr = m.arr - 1 end

				assert(ty, 'We should have gotten a type by now. '..m.name)
				assert(not m.len or not m.len:match',', 'No multi-leveled arrays should be here. '..m.name)
				assert(m.arr or 0 <= 1, 'Only one unhandled * should remain. '..m.name)
				if m.arr == 1 and m.len then ty = array(ty) end
				vk[vn].__index[i] = {name=m.name, type=ty, len=m.len, version='0.0.0'}

				if m.values and not m.values:match ',' then
					vk[vn].__index[i].doc = 'Automatically set to '..m.values..'.'
				elseif m.name == 'pNext' then
					vk[vn].__index[i].doc = 'Actually contains a sType field, and will be converted accordingly.'
				end
			end

			local usedaslen = {}
			for _,e in ipairs(vk[vn].__index) do
				if e.len then usedaslen[e.len] = true end
			end
			local i = 1
			repeat
				if usedaslen[vk[vn].__index[i].name] then table.remove(vk[vn].__index, i)
				else i = i + 1 end
			until not vk[vn].__index[i]
		end
	end
end

return vk

--[=[
do
	local voidf = callable{realname='PFN_vkVoidFunction'}
	for v,cs in pairs(vk.cmds) do
		local M,m = v:match '(%d+)%.(%d+)'
		if M then v = 'v0_'..M..'_'..m
		else v = 'v'..v..'_0_0' end
		for _,ct in ipairs(cs) do
			local b
			if ct[2] and not ct[2].optional and
				ct[1].type == vkbps[ct[2].type] then b = vkbs[ct[2].type] end
			if not b and ct[1] then b = vkbs[ct[1].type] end
			if not b then b = Vk end

			local c = {returns = raw{realname=ct.ret}, realname='PFN_'..ct.name}
			for i,a in ipairs(ct) do c[i] = {a.name, raw{realname=a.type}} end
			b[v][ct.name] = c
			if cs.extname then
				cmdconsts[ct.name] = {cs.extname, voidf}
			end
		end
	end
end
]=]
