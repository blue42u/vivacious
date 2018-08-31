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

-- luacheck: globals array constarray method callable versioned openfile
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
local xml = openfile'external/vulkan-docs/xml/vk.xml':read 'a'
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

-- Now we get Vulkan's types loaded in. First we need to make some empty shells.
local vkraw = {}	-- Same as `vk`, but uses Vulkan's names rather than vV's.
local cats = {
	basetype=true, handle=true, enum=true, bitmask=true,
	funcpointer=true, struct=true, union=true,
}
local masks = {}
for t in xtrav(xml.root, {_name='types'}, {_name='type'}) do
	if not t.attr.category or cats[t.attr.category] then
		local rn = t.attr.name or xtrav(t, {_name='name'}, {_type='text'})().value
		vkraw[rn] = t.attr.alias and vkraw[t.attr.alias] or {__raw={C=rn}}
		if t.attr.category then
			vk[rn:match '^Vk(.*)' or rn:match '^PFN_(.*)'] = vkraw[rn]
			if t.attr.category == 'bitmask' then
				local con, cnt = rn:gsub('Flags', 'FlagBits')
				assert(cnt == 1, "Hrm... Mistakes have been made: "..rn)
				masks[con] = masks[con] or {}
				masks[con][rn] = true
			end
		end
	end
end
-- Two are odd, they live in the "define" category
vkraw.ANativeWindow = {__raw={C='struct ANativeWindow*'}}
vkraw.AHardwareBuffer = {__raw={C='struct AHardwareBuffer*'}}
-- Others have a name that doesn't make sense for vV, so we add the *s.
vkraw.Display.__raw.C = 'Display*'
vkraw.xcb_connection_t.__raw.C = 'xcb_connection_t*'
vkraw.void.__raw.C = 'void*'
vkraw.char.__raw.C = 'char*'

-- Mark the handles with a bit of useful info
for t in xtrav(xml.root, {_name='types'}, {_name='type', category='handle'}) do
	-- We only do this automatically for single-parent handles.
	if t.attr.parent and not t.attr.parent:find ',' then
		vkraw[t.attr.name or xtrav(t, {_name='name'}, {_type='text'})().value]
		._parent = t.attr.parent
	end
end

-- Fill the enumerations with the corrosponding data.
--[==[ TODO: Disabled for now, needs a decision to be made for conversion's sake.
for t in xtrav(xml.root, {_name='enums'}) do if vkraw[t.attr.name] then
	local self = vkraw[t.attr.name]
	self.__enum,self.__raw.enum = {},{}

	for et in xtrav(t, {_name='enum'}) do
		if not self.__raw.enum[et.attr.name] then
			table.insert(self.__enum, {name=et.attr.name})
			self.__raw.enum[et.attr.name] = {C=et.attr.name}
		end
	end
	for et in xtrav(xml.root,
		{_name='feature'}, {_name='require'}, {_name='enum', extends=t.attr.name}) do
		if not self.__raw.enum[et.attr.name] then
			table.insert(self.__enum, {name=et.attr.name})
			self.__raw.enum[et.attr.name] = {C=et.attr.name}
		end
	end
	for ext in xtrav(xml.root, {_name='extensions'}, {_name='extension'}) do
		for et in xtrav(ext, {_name='require'}, {_name='enum', extends=t.attr.name}) do
			if not self.__raw.enum[et.attr.name] then
				table.insert(self.__enum, {name=et.attr.name})
				self.__raw.enum[et.attr.name] = {C=et.attr.name, ifdef=ext.attr.name}
			end
		end
	end
end end

-- Connect the __enum tags and __mask tags of corrosponding bitmask/enums
for rq,v in pairs(masks) do for rn in pairs(v) do
	vkraw[rn].__mask = true
	if vkraw[rq] then
		vkraw[rn].__enum,vkraw[rn].__raw.enum = vkraw[rq].__enum,vkraw[rq].__raw.enum
	end
end end
]==]

-- Common code for functions, structures and unions.
-- Made possible by the fact that <member> and <param> tags are nearly identical
-- and that __call, __index and __newindex fields are also nearly identical
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

		-- sType fields aren't actually exposed (to Lua), so we force the value
		if t.attr.values then
			assert(not t.attr.values:find ',', "Hrm... Think about this.")
			res.default = t.attr.values
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

	-- Figure out how many "array" layers there are, using * and [ in the text.
	if tx then
		local arr = #tx:gsub('[^[*]', '')
		if res.type.__raw.C:find '*$' then arr = arr - 1 end
		-- Sometimes Vulkan has an extra pointer that's not an array, detect this.
		if arr == 1 and not res._len then
			-- res._extraptr = true	-- TODO: Disabled for the time being
		elseif arr > 0 then
			assert(not array[res.type].__newindex or res._len, 'Arrays need lengths! '..res.name)
			if res.type == vkraw.char then
				res._len = res._len:gsub(',?null%-terminated$', '')
				if res._len == '' then res._len = nil end
			end
			for _=1,arr do res.type = array(res.type) end
		end
	end

	res._len = nil	-- TODO: _len disabled for the time being
	return res
end

-- Load in the structures and unions
--[==[ TODO: Disabled for now, needs a decision to be made for conversion's sake.
for t in xtrav(xml.root,
	{_name='types'}, {_name='type', category={'struct', 'union'}}) do
	if not t.attr.alias then
		local self = vkraw[t.attr.name]
		self.__newindex, self.__raw.newindex = {}, {}
		for mt in xtrav(t, {_name='member'}) do
			local r = transform({}, mt)
			table.insert(self.__newindex, r)
			table.insert(self.__raw.newindex, {name=r.name, value=r.name})
		end
	end
end
--]==]

-- Load in the funcpointers
--[==[ TODO: Disabled for now, needs a decision to be made for conversion's sake.
for t in xtrav(xml.root, {_name='types'}, {_name='type', category='funcpointer'}) do
	local nam = xtrav(t, {_name='name'}, {_type='text'})().value
	local self = vkraw[nam]
	self.__call = {}
	local lastty, text = nil, {}
	for _,mt in ipairs(t.kids) do
		if mt.type == 'text' then table.insert(text, mt.value)
		elseif mt.name == 'type' then
			if lastty then
				text = table.concat(text):gsub('[%s,);]', '')
				local res = {name=text:gsub('[^%w]', ''), type=vkraw[lastty]}
				if res.type == vkraw.char then res._len = 'null-terminated' end
				transform(res, text)
				table.insert(self.__call, res)
			end
			lastty, text = xtrav(mt, {_type='text'})().value, {}
		end
	end
	if lastty then
		text = table.concat(text):gsub('[%s,);]', '')
		local res = {name=text:gsub('[^%w]', ''), type=vkraw[lastty]}
		transform(res, text)
		table.insert(self.__call, res)
	end
end
--]==]

-- Load in the commands (these all go to Vk)
vk.Vk.__index = {}
for t in xtrav(xml.root, {_name='commands'}, {_name='command'}) do
	if not t.attr.alias then
		local out = {type = {__call = {}, __raw={}}}
		for par in xtrav(t, {_name='param'}) do
			local r = transform({}, par)
			table.insert(out.type.__call, r)
		end

		local pro = transform({}, xtrav(t, {_name='proto'})())
		out.name, out.type.__raw.C = pro.name, 'PFN_'..pro.name
		out.type.__raw.call = 'Vv_VK_'..out.name
		pro.name, pro.ret, pro.mainret = nil, true, true

		vk.__customheader = (vk.__customheader or '')
			..'#define Vv_VK_'..out.name..'(_f, ...) _f(__VA_ARGS__)\n'

		if pro.type == vkraw.void then out.type.__call.nomainret = true else
			table.insert(out.type.__call, pro)
		end

		table.insert(vk.Vk.__index, out)
	else
		table.insert(vk.Vk.__index, {name=t.attr.name, aliasof=t.attr.alias})
	end
end

-- Figure out the C ifdef's for everything
local cmds, ifdefs = {}, {}
for _,c in ipairs(vk.Vk.__index) do cmds[c.name] = c.type or cmds[c.aliasof] end
for ext in xtrav(xml.root, {_name='extensions'}, {_name='extension'}) do
	for et in xtrav(ext, {_name='require'}, {_name='command'}) do
		local t = cmds[et.attr.name]
		assert(t, 'No vkraw for '..et.attr.name)
		if not ifdefs[t] then ifdefs[t] = {} end
		table.insert(ifdefs[t], ext.attr.name)
		if et.parent.attr.extension then
			table.insert(ifdefs[t], et.parent.attr.extension)
		end
		ifdefs[t].otherwise = 'PFN_vkVoidFunction'
	end
end
for et in xtrav(xml.root, {_name='feature'}, {_name='require'},
	{_name='command'}) do
	if not et.attr.name:match '^[Vv][Kk]_' then
		local t = cmds[et.attr.name]
		assert(t, 'No vkraw for '..et.attr.name)
		ifdefs[t] = nil
	end
end

-- Add them as custom header lines to the resulting header
for t,consts in pairs(ifdefs) do
	for i,v in ipairs(consts) do consts[i] = '!defined('..v..')' end
	vk.__customheader = (vk.__customheader or '')
		..'#if '..table.concat(consts, ' || ')..'\n'
		..'typedef '..consts.otherwise..' '..t.__raw.C..';\n'
		..'#endif\n'
end

-- Return the resulting spec
return vk
