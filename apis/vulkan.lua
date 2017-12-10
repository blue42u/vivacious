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
						v1_0_0 = {{'real', c_rawtype(n)}}}
					vktypes[n] = vktypes[t.parent][n:match'Vk(.*)']
				elseif t.type == 'VK_DEFINE_HANDLE' then
					_ENV[n] = {doc="A Vulkan Binding", _ENV[t.parent],
						v1_0_0 = {{'real', c_rawtype(n)}}}
					vktypes[n] = _ENV[n]
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
		print('Vk.typedef.'..n:match'Vk(.*)'..' = '..t.category..'{')
		for _,v in ipairs(vals) do
			table.insert(entries, {v[1], c_external(v[2])})
			print('\t{"'..v[1]..'", c_external"'..v[2]..'"},')
		end
		print('}')
		Vk.typedef[n:match'Vk(.*)'] = (t.category == 'enum' and enum or bitmask)(entries)
		print('Vk.'..n:match'Vk(.*)'..'.c_external = "'..n..'"')
		Vk[n:match'Vk(.*)'].c_external = n
		vktypes[n] = Vk[n:match'Vk(.*)']

		if t.category == 'bitmask' and t.requires then
			print('Vk.typedef.'..t.requires:match'Vk(.*)'..' = {"Alias", Vk.'..n:match'Vk(.*)'..'}\n')
			Vk.typedef[t.requires:match'Vk(.*)'] = Vk[n:match'Vk(.*)']
			Vk[t.requires:match'Vk(.*)'].c_external = t.requires
			vktypes[t.requires] = Vk[t.requires:match'Vk(.*)']
		else print() end
	end
end

vktypes.void = general
vktypes.VkBool32 = boolean

vktypes.uint64_t = integer
vktypes.uint32_t = integer
vktypes.uint8_t = integer
vktypes.int = integer
vktypes.int32_t = integer
vktypes.float = number
vktypes.size_t = size
vktypes.VkDeviceSize = size

vktypes.string = str

vktypes.vksamplemask = c_bitmask('VkSampleMask')

vktypes.PFN_vkInternalAllocationNotification = callback{
	{'udata', general}, {'size', size},
	{'type', Vk.InternalAllocationType}, {'scope', Vk.SystemAllocationScope},
}
vktypes.PFN_vkInternalFreeNotification = callback{
	{'udata', general}, {'size', size},
	{'type', Vk.InternalAllocationType}, {'scope', Vk.SystemAllocationScope},
}
vktypes.PFN_vkReallocationFunction = callback{
	{'udata', general}, {'original', ptr}, {'size', size}, {'alignment', size},
	{'scope', Vk.SystemAllocationScope},
	{ptr},
}
vktypes.PFN_vkAllocationFunction = callback{
	{'udata', general}, {'size', size}, {'alignment', size},
	{'scope', Vk.SystemAllocationScope},
	{ptr},
}
vktypes.PFN_vkFreeFunction = callback{
	{'udata', general}, {'mem', ptr},
}

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
	HINSTANCE=true, HWND=true, SECURITY_ATTRIBUTES=true, -- windows.h
	xcb_connection_t=true, xcb_visualid_t=true, xcb_window_t=true,	-- xcb.h
} do vktypes[n] = c_rawtype(n) end

for n in pairs{
	HANDLE=true, LPCWSTR=true, DWORD=true, -- windows.h
} do vktypes[n] = c_rawtype(n, true) end

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
				end
				if m.values and not m.values:find',' then m.def = enumify(m.values, m.type)
				elseif m.optional == 'true' then m.def = m.arr > 0 and {} or 0 end
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

			local pn = n:match'Vk(.*)'
			print('Vk.typedef.'..pn..' = '..t.category..'{')
			for _,m in ipairs(t.members) do
				if (m.arr or 0) > 0 then
					assert(m.arr == 1)
					print('\t{"'..m.name..'", array{vktypes.'..m.type
						..', c_len="'..tostring(m.len)..'"}},')
					table.insert(mems, {m.name, array{vktypes[m.type], c_len=m.len}})
				else
					print('\t{"'..m.name..'", vktypes.'..m.type..'},')
					table.insert(mems, {m.name, vktypes[m.type]})
				end
				def[m.name] = m.def
			end
			print('}')

			vktypes.Vk.typedef[pn] = compound{v1_0_0=mems}
			print('Vk.'..pn..'.c_external = "'..n..'"')
			Vk[pn].c_external = n
			local function dump(v, k, p)
				if type(v) == 'table' then
					if next(v) then
						print(p..k..' = {')
						for tk,tv in pairs(v) do dump(tv, tk, '\t'..p) end
						print(p..'},')
					else print(p..k..' = {},') end
				else print(p..k..' = '..tostring(v)..',') end
			end
			dump(def, 'Vk.'..pn..'.default', '')
			print()
			Vk[pn].default = def
			vktypes[n] = Vk[pn]
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
