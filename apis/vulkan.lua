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

-- Load up the Vulkan registry data
local Vk = dofile '../external/vulkan.lua'
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
						'0.0.0',
						{name='real', type={__raw=n, __name='internal '..n}, readonly=true},
					},
				}
				-- This isn't correct, but there's only one case so...
				if t.parent then for p in t.parent:gmatch '[^,]+' do
					local pn = p:match 'Vk(.+)'
					table.insert(vk[vn].__index,
						{name=pn:gsub('^.', string.lower), type=vk[pn], readonly=true})
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
	VkAndroidSurfaceCreateFlagsKHR = 0,
	VkAttachmentDescriptionFlags = {'VK_ATTACHMENT_DESCRIPTION_', '_BIT'},
	VkBufferViewCreateFlagBits = 0,
	VkBufferViewCreateFlags = 0,
	VkCommandBufferResetFlags = {'VK_COMMAND_BUFFER_RESET_', '_BIT'},
	VkCommandPoolResetFlags = {'VK_COMMAND_POOL_RESET_', '_BIT'},
	VkCommandPoolTrimFlagsKHR = 0,
	VkDescriptorPoolCreateFlags = {'VK_DESCRIPTOR_POOL_CREATE_', '_BIT'},
	VkDescriptorPoolResetFlags = 0,
	VkDescriptorSetLayoutCreateFlags = {'VK_DESCRIPTOR_SET_LAYOUT_CREATE_', '_BIT'},
	VkDescriptorUpdateTemplateCreateFlagsKHR = 0,
	VkDeviceCreateFlagBits = 0,
	VkDeviceCreateFlags = 0,
	VkDeviceEventTypeEXT = {'VK_DEVICE_EVENT_TYPE_', ''},
	VkDeviceQueueCreateFlagBits = 0,
	VkDeviceQueueCreateFlags = 0,
	VkDisplayEventTypeEXT = {'VK_DISPLAY_EVENT_TYPE_', ''},
	VkDisplayModeCreateFlagsKHR = 0,
	VkDisplaySurfaceCreateFlagsKHR = 0,
	VkEventCreateFlags = 0,
	VkFenceCreateFlags = {'VK_FENCE_CREATE_', '_BIT'},
	VkFenceImportFlagsKHR = {'VK_FENCE_IMPORT_', '_BIT'},
	VkFramebufferCreateFlagBits = 0,
	VkFramebufferCreateFlags = 0,
	VkImageViewCreateFlags = 0,
	VkInstanceCreateFlagBits = 0,
	VkInstanceCreateFlags = 0,
	VkInternalAllocationType = {'VK_INTERNAL_ALLOCATION_TYPE_', ''},
	VkIOSSurfaceCreateFlagsMVK = 0,
	VkMacOSSurfaceCreateFlagsMVK = 0,
	VkMemoryAllocateFlagsKHX = {'VK_MEMORY_ALLOCATE_', '_BIT'},
	VkMemoryMapFlags = 0,
	VkMirSurfaceCreateFlagsKHR = 0,
	VkPipelineCacheCreateFlagBits = 0,
	VkPipelineCacheCreateFlags = 0,
	VkPipelineCacheHeaderVersion = {'VK_PIPELINE_CACHE_HEADER_VERSION_', ''},
	VkPipelineColorBlendStateCreateFlagBits = 0,
	VkPipelineColorBlendStateCreateFlags = 0,
	VkPipelineCoverageModulationStateCreateFlagsNV = 0,
	VkPipelineCoverageToColorStateCreateFlagsNV = 0,
	VkPipelineDepthStencilStateCreateFlagBits = 0,
	VkPipelineDepthStencilStateCreateFlags = 0,
	VkPipelineDiscardRectangleStateCreateFlagsEXT = 0,
	VkPipelineDynamicStateCreateFlagBits = 0,
	VkPipelineDynamicStateCreateFlags = 0,
	VkPipelineInputAssemblyStateCreateFlagBits = 0,
	VkPipelineInputAssemblyStateCreateFlags = 0,
	VkPipelineLayoutCreateFlagBits = 0,
	VkPipelineLayoutCreateFlags = 0,
	VkPipelineMultisampleStateCreateFlagBits = 0,
	VkPipelineMultisampleStateCreateFlags = 0,
	VkPipelineRasterizationStateCreateFlagBits = 0,
	VkPipelineRasterizationStateCreateFlags = 0,
	VkPipelineShaderStageCreateFlagBits = 0,
	VkPipelineShaderStageCreateFlags = 0,
	VkPipelineTessellationStateCreateFlagBits = 0,
	VkPipelineTessellationStateCreateFlags = 0,
	VkPipelineVertexInputStateCreateFlagBits = 0,
	VkPipelineVertexInputStateCreateFlags = 0,
	VkPipelineViewportStateCreateFlagBits = 0,
	VkPipelineViewportStateCreateFlags = 0,
	VkPipelineViewportSwizzleStateCreateFlagsNV = 0,
	VkQueryControlFlags = {'VK_QUERY_CONTROL_', '_BIT'},
	VkQueryPoolCreateFlagBits = 0,
	VkQueryPoolCreateFlags = 0,
	VkRenderPassCreateFlagBits = 0,
	VkRenderPassCreateFlags = 0,
	VkSamplerCreateFlagBits = 0,
	VkSamplerCreateFlags = 0,
	VkSemaphoreCreateFlags = 0,
	VkSemaphoreImportFlagsKHR = {'VK_SEMAPHORE_IMPORT_', '_BIT'},
	VkShaderModuleCreateFlags = 0,
	VkSparseMemoryBindFlags = {'VK_SPARSE_MEMORY_BIND_', '_BIT'},
	VkSurfaceCounterFlagsEXT = {'VK_SURFACE_COUNTER_', ''},
	VkSwapchainCreateFlagsKHR = {'VK_SWAPCHAIN_CREATE_', '_BIT'},
	VkValidationCacheCreateFlagsEXT = 0,
	VkValidationCacheHeaderVersionEXT = {'VK_VALIDATION_CACHE_HEADER_VERSION_', ''},
	VkViSurfaceCreateFlagsNN = 0,
	VkWaylandSurfaceCreateFlagsKHR = 0,
	VkWin32SurfaceCreateFlagsKHR = 0,
	VkXcbSurfaceCreateFlagsKHR = 0,
	VkXlibSurfaceCreateFlagsKHR = 0,
}

local required = {}
for _,t in pairs(Vk.types) do
	if t.requires then required[t.requires] = true end
end

for n,t in pairs(Vk.types) do
	if not required[n] and (t.category == 'enum' or t.category == 'bitmask') then
		local vn = n:match 'Vk(.+)'
		vk[vn] = {__raw=n, __name=n}

		local vals,rvals = {},{}
		for rn in pairs(t.values) do
			table.insert(rvals, rn)
			for v in pairs(Vk.vids) do rn = rn:gsub('_'..v..'$', '') end
			table.insert(vals, (rn:gsub('_BIT$', '')))
		end

		local pre
		if #vals <= 1 then
			local ef = enumfixes[n]
			if ef then
				if #vals == 0 then
					assert(ef == 0, "Outdated 'fixes override for "..n..", has no examples!")
					pre = ''
				else
					assert(ef ~= 0, "Outdated 'fixes override for "..n..", now has an example!")
					pre = ef[1]
					assert(pre, "'fixes override for "..n.." is missing a 'fix!")
					for _,v in ipairs(vals) do
						assert(v:match('^'..pre),
							"Outdated 'fixes override for "..n..", prefix does not match! ("..v.." ~= "..pre..")")
					end
				end
			else
				if #vals == 0 then error("No examples for "..n)
				else error("One example for "..n.." ("..vals[1]..")") end
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
	__format = 'VK_MAKE_VERSION(%u,%u,%u)',
	__frommatch = '^(%d+)%.(%d+)%.(%d+)$',
	__fromtable = {'M', 'm', 'p'},
	__fromnil = {0, 0, 0},
}

return vk

--[=[

local rawtypes = {}
rawtypes.voidptr = 'lightuserdata'
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

rawtypes.vksamplemask = {__raw='VkSampleMask*'}

vktypes.vksamplemask = flexmask{
	raw{realname='VkSampleMask'},
	bits=32, lenvar='fish',
}

vktypes.PFN_vkInternalAllocationNotification = callable{
	realname = 'PFN_vkInternalAllocationNotification',
	{'udata', generic}, {'size', integer},
	{'type', Vk.InternalAllocationType}, {'scope', Vk.SystemAllocationScope},
}
vktypes.PFN_vkInternalFreeNotification = callable{
	realname = 'PFN_vkInternalFreeNotification',
	{'udata', generic}, {'size', integer},
	{'type', Vk.InternalAllocationType}, {'scope', Vk.SystemAllocationScope},
}
vktypes.PFN_vkReallocationFunction = callable{
	realname = 'PFN_vkReallocationFunction',
	{'udata', generic}, {'original', memory}, {'size', integer},
	{'alignment', integer},
	{'scope', Vk.SystemAllocationScope},
	returns = {memory},
}
vktypes.PFN_vkAllocationFunction = callable{
	realname = 'PFN_vkAllocationFunction',
	{'udata', generic}, {'size', integer}, {'alignment', integer},
	{'scope', Vk.SystemAllocationScope},
	returns = {memory},
}
vktypes.PFN_vkFreeFunction = callable{
	realname = 'PFN_vkFreeFunction',
	{'udata', generic}, {'mem', memory},
}

vktypes.PFN_vkDebugReportCallbackEXT = callable{
	realname = 'PFN_vkDebugReportCallbackEXT',
	{'flags', Vk.DebugReportFlagsEXT}, {'objectType', Vk.DebugReportObjectTypeEXT},
	{'object', index}, {'location', index}, {'mCode', integer},
	{'layerPrefix', string}, {'message', string},
	{'udata', generic},
	returns = {boolean},
}

for n in pairs{
	Display=true, VisualID=true, Window=true,	-- Xlib.h
	RROutput=true,	-- Xrandr.h
	ANativeWindow=true,	--android/native_window.h
	MirConnection=true, MirSurface=true,	-- mir_toolkit/client_types.h
	wl_display=true, wl_surface=true,	-- wayland-client.h
	HANDLE=true, LPCWSTR=true, DWORD=true, SECURITY_ATTRIBUTES=true,
	HINSTANCE=true, HWND=true, -- windows.h
	xcb_connection_t=true, xcb_visualid_t=true, xcb_window_t=true,	-- xcb.h
} do vktypes[n] = raw{realname=n} end

do
	local ex = {
		VkShaderModuleCreateInfo_pCode = {name='pCode', type='string', len='codeSize'},
		VkPipelineMultisampleStateCreateInfo_pSampleMask = {name='pSampleMask',
			type='vksamplemask', len='rasterizationSamples'}
	}

	local structs = {}
	for n,t in pairs(vk.types) do
		if t.category == 'struct' or t.category == 'union' then
			structs[n] = t

			local mems = {}
			for i,m in ipairs(t.members) do
				m = ex[n..'_'..m.name] or m
				t.members[i] = m
				if m.type == 'char' then
					m.type = 'string'
					m.arr = m.arr - 1
					if m.len then
						m.len = m.len:gsub(',?null%-terminated$', '')
						if #m.len == 0 then m.len = nil end
					end
				elseif m.type == 'void' then
					m.arr = m.arr - 1
				elseif (m.arr or 0) > 0 and not m.len then
					m.arr = m.arr - 1
				end
				if m.values and not m.values:find',' then m.def = m.values
				elseif m.optional == 'true' then m.def = '' end
				m.i = i
				mems[m.name] = m
			end

			local rmed = {}
			for _,m in pairs(mems) do
				if m.len then
					if mems[m.len] then
						t.members[mems[m.len].i] = false
						mems[m.len],rmed[m.len] = nil,true
					elseif not rmed[m.len] then
						print('>', n)
						for mn in pairs(mems) do print('>>', mn) end
						print('>>>', m.name, m.len, m.type)
						error('Odd len: '..m.len)
					end
				end
			end

			local i = 1
			while t.members[i] ~= nil do
				if not t.members[i] then table.remove(t.members, i)
				else i = i + 1 end
			end
		end
	end

	repeat
		local stuck = true
		local missing = {}
		for n,t in pairs(structs) do
			local mems = {realname=n}
			for _,m in ipairs(t.members) do
				if not vktypes[m.type] then missing[m.type] = true goto skip end
			end

			local pn = n:match'Vk(.*)'
			for _,m in ipairs(t.members) do
				if (m.arr or 0) > 0 then
					assert(m.arr == 1)
					table.insert(mems, {m.name,
						array{vktypes[m.type], lenvar=m.len}, {}})
				else
					table.insert(mems, {m.name, vktypes[m.type],
						m.def ~= '' and m.def or nil})
				end
			end

			vktypes.Vk.type[pn] = compound(mems)
			vktypes[n] = Vk[pn]
			structs[n] = nil
			stuck = false
			::skip::
		end
		if stuck then
			for n in pairs(structs) do print('>>', n) end
			for t in pairs(missing) do print('>', t) end
			error("Got stuck writing the structs")
		end
	until not next(structs)
end

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
