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
					vktypes[t.parent][n:match'Vk(.*)'] = {doc="A Vulkan Binding"}
					vktypes[n] = vktypes[t.parent][n:match'Vk(.*)']
				elseif t.type == 'VK_DEFINE_HANDLE' then
					_ENV[n] = {doc="A Vulkan Binding", _ENV[t.parent]}
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

for n,t in pairs(vk.types) do
	if t.category == 'enum' or t.category == 'bitmask' then
		local bn = t.name:match(t.category == 'enum' and '^(.-)%u*$' or '^(.-)Flags%u*$')
		local tokens = {}
		for w in bn:gmatch'%u+%l*' do table.insert(tokens, w:upper()) end

		local vals = {}
		for rn in pairs(t.values) do
			local nam = rn
			for s in pairs(vk.vids) do if nam:match('_'..s..'$') then
				nam = nam:gsub('_'..s..'$', '')
				break
			end end
			if t.category == 'bitmask' then nam:gsub('_BIT$', '') end
			for _,s in ipairs(tokens) do if nam:match('^'..s..'_') then
				nam = nam:gsub('^'..s..'_', '')
			else break end end
			nam = nam:lower():gsub('_.', function(s) return s:sub(2):upper() end)
			table.insert(vals, {nam, rn})
		end

		local entries = {c_external=n}
		print('<Vk.typedef.'..n:match'Vk(.*)'..' = '..t.category..'{')
		for _,v in ipairs(vals) do
			table.insert(entries, {v[1], c_external(v[2])})
			print('<\t{"'..v[1]..'", c_external"'..v[2]..'"},')
		end
		print('<c_external="'..n..'"}')
		Vk.typedef[n:match'Vk(.*)'] = (t.category == 'enum' and enum or bitmask)(entries)
		vktypes[n] = Vk[n:match'Vk(.*)']

		if t.category == 'bitmask' and t.requires then
			print('<Vk.typedef.'..t.requires:match'Vk(.*)'..' = {"Alias", Vk.'..n:match'Vk(.*)'..'}\n')
			Vk.typedef[t.requires:match'Vk(.*)'] = Vk[n:match'Vk(.*)']
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

vktypes.VkSampleMask = integer

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
	{'layerPrefix', string}, {'message', string},
	{'udata', general},
	{boolean},
}

for n,t in pairs(vk.types) do
	if t.category == nil and vktypes[n] == nil then vktypes[n] = 'ignore{}' end
end

do
	local structs = {}
	for n,t in pairs(vk.types) do
		if t.category == 'struct' or t.category == 'union' then
			structs[n] = t

			local mems = {}
			for _,m in ipairs(t.members) do
				if m.values and not m.values:find',' then m.def = 'external"'..m.values..'"'
				elseif m.optional == 'true' then m.def = m.arr > 0 and 0 or {} end
				if m.type == 'char' then
					m.type = 'string'
					m.arr = m.arr - 1
					if m.len then
						m.len = m.len:gsub(',?null%-terminated$', '')
						if #m.len == 0 then m.len = nil end
					end
				end
				mems[m.name] = m
			end

			local rmed = {}
			for _,m in pairs(mems) do
				if m.len then
					if mems[m.len] then mems[m.len],rmed[m.len] = nil,true
					elseif not rmed[m.len] then
						for mm in pairs(mems) do print('>>', mm) end
						print('>>>', m.name, m.len, m.type)
						error('Odd len: '..m.len)
					end
				end
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
				table.insert(mems, {m.name, m.type, m.def})
			end

			print('Vk.typedef.'..n:match'Vk(.*)'..' = {"A Vulkan Binding", '..t.category..'{')
			for _,m in ipairs(mems) do
				print('\t{"'..m[1]..'", vktypes.'..m[2]..', '..tostring(m[3])..'},')
			end
			print('}, c_external="'..n..'"}\n')
			vktypes.Vk.typedef[n:match'Vk(.*)'] = mems
			vktypes[n] = mems
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
