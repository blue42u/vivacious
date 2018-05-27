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

-- Build the translations of the raw C names for enums, changing Lua's name.
local enumnames = {}
local humanerror
for _,v in pairs(vk) do if v.__enum then
	-- Try to get the common prefix for this enum.
	local pre
	if #v.__enum < 2 then
		pre = human.enumprefixes[v.__raw]
		if #v.__enum == 0 then
			if pre ~= 0 then
				print(('VkHuman ERROR: does not handle empty enum %s :{%s}'):format(v.__name, v.__raw))
				humanerror = true
			end
		elseif #v.__enum == 1 then
			if type(pre) ~= 'string' then
				print(('VkHuman ERROR: does not handle only entry %s of enum %s :{%s}')
					:format(v.__enum[1].raw, v.__name, v.__raw))
				humanerror = true
			end
		end
	else
		if human.enumprefixes[v.__raw] then
			print(('VkHuman ERROR: handles multi-entried enum %s :{%s}'):format(v.__name, v.__raw))
			humanerror = true
		end
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
if humanerror then error 'VkHuman error detected!' end

-- Use the _len indicators to remove some of the __index and __call entries.
local handled = {}
local function antilen(typ, key, doct, dockey)
	if not typ[key] then return end
	if handled[typ] then return end
	handled[typ] = true
	local names, lens = {},{}
	local extradoc = {doct[dockey]}
	for i,e in ipairs(typ[key]) do
		names[e.name] = i
		if e._len then
			-- The lengths should almost always be a bit of Lua code
			local v,t = human.length(e._len, '#'..e.name, typ[key])
			if v then lens[v] = lens[v] or {}; table.insert(lens[v], t) end
		end
		if e._value then
			assert(enumnames[e._value], 'Unknown _value: '..e._value)
			table.insert(extradoc, '- '..e.name..' = `\''..enumnames[e._value]..'\'`')
		end
	end
	for k,ns in pairs(lens) do
		if names[k] then
			local x = typ[key][names[k]]
			x.canbenil,x._islen = true, true
		end
		local parts = {}
		for _,ex in ipairs(ns) do table.insert(parts, ex) end
		table.insert(extradoc, '- '..k..' = `'..table.concat(parts, ' == ')..'`')
	end

	if #extradoc > 0 then doct[dockey] = table.concat(extradoc, '\n') end
end

for _,v in pairs(vk) do antilen(v, '__index', v, '__doc') end
for _,e in ipairs(vk.Vk.__index) do antilen(e.type, '__call', e, 'doc') end

return vk
