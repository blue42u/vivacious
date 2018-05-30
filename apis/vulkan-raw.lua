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

	-- for-compatible wrapper for xfind
	local function xpairs_inside(s, init)
		return xfind(s.tag, s.where, init+1)
	end
	local function xpairs(tag, where)
		return xpairs_inside, {tag=tag, where=where}, 0
	end

	-- Super-for loop, exposed as an iterator using coroutines. It works.
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
local cats = {
	basetype=true, handle=true, enum=true, bitmask=true,
	funcpointer=true, struct=true, union=true,
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
			if t.attr.category == 'bitmask' then
				local con = rn:gsub('Flags', 'FlagBits')
				masks[con] = masks[con] or {}
				masks[con][rn] = true
			end
		end
	end
end
-- Two are odd, they live in the "define" category
vkraw.ANativeWindow = {__name='ANativeWindow', __raw='struct ANativeWindow'}
vkraw.AHardwareBuffer = {__name='AHardwareBuffer', __raw='struct AHardwareBuffer'}

-- A handful of types should only appear as pointers, so the *'s are integrated.
for k,v in pairs{
	void='lightuserdata', char='string',
	ANativeWindow=vkraw.ANativeWindow, AHardwareBuffer=vkraw.AHardwareBuffer,
} do array[vkraw[k]] = v end

-- Mark the handles with a bit of useful info
for t in xtrav(xml.root, {_name='types'}, {_name='type', category='handle'}) do
	if t.attr.parent and not t.attr.parent:find ',' then
		vkraw[t.attr.name or xtrav(t, {_name='name'}, {_type='text'})().value]
			._parent = t.attr.parent
	end
end

-- Load in the enumerations
for t in xtrav(xml.root, {_name='enums'}) do if vkraw[t.attr.name] then
	local out = {}
	vkraw[t.attr.name].__enum = out
	for et in xtrav(t, {_name='enum'}) do
		table.insert(out, {raw=et.attr.name, name=et.attr.name}) end
	for et in xtrav(xml.root, {_name='feature'}, {_name='require'},
		{_name='enum', extends=t.attr.name}) do
			table.insert(out, {raw=et.attr.name, name=et.attr.name}) end
	for ext in xtrav(xml.root, {_name='extensions'}, {_name='extension'}) do
		for et in xtrav(ext, {_name='require'}, {_name='enum', extends=t.attr.name}) do
			table.insert(out, {raw=et.attr.name, name=et.attr.name, ifdef=ext.attr.name}) end end

	-- We do the least bit of work here, stripping the AIDs and _BIT suffixes
	for _,e in ipairs(out) do
		e.name = stripAIDs(e.name, '_'):gsub('_BIT$', '')
	end
end end

-- Connect the __enum tags and __mask tags of corrosponding bitmask/enums
for rq,v in pairs(masks) do for rn in pairs(v) do
	if vkraw[rq] then vkraw[rn].__mask = vkraw[rq].__enum end
end end

-- Common code for functions, structures and unions.
-- Made possible by the fact that <member> and <param> tags are nearly identical
-- and __call and __index fields are also nearly identical
local function transform(res, t)
	local tx

	-- t may be a table, which is a tag in the DOM
	if type(t) == 'table' then
		if not res.name then
			res.name = xtrav(t, {_name='name'}, {_type='text'})().value
		end
		if not res.type then
			local typ = xtrav(t, {_name='type'}, {_type='text'})().value
			assert(vkraw[typ], 'Invalid type reference '..typ)
			res.type = vkraw[typ]
		end
		if not res._len then
			res._len = t.attr.altlen or t.attr.len
			if not res._len then
				local x = xtrav(t, {_name='enum'}, {_type='text'})()
				if x then res._len = x.value end
			end
		end
		if res.canbenil == nil then res.canbenil = t.attr.optional == 'true' end

		-- sType fields aren't actually exposed (to Lua), so we force the value
		if t.attr.values then
			res.canbenil = true
			res._value = t.attr.values
		end

		-- Construct the text data from the contained text tags
		tx = {}
		for ttx in xtrav(t, {_type='text'}) do tx[#tx+1] = ttx.value end
		tx = table.concat(tx)
		if not res._len and tx:find '%[' then
			res._len = tx:match '%[(.+)%]'
		end
	elseif type(t) == 'string' then
		tx = t	-- The text data is just the string
	end

	-- Figure out how many "array" layers there are, using * and [ in the text
	if tx then
		local arr = #tx:gsub('[^[*]', '')
		-- Sometimes Vulkan has an extra pointer that's not an array, detect this.
		if arr == 1 and not res._len and res.type ~= vkraw.void then
			res.extraptr = true
		elseif arr > 0 then
			assert(not array[res.type].__index or res._len, 'Arrays need lengths! '..res.name)
			if res.type == vkraw.char then
				res._len = res._len:gsub(',?null%-terminated$', '')
				if res._len == '' then res._len = nil end
			end
			for _=1,arr do res.type = array(res.type) end
		end
	end

	return res
end

-- Load in the structures and unions
for t in xtrav(xml.root, {_name='types'}, {_name='type', category={'struct', 'union'}}) do
	if not t.attr.alias then
		vkraw[t.attr.name].__index = {}
		for mt in xtrav(t, {_name='member'}) do
			table.insert(vkraw[t.attr.name].__index, transform({version='0.0.0'}, mt))
		end
	end
end

-- Load in the funcpointers
for t in xtrav(xml.root, {_name='types'}, {_name='type', category='funcpointer'}) do
	local nam = xtrav(t, {_name='name'}, {_type='text'})().value
	vkraw[nam].__call = {}
	local lastty, text = nil, {}
	for _,mt in ipairs(t.kids) do
		if mt.type == 'text' then table.insert(text, mt.value)
		elseif mt.name == 'type' then
			if lastty then
				text = table.concat(text):gsub('[%s,);]', '')
				local res = {name=text:gsub('[^%w]', ''), type=vkraw[lastty], version='0.0.0'}
				if res.type == vkraw.char then res._len = 'null-terminated' end
				transform(res, text)
				table.insert(vkraw[nam].__call, res)
			end
			lastty, text = xtrav(mt, {_type='text'})().value, {}
		end
	end
	if lastty then
		text = table.concat(text):gsub('[%s,);]', '')
		local res = {name=text:gsub('[^%w]', ''), type=vkraw[lastty], version='0.0.0'}
		transform(res, text)
		table.insert(vkraw[nam].__call, res)
	end
end

-- Load in the commands (these all go to Vk)
vk.Vk.__index = {}
for t in xtrav(xml.root, {_name='commands'}, {_name='command'}) do
	if not t.attr.alias then -- We can't yet handle aliases properly
		local out = {
			type = {__call = {} },
			version = '0.0.0',
		}
		for par in xtrav(t, {_name='param'}) do
			table.insert(out.type.__call, transform({version='0.0.0'}, par))
		end

		local pro = transform({version='0.0.0'}, xtrav(t, {_name='proto'})())
		out.name, out.type.__raw = pro.name, 'PFN_'..pro.name
		pro.name, pro.mainret = 'return', true
		if pro.type ~= vkraw.void then table.insert(out.type.__call, pro) end

		table.insert(vk.Vk.__index, out)
	else
		table.insert(vk.Vk.__index, {name=t.attr.name, aliasof=t.attr.alias, version='0.0.0'})
	end
end

-- Figure out the C ifdef's for everything
local voidf,voidp = {__raw='PFN_vkVoidFunction'},{__raw='void*'}
local cmds = {}
for _,c in ipairs(vk.Vk.__index) do cmds[c.name] = c.type or cmds[c.aliasof] end
for ext in xtrav(xml.root, {_name='extensions'}, {_name='extension'}) do
	for et in xtrav(ext, {_name='require'}, {_name={'type', 'command'}}) do
		local t = (et.name == 'type' and vkraw or cmds)[et.attr.name]
		assert(t, 'No vkraw for '..et.attr.name)
		if not t.__ifdef then t.__ifdef = {} end
		table.insert(t.__ifdef, ext.attr.name)
		if et.parent.attr.extension then table.insert(t.__ifdef, et.parent.attr.extension) end
		t.__ifndef = et.name == 'type' and voidp or voidf
	end
end
for et in xtrav(xml.root, {_name='feature'}, {_name='require'}, {_name={'type', 'command'}}) do
	if not et.attr.name:match '^[Vv][Kk]_' then
		local t = (et.name == 'type' and vkraw or cmds)[et.attr.name]
		assert(t, 'No vkraw for '..et.attr.name)
		t.__ifdef = nil
	end
end

-- Return the resulting spec
return vk
