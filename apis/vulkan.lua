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

-- A version of ipairs that allows the current entry to be removed
-- Loop vars are value, removal function.
local function rpairs(tab)
	local addone = true
	local i = 0
	return function(t)
		if addone then i = i + 1 end
		addone = true
		if t[i] ~= nil then
			return t[i], function()
				if addone then table.remove(t, i) end
				addone = false
			end
		end
	end, tab
end

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

-- Vulkan structures that have an sType field are always dereferenced. Make it so.
for _,v in pairs(vk) do
	if v.__index and v.__raw and v.__index then
		v.__raw.dereference = true
	end
end

-- Process the commands. There's a lot to do.
local wrappers,wrapped,moveto = {},{},{}
for c,rmc in rpairs(vk.Vk.__index) do
	if not c.aliasof then
		c.type.__call.method = true	-- All commands are methods in vV

		-- For later reference, some useful markings
		local names,raws = {},{}
		for i,e in ipairs(c.type.__call) do if e.name then
			names[e.name], raws[e.name] = e, c.type.__raw.call[i]
		end end

		-- Figure out where all the commands should go, and move them there
		local sargs = {human.self(c.type.__call, c.name)}
		local rets = {human.rets(c.type.__call, c.name)}
		local rawself = table.remove(sargs, 1)
		if rawself then
			if not wrappers[rawself] then	-- Make the wrapper if it doesn't exist yet
				wrappers[rawself] = {
					__name = rawself.__name,
					__index = {{name='real', type=rawself}, {name='parent'}},
				}
				vk[rawself.__name:gsub('^Vk', '')] = wrappers[rawself]
				wrapped[wrappers[rawself]] = rawself
			end
			-- Move the command to its rightful owner or "self"
			moveto[c.name] = wrappers[rawself]
			table.insert(wrappers[rawself].__index, c)
			rmc()

			-- The first few fields are often provided by the self. Mark them as such.
			for i,s in ipairs(sargs) do
				c.type.__raw.call[i].value = s
				table.remove(c.type.__call, 1)
			end
		end

		-- Some fields are actually return values: mark them for later.
		for _,r in ipairs(rets) do
			local foundit = false
			for _,e in ipairs(c.type.__call) do
				if e.name == r then
					e.ret = true
					foundit = true
					break
				end
			end
			hassert(foundit, "No argument to mark for returning called "..tostring(r))
		end

		for _,e in ipairs(c.type.__call) do
			-- Some fields merely indicate the length of others. Mark them as such.
			if e._len then
				local r,x = human.length(e, c.type, '#'..e.name, c.type.__call)
				if r and raws[r] then
					raws[r].value = nil	-- It'll just be r at this point
					raws[r].values = raws[r].values or {}
					table.insert(raws[r].values, x)
					e.lentype = names[r].type
					local re = names[r]
					re._islen = true
				end
			end

			-- If there's an argument that's been wrapped, replace it.
			if wrappers[e.type] and raws[e.name].value and not e.ret then
				raws[e.name].value, e.type = e.name..'.real', wrappers[e.type]
			end
		end

		-- Some fields are marked as lengths. Now we merge them for Lua.
		for e,rme in rpairs(c.type.__call) do
			if e._islen then
				e._islen = nil
				rme()
			end
		end
	end
end

-- Some of the leftover commands are aliases. Now we get to move them.
for c,rmc in rpairs(vk.Vk.__index) do
	if moveto[c.aliasof] then
		table.insert(moveto[c.aliasof].__index, c)
		rmc()
	end
end

-- Connect up the parent fields of the wrappers, so they actually make sense
for rs,w in pairs(wrappers) do
	local par = human.parent(rs._parent, rs.__name)
	if par then assert(wrapped[vk[par]], "vk."..par.." isn't a wrapper!") end
	w.__index[2].type = assert(vk[par or 'Vk'], 'No wrapper for '..(par or 'nil'))
	rs._parent = nil
	rs.__name = 'opaque handle/'..rs.__name
end

-- All set, let's do this!
if humanerror then error 'VkHuman error detected!' end
return vk
