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

c_define = 'VK_NO_PROTOTYPES'
c_include = 'vulkan/vulkan.h'

-- Load up the Vulkan registry data
local vk = dofile '../external/vulkan.lua'

local parent_overrides = {
	VkInstance = 'Vk',
	VkDisplayKHR = 'VkPhysicalDevice',
	VkDisplayModeKHR = 'VkDisplayKHR',
}

Vk = {doc="The core Vulkan binding"}
local vktypes = {Vk=Vk}

local vknulls = {}

do
	local handles = {}
	for n,t in pairs(vk.types) do
		if t.category == 'handle' then
			if t.parent and t.parent:find',' then t.parent = nil end	-- We don't do multi-parenting
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
					vktypes[t.parent][n:match'Vk(.*)'] = {doc="A Vulkan Binding",
						wrapper = c_rawtype(n)}
					vktypes[n] = vktypes[t.parent][n:match'Vk(.*)']
				elseif t.type == 'VK_DEFINE_HANDLE' then
					_ENV[n] = {doc="A Vulkan Binding", _ENV[t.parent],
						wrapper = c_rawtype(n)}
					vktypes[n] = _ENV[n]
				else error() end
				vknulls[n] = {}
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

local function enumify(rn, tn, bit)
	local bn = tn:match((not bit) and '^(.-)%u*$' or '^(.-)Flags%u*$')
	local tokens = {}
	for w in bn:gmatch'%u+%l*' do table.insert(tokens, w:upper()) end

	local nam = rn
	for s in pairs(vk.vids) do if nam:match('_'..s..'$') then
		nam = nam:gsub('_'..s..'$', '')
		break
	end end
	if bit then nam:gsub('_BIT$', '') end
	for _,s in ipairs(tokens) do if nam:match('^'..s..'_') then
		nam = nam:gsub('^'..s..'_', '')
	else break end end
	return nam:lower():gsub('_.', function(s) return s:sub(2):upper() end)
end

for n,t in pairs(vk.types) do
	if t.category == 'enum' or t.category == 'bitmask' then
		local vals = {}
		for rn in pairs(t.values) do
			table.insert(vals, {enumify(rn, t.name, t.category == 'bitmask'), rn})
		end

		local entries = {}
		for _,v in ipairs(vals) do
			table.insert(entries, {v[1], c_external(v[2])})
		end
		Vk.typedef[n:match'Vk(.*)'] = (t.category == 'enum' and enum or bitmask)(entries)
		Vk[n:match'Vk(.*)'].c_external = n
		vktypes[n] = Vk[n:match'Vk(.*)']
		if t.category == 'bitmask' then vknulls[n] = {}
		elseif #vals > 0 then vknulls[n] = vals[1][1] end

		if t.category == 'bitmask' and t.requires then
			Vk.typedef[t.requires:match'Vk(.*)'] = Vk[n:match'Vk(.*)']
			Vk[t.requires:match'Vk(.*)'].c_external = t.requires
			vktypes[t.requires] = Vk[t.requires:match'Vk(.*)']
			vknulls[t.requires] = {}
		end
	end
end

vktypes.void,vknulls.void = general, false
vktypes.VkBool32,vknulls.VkBool32 = boolean, false

vktypes.uint64_t,vknulls.uint64_t = integer, 0
vktypes.uint32_t,vknulls.uint32_t = integer, 0
vktypes.uint8_t,vknulls.uint8_t = integer, 0
vktypes.int,vknulls.int = integer, 0
vktypes.int32_t,vknulls.int32_t = integer, 0
vktypes.float,vknulls.float = number, 0
vktypes.size_t,vknulls.size_t = size, 0
vktypes.VkDeviceSize,vknulls.VkDeviceSize = size, 0

vktypes.string,vknulls.string = str, ''

vktypes.vksamplemask,vknulls.vksamplemask = c_bitmask('VkSampleMask'),{}

vktypes.PFN_vkInternalAllocationNotification = callback{
	{'udata', general}, {'size', size},
	{'type', Vk.InternalAllocationType}, {'scope', Vk.SystemAllocationScope},
}
vknulls.PFN_vkInternalAllocationNotification = true
vktypes.PFN_vkInternalFreeNotification = callback{
	{'udata', general}, {'size', size},
	{'type', Vk.InternalAllocationType}, {'scope', Vk.SystemAllocationScope},
}
vknulls.PFN_vkInternalFreeNotification = true
vktypes.PFN_vkReallocationFunction = callback{
	{'udata', general}, {'original', ptr}, {'size', size}, {'alignment', size},
	{'scope', Vk.SystemAllocationScope},
	{ptr},
}
vknulls.PFN_vkReallocationFunction = true
vktypes.PFN_vkAllocationFunction = callback{
	{'udata', general}, {'size', size}, {'alignment', size},
	{'scope', Vk.SystemAllocationScope},
	{ptr},
}
vknulls.PFN_vkAllocationFunction = true
vktypes.PFN_vkFreeFunction = callback{
	{'udata', general}, {'mem', ptr},
}
vknulls.PFN_vkFreeFunction = true

vktypes.PFN_vkDebugReportCallbackEXT = callback{
	{'flags', Vk.DebugReportFlagsEXT}, {'objectType', Vk.DebugReportObjectTypeEXT},
	{'object', integer}, {'location', size}, {'mCode', integer},
	{'layerPrefix', str}, {'message', str},
	{'udata', general},
	{boolean},
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
} do vktypes[n],vknulls[n] = c_rawtype(n),c_external'NULL' end

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
				if m.values and not m.values:find',' then m.def = enumify(m.values, m.type)
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
			local mems,def = {},{}
			for _,m in ipairs(t.members) do
				if not vktypes[m.type] then missing[m.type] = true goto skip end
			end

			local sTyped = false
			local pn = n:match'Vk(.*)'
			for _,m in ipairs(t.members) do
				if m.name == 'sType' then sTyped = true end
				if (m.arr or 0) > 0 then
					assert(m.arr == 1)
					table.insert(mems, {m.name, array{vktypes[m.type], c_len=m.len}})
				else
					table.insert(mems, {m.name, vktypes[m.type]})
				end
				if m.def == '' then
					if vknulls[m.type] == nil then error('No NULL for '..m.type) end
					def[m.name] = m.arr > 0 and {} or vknulls[m.type]
				else def[m.name] = m.def end
			end

			vktypes.Vk.typedef[pn] = compound{v1_0_0=mems, static=not sTyped}
			Vk[pn].c_external = n
			Vk[pn].default = def
			vktypes[n] = Vk[pn]
			vknulls[n] = {}
			structs[n] = nil
			stuck = false
			::skip::
		end
		if stuck then
			for t in pairs(missing) do print('>', t) end
			for n in pairs(structs) do print('>>', n) end
			error()
		end
	until not next(structs)
end
