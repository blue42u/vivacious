--[========================================================================[
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
--]========================================================================]

--c_define = 'VK_NO_PROTOTYPES'
--c_include = 'vulkan/vulkan.h'

-- Load up the Vulkan registry data
local vk = dofile 'external/vulkan.lua'

local parent_overrides = {
	VkInstance = 'Vk',
	VkDisplayKHR = 'VkPhysicalDevice',
	VkDisplayModeKHR = 'VkDisplayKHR',
}

Vk = {}
local vktypes = {Vk=Vk}
local vkbs = {}

do
	local handles = {}
	for n,t in pairs(vk.types) do
		if t.category == 'handle' then
			-- We don't do multi-parenting
			if t.parent and t.parent:find',' then t.parent = nil end
			t.parent = parent_overrides[n] or t.parent
			if t.parent == nil then error(n..' has no parent!') end
			handles[n] = t
		end
	end

	repeat
		local stuck = true
		for n,t in pairs(handles) do
			if vktypes[t.parent] then
				if t.type == 'VK_DEFINE_NON_DISPATCHABLE_HANDLE' then
					vktypes[t.parent][n:match'Vk(.*)'] = {wrapperfor = n}
					vktypes[n] = vktypes[t.parent][n:match'Vk(.*)']
				elseif t.type == 'VK_DEFINE_HANDLE' then
					_ENV['Vk.'..n:match'Vk(.*)'] = {vktypes[t.parent], wrapperfor = n}
					vktypes[n] = _ENV['Vk.'..n:match'Vk(.*)']
					vkbs[n] = vktypes[n]
				else error() end
				handles[n] = nil
				stuck = false
			end
		end
		if stuck then
			for n,t in pairs(handles) do print('>>', n, t.parent) end
			error()
		end
	until not next(handles)
end

for n,t in pairs(vk.types) do
	if t.category == 'enum' or t.category == 'bitmask' then
		local vals = {realname=n}
		for rn in pairs(t.values) do table.insert(vals, rn) end
		if t.category == 'enum' then
			if #vals > 0 then
				vals.default = next(t.values)
				Vk.type[n:match'Vk(.*)'] = options(vals)
				vktypes[n] = Vk[n:match'Vk(.*)']
			end
		else
			Vk.type[n:match'Vk(.*)'] = flags(vals)
			vktypes[n] = Vk[n:match'Vk(.*)']
			if t.requires and #vals > 0 then
				vals.default = next(t.values)
				Vk.type[t.requires:match'Vk(.*)'] = options(vals)
				vktypes[t.requires] = Vk[t.requires:match'Vk(.*)']
			end
		end
	end
end

vktypes.void = generic
vktypes.VkBool32 = boolean

vktypes.uint64_t = unsigned
vktypes.uint32_t = unsigned
vktypes.uint8_t = unsigned
vktypes.int = integer
vktypes.int32_t = integer
vktypes.float = number
vktypes.size_t = raw{realname='size_t', conversion='%u'}
vktypes.VkDeviceSize = raw{realname='VkDeviceSize', conversion='%u'}

vktypes.string = string

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
			local mems = {}
			for _,m in ipairs(t.members) do
				if not vktypes[m.type] then missing[m.type] = true goto skip end
			end

			local sTyped = false
			local pn = n:match'Vk(.*)'
			for _,m in ipairs(t.members) do
				if m.name == 'sType' then sTyped = true end
				if (m.arr or 0) > 0 then
					assert(m.arr == 1)
					table.insert(mems, {m.name,
						array{vktypes[m.type], lenvar=m.len}, {}})
				else
					table.insert(mems, {m.name, vktypes[m.type],
						m.def ~= '' and m.def or nil})
				end
			end

			vktypes.Vk.type[pn] = compound{v1_0_0=mems, addptr=sTyped,
				realname=n}
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
	for v,cs in pairs(vk.cmds) do
		local M,m = v:match '(%d+)%.(%d+)'
		v = 'v'..M..'_'..m..'_0'
		for _,ct in ipairs(cs) do
			local b,bn
			if ct[2] then b,bn = vkbs[ct[2].type],ct[2].type end
			if not b and ct[1] then b,bn = vkbs[ct[1].type],ct[1].type end
			if not b then b,bn = Vk,'' end

			local n = ct.name
			if n == 'vkDestroy'..(bn:match'Vk(.*)' or '') then n = 'destroy' end

			if n:match 'vkCreate.+' then
				local r = vktypes[ct[#ct].type]
				table.remove(ct)
				if ct[1].type == bn then table.remove(ct, 1) end

				local c = {returns = {r, vktypes.VkResult}, {'self', b}}
				for _,a in ipairs(ct) do
					if a.name == 'pCreateInfo' then
						table.insert(c, {'pCreateInfo', vktypes[a.type]})
					elseif a.name == 'pCreateInfos' then
						table.insert(c, {'pCreateInfos', array{vktypes[a.type],
							lenvar='createInfoCount'}})
						c.returns[1] = array{c.returns[1], lenvar='createInfoCount'}
					else table.insert(c, {a.name, vktypes[a.type]}) end
				end
				b[v][n] = c
			elseif n == 'destroy' then
				b[v][n] = {{'self', b}}
			else
				local c = {returns = raw{realname=ct.ret},
					realname='PFN_'..ct.name}
				for i,a in ipairs(ct) do
					c[i] = {a.name, raw{realname=a.type}}
				end
				b[v][n] = c
			end
		end
	end
end
