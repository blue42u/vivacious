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
local vk = require 'vulkan-raw'
local human = require 'vulkan-human'

vk.version = {__raw={C='uint32_t'}, __name="'M.m.p'"}

-- Helper for for-loop accumulations, since I'm tired of typing it again
local function acc(...)
 local r = {}
 for x in ... do r[#r+1] = x end
 return r
end

-- Helpers for Human errors.
local humanerror = false
local function herror(s, v)
 if v then v = v.__name..(v.__raw and ' :{'..v.__raw.C..'}' or '') end
 io.stderr:write(tostring(s):gsub('{#}', v or '{#}')..'\n')
 humanerror = true
end
local function hassert(t, ...) if not t then herror(...) end end
human.herror, human.hassert = herror, hassert	-- Let the Human have access

-- Build the translations of the raw C names for enums, changing Lua's name.
local enumnames = {}
local handled = {}
for _,v in pairs(vk) do if v.__enum and not v.__mask and not handled[v.__enum] then
	handled[v.__enum] = true

	-- Try to get the common prefix for this enum.
	local pre
	if #v.__enum < 2 then
		pre = human.enumprefixes[v.__raw.C]
		if #v.__enum == 0 then
			hassert(pre == 0, 'Unhandled empty enum {#}', v)
		elseif #v.__enum == 1 then
			hassert(type(pre) == 'string',
				'Unhandled only entry '..v.__raw.enum[v.__enum[1].name].C..' of enum {#}', v)
		end
	else
		hassert(human.enumprefixes[v.__raw.C] == nil, 'Handled multi-entried enum {#}', v)
		local _,nv = next(v.__raw.enum)
		local full = acc((nv.C..'_'):gmatch '([^_]*)_')
		for j=1,#full do
			local tpre = table.concat(full, '_', 1, j)
			for _,e in ipairs(v.__enum) do
				if v.__raw.enum[e.name].C:sub(1,#tpre) ~= tpre then tpre = nil; break end
			end
			if not tpre then break end
			pre = tpre
		end
	end

	-- Remove the common prefix
	if pre then
		for _,e in ipairs(v.__enum) do
			local old = e.name
			e.name = e.name:gsub('^'..pre..'_', '')
			e.name = ('_'..e.name):lower():gsub('_(.)', string.upper)
			v.__raw.enum[e.name], v.__raw.enum[old] = v.__raw.enum[old], nil
		end
	end

	-- Record the resulting links
	for _,e in ipairs(v.__enum) do
		enumnames[v.__raw.enum[e.name].C] = e.name
	end
end end

-- Process the _lens and _values of accessable structures.
for _,v in pairs(vk) do if (v.__index or v.__call) and not handled[v] then
	handled[v] = true

	local names,raws,eptr = {},{},{}
	for _,re in ipairs(v.__raw and (v.__raw.index or v.__raw.call) or {}) do
		raws[re.name] = re
	end
	for _,e in ipairs(v.__index or v.__call) do
		names[e.name] = e
		if e._len then
			local r,x = human.length(e, v, '#'..e.name, v.__index or v.__call)
			if r then
				local n = names[r]
				n.canbenil = true
				raws[r].value = nil
				raws[r].values = raws[r].values or {}
				table.insert(raws[r].values, x)
			end
		end
		if e._value then
			assert(enumnames[e._value], 'Unknown value: '..e._value)
			raws[e.name].C = enumnames[e._value]
			e._value = nil
		end
		if e._extraptr then eptr[e.name],e._extraptr = true,nil end
	end
	for _,re in ipairs(v.__raw and (v.__raw.index or v.__raw.call) or {}) do
		if eptr[re.name] then re.extraptr = true end
	end
end end

-- Process the commands.
local alias = {}
for _,c in ipairs(vk.Vk.__index) do if c.aliasof then
	if not alias[c.aliasof] then alias[c.aliasof] = {} end
	table.insert(alias[c.aliasof], c)
end end
local removed,handle,connect = {},{},{}
for _,c in ipairs(vk.Vk.__index) do if not c.aliasof then
	c.exbinding = true
	c.type.__call.method = true

	-- Figure out where this entry should actually go, and move it there.
	local raws = {}
	for _,re in ipairs(c.type.__raw.call) do raws[re.value] = re end
	local self = human.self(c.type.__call, raws, c.name)
	if self then
		if not handle[self] then
			vk[self.__name] = {
				__name = self.__name,
				__index = {{name='real', version='0.0.0', type=self},
					{name='parent', version='0.0.0'}}
			}
			handle[self] = vk[self.__name]
			handle[self].__index[2].type = vk.Vk
			if not self._parent then
				hassert(human.parent[self.__name] ~= nil, 'No parent for '..self.__name)
			end
			connect[handle[self]] = (self._parent and self._parent:gsub('^Vk', ''))
				or human.parent[self.__name] or nil
			self._parent = nil
			self.__name = 'opaque handle/'..self.__name
		end
		local ind = handle[self].__index
		removed[c] = true
		ind[#ind+1] = c
		for _,a in ipairs(alias[c.name] or {}) do
			removed[a] = true
			ind[#ind+1] = a
		end
	end
end end
for h,p in pairs(connect) do
	h.__index[2].type = assert(handle[vk[p]], 'No handle '..p) end
for _,c in ipairs(vk.Vk.__index) do if not c.aliasof then
	local raws,eptr = {},{}
	for _,re in ipairs(c.type.__raw.call) do raws[re.value] = re end
	for _,e in ipairs(c.type.__call) do
		if e._len then
			local r,x = human.length(e, c.type, '#'..e.name, c.type.__call)
			if r and raws[r] then
				raws[r].value = nil
				raws[r].values = raws[r].values or {}
				raws[r].type = 'integer'
				table.insert(raws[r].values, x)
			end
		end
		if raws[e.name] and not raws[e.name].values and handle[e.type] then
			e.type, raws[e.name].value = handle[e.type], e.name..'.real'
			raws[e.name].type = handle[e.type]
		end
		if e._extraptr then eptr[e.name],e._extraptr = true,nil end
	end
	for _,re in ipairs(c.type.__raw.call) do
		if eptr[re.value] then re.extraptr = true end
	end
end end
local newindex = {}
for _,c in ipairs(vk.Vk.__index) do
	if not removed[c] then newindex[#newindex+1] = c end
end
vk.Vk.__index = newindex

if humanerror then error 'VkHuman error detected!' end
return vk
