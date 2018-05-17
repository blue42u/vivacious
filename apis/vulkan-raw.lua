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
local vk = {}

-- The main type is Vk, the Vulkan connection manager.
vk.Vk = {
	__name = 'Vk',
	__doc = [[
		Loader for the Vulkan loader, and manager of the vV-Vulkan connection.
	]],
	__directives = {'define VK_NO_PROTOTYPES', 'include <vulkan/vulkan.h>'},
}

-- Load in the Vulkan registry
local xml = assert(io.open('external/vulkan-docs/xml/vk.xml', 'r')):read 'a'
package.loaded.slaxml = require 'external.slaxml.slaxml'
xml = require 'external.slaxml.slaxdom':dom(xml, {stripWhitespace=true})

-- Traversing the DOM is hard in Lua, let's make it easier.
local xtrav
do
	-- Matching function for tags. The entries in `where` are used to string.match
	-- the attributes ('^$' is added), and keys that start with '_' are used on
	-- the tag itself.
	local function xmatch(tag, where)
		for k,v in pairs(where) do
			local t = tag.attr
			if k:match '^_' then k,t = k:match '^_(.*)', tag end
			if not t[k] then return false end
			if type(v) == 'string' then
				if not string.match(t[k], '^'..v..'$') then return false end
			elseif type(v) == 'table' then
				local matchedone = false
				for _,v2 in ipairs(v) do
					if string.match(t[k], '^'..v2..'$') then matchedone = true end
				end
				if not matchedone then return false end
			end
		end
		return true
	end

	-- Find a tag among this tag's children that matchs `where`.
	local function xfind(tag, where, init)
		for i=init or 1, #tag.kids do
			local t = tag.kids[i]
			if xmatch(t, where) then return i, t end
		end
	end

	local function xpairs_inside(s, init)
		return xfind(s.tag, s.where, init+1)
	end
	local function xpairs(tag, where)
		return xpairs_inside, {tag=tag, where=where}, 0
	end

	-- Super-for loop
	local function xnest(tag, where, ...)
		if where then
			for _,t in xpairs(tag, where) do xnest(t, ...) end
		else coroutine.yield(tag) end
	end
	function xtrav(...)
		local args = {...}
		return coroutine.wrap(function() xnest(table.unpack(args)) end)
	end
end

-- We need the list of author id's to allow their removal at key points.
local aids = {}
for t in xtrav(xml.root, {_name='tags'}, {_name='tag'}) do
	aids[t.attr.name] = true
end
local function stripAIDs(s, pre)
	pre = pre or ''
	repeat
		local didanything = false
		for a in pairs(aids) do
			if s:sub(-(#a+#pre)) == pre..a then
				s = s:gsub(pre..a..'$', '')
				didanything = true
			end
		end
	until not didanything
	return s
end

-- Now we get Vulkan's types loaded in. First we need to make some empty shells.
local vkraw = {}	-- Same as `vk`, but uses Vulkan's names rather than vV's.
do
	local cats = {
		basetype=false, handle='__index', enum='__enum', bitmask=false,
		funcpointer='__call', struct='__index', union='__index',
	}
	local masks = {}
	for t in xtrav(xml.root, {_name='types'}, {_name='type'}) do
		if not t.attr.category or cats[t.attr.category] ~= nil then
			local rn = t.attr.name
				or xtrav(t, {_name='name'}, {_type='text'})().value
			local sel = t.attr.alias and vkraw[t.attr.alias]
				or {__name=rn:match '^PFN_(.*)' or rn, __raw=rn}
			vkraw[rn] = sel
			if t.attr.category then
				vk[rn:match '^Vk(.*)' or rn:match '^PFN_(.*)'] = sel
				if cats[t.attr.category] then sel[cats[t.attr.category]] = {}
				elseif t.attr.category == 'bitmask' then
					local con = rn:gsub('Flags', 'FlagBits')
					masks[con] = masks[con] or {}
					masks[con][rn] = true
				end
			end
		end
	end
	for rq,v in pairs(masks) do for rn in pairs(v) do
		if vkraw[rq] then vkraw[rn].__mask = vkraw[rq].__enum end
	end end
	-- Two are odd, they live in the "define" category
	vkraw.ANativeWindow = {__name='ANativeWindow', __raw='struct ANativeWindow'}
	vkraw.AHardwareBuffer = {__name='AHardwareBuffer', __raw='struct AHardwareBuffer'}
end

-- There are two base types that need reinterpreting: void* and char*.
array[vkraw.void] = 'lightuserdata'
array[vkraw.char] = 'string'
array[vkraw.ANativeWindow] = vkraw.ANativeWindow
array[vkraw.AHardwareBuffer] = vkraw.AHardwareBuffer

-- Load in the enumerations
for t in xtrav(xml.root, {_name='enums'}) do if vkraw[t.attr.name] then
	local out = vkraw[t.attr.name].__enum
	for et in xtrav(t, {_name='enum'}) do
		table.insert(out, {raw=et.attr.name, name=et.attr.name}) end
	for et in xtrav(t, {_name='extensions'}, {_name='extension'},
		{_name='require'}, {_name='enum', extends=t.attr.name}) do
			table.insert(out, {raw=et.attr.name, name=et.attr.name}) end

	-- We do the least bit of work here, stripping the AIDs and _BIT suffixes
	for _,e in ipairs(out) do
		e.name = stripAIDs(e.name, '_'):gsub('_BIT$', '')
	end
end end

-- Common code for functions, structures and unions.
-- Made possible by the fact that <member> and <param> tags are nearly identical
-- and __call and __index fields are also nearly identical
local function transform(res, mt, tx)
	if mt then
		if not res.name then
			res.name = xtrav(mt, {_name='name'}, {_type='text'})().value
		end
		if not res.type then
			local typ = xtrav(mt, {_name='type'}, {_type='text'})().value
			assert(vkraw[typ], 'Invalid type reference '..typ)
			res.type = vkraw[typ]
		end
		if not res._len then res._len = mt.attr.altlen or mt.attr.len end
		if res.canbenil == nil then res.canbebil = mt.attr.optional == 'true' end
	end

	-- sType fields aren't actually exposed (to Lua), so we need to specify their value
	if mt and mt.attr.values then
		res.canbenil = true
		res.value = mt.attr.values
		res.doc = 'Automatically set to '..res.value
	end

	if not tx and mt then
		tx = {}
		for ttx in xtrav(mt, {_type='text'}) do tx[#tx+1] = ttx.value end
		tx = table.concat(tx)
		if not res._len and tx:find '%[' then
			res._len = tx:match '%[(.+)%]'
		end
	end

	-- Figure out how many "array" layers there are, using * and [
	if tx then
		local arr = #tx:gsub('[^[*]', '')
		-- Sometimes Vulkan has an extra pointer that's not an array, detect this.
		if arr == 1 and not res._len and res.type ~= vkraw.void then
			res._extraptr = true
			res.name = '\\*'..res.name	 -- Debugging purposes
		elseif arr > 0 then
			assert(not array[res.type].__index or res._len, 'Arrays need lengths! '..res.name)
			if res.type == vkraw.char then
				res._len = res._len:gsub(',?null%-terminated$', '')
				if res._len == '' then res._len = nil end
			end
			for _=1,arr do res.type = array(res.type) end
		end
	end

	-- Debugging purposes
	if res._len then res.name = res.name..'['..res._len..']' end

	return res
end

-- Load in the structures and unions
for t in xtrav(xml.root, {_name='types'}, {_name='type', category={'struct', 'union'}}) do
	for mt in xtrav(t, {_name='member'}) do
		table.insert(vkraw[t.attr.name].__index,
			transform({version='0.0.0'}, mt))
	end
end

-- Load in the funcpointers
for t in xtrav(xml.root, {_name='types'}, {_name='type', category='funcpointer'}) do
	local nam = xtrav(t, {_name='name'}, {_type='text'})().value
	local lastty, text = nil, {}
	for _,mt in ipairs(t.kids) do
		if mt.type == 'text' then table.insert(text, mt.value)
		elseif mt.name == 'type' then
			if lastty then
				text = table.concat(text):gsub('[%s,);]', '')
				local res = {name=text:gsub('[^%w]', ''), type=vkraw[lastty], version='0.0.0'}
				transform(res, nil, text)
				table.insert(vkraw[nam].__call, res)
			end
			lastty, text = xtrav(mt, {_type='text'})().value, {}
		end
	end
	if lastty then
		text = table.concat(text):gsub('[%s,);]', '')
		local res = {name=text:gsub('[^%w]', ''), type=vkraw[lastty], version='0.0.0'}
		transform(res, nil, text)
		table.insert(vkraw[nam].__call, res)
	end
end

-- Load in the handles
for t in xtrav(xml.root, {_name='types'}, {_name='type', category='handle'}) do
	local name = t.attr.name or xtrav(t, {_name='name'}, {_type='text'})().value
	vkraw[name].__index = {
		{name='real', type={__raw=name, __name='opaque handle'},
		doc="Vulkan's handle", version='0.2.0'},
	}
	vkraw[name].__raw = nil
	for p in ((t.attr.parent or 'Vk')..','):gmatch '([^,]+),' do
		local pn = (p:match 'Vk(.+)' or p):gsub('^.', string.lower)
		table.insert(vkraw[name].__index, {
			name=pn, type=vkraw[p] or vk[p], version='0.2.0',
		})
	end
end

-- Load in the commands (these all go to Vk)
vk.Vk.__index = {}
for t in xtrav(xml.root, {_name='commands'}, {_name='command'}) do
	if not t.attr.alias then -- We can't yet handle aliases properly
		local pro = xtrav(t, {_name='proto'})()
		local out = {
			type = {__call = { transform({version='0.0.0'}, pro) }},
			version = '0.0.0',
		}
		out.type.__call[1].name, out.name = 'return', out.type.__call[1].name
		out.type.__raw = 'PFN_'..out.name

		for par in xtrav(t, {_name='param'}) do
			table.insert(out.type.__call, transform({version='0.0.0'}, par))
		end

		table.insert(vk.Vk.__index, out)
	end
end

-- Return the resulting spec
return vk
