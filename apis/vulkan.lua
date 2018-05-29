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

vk.version = {__raw='uint32_t', __name="'M.m.p'"}

-- Helper for for-loop accumulations, since I'm tired of typing it again
local function acc(...)
	local r = {}
	for x in ... do table.insert(r, x) end
	return r
end

-- Helpers for Human errors.
local humanerror = false
local function herror(s, v)
	if v then v = v.__name..(v.__raw and ' :{'..v.__raw..'}' or '') end
	io.stderr:write('VkHuman ERROR: '..tostring(s):gsub('{#}', v)..'\n')
	humanerror = true
end
local function hassert(t, ...) if not t then herror(...) end end

-- Build the translations of the raw C names for enums, changing Lua's name.
local enumnames = {}
for _,v in pairs(vk) do if v.__enum then
	-- Try to get the common prefix for this enum.
	local pre
	if #v.__enum < 2 then
		pre = human.enumprefixes[v.__raw]
		if #v.__enum == 0 then
			hassert(pre == 0, 'Unhandled empty enum {#}', v)
		elseif #v.__enum == 1 then
			hassert(type(pre) == 'string',
				'Unhandled only entry '..v.__enum[1].raw..' of enum {#}', v)
		end
	else
		hassert(human.enumprefixes[v.__raw] == nil, 'Handled multi-entried enum {#}')
		local full = acc((v.__enum[1].raw..'_'):gmatch '([^_]*)_')
		for j=1,#full do
			local tpre = table.concat(full, '_', 1, j)
			for _,e in ipairs(v.__enum) do
				if e.raw:sub(1,#tpre) ~= tpre then tpre = nil; break end
			end
			if not tpre then break end
			pre = tpre
		end
	end

	-- Remove the common prefix
	if pre then
		for _,e in ipairs(v.__enum) do
			e.name = e.name:gsub('^'..pre..'_', '')
			e.name = ('_'..e.name):lower():gsub('_(.)', string.upper)
			enumnames[e.raw] = e.name
		end
	end
end end

-- Process the _lens and _values of accessable structures.
local handled = {}	-- To handle aliases, remove repetition
for _,v in pairs(vk) do if (v.__index or v.__call) and not handled[v] then
	handled[v] = true

	local names,lens = {},{}
	for _,e in ipairs(v.__index or v.__call) do
		names[e.name] = e
		if e._len then
			local r,x = human.length(e, v, '#'..e.name, v.__index or v.__call)
			if r then lens[r] = lens[r] or {}; table.insert(lens[r], x) end
		end
		if e._value then
			assert(enumnames[e._value], 'Unknown value: '..e._value)
			e.setto = {enumnames[e._value]}
		end
	end
	for r,xs in pairs(lens) do
		if names[r] then names[r].canbenil, names[r].setto = true, xs end
	end
end end

-- Process the commands.
for _,c in ipairs(vk.Vk.__index) do
	c.exbinding = true
	c.type.__call.method = true

	local names,lens = {},{}
	for _,e in ipairs(c.type.__call) do
		names[e.name] = e
		if e._len then
			local r,x = human.length(e, c.type, '#'..e.name, c.type.__call)
			if r then lens[r] = lens[r] or {}; table.insert(lens[r], x) end
		end
	end
	for r,xs in pairs(lens) do
		if names[r] then names[r].setto = xs end
	end
end

if humanerror then error 'VkHuman error detected!' end
return vk
