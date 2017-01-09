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

package.path = package.path..';'..arg[2]..'/?.lua'
local trav = require('traversal')
local cpairs, first = trav.cpairs, trav.first

local xml = io.open(arg[2]..'/vk.xml', 'r'):read('a')
local dom = require('slaxdom'):dom(xml, {stripWhitespace=true})

local outtab = {}
local waserr = 0
local function out(s) table.insert(outtab, s) end
local function derror(err) print(err) ; waserr = waserr + 1 end

local function fout(s, t)
	for k,v in pairs(t) do
		s = string.gsub(s, '`'..k..'`', v)
	end
	out(s)
end

local function bmfixes(name, protect)
	-- If this is from an extension, remove that suffix
	local ext = ''
	if protect then
		ext = '_'..string.match(protect, '^VK_(%u+)')
	end

	-- First we determine and remove the author/extension suffix
	local suffix = string.match(name, '(%u+)$')
	if suffix then
		name = string.match(name, '(.*)'..suffix)
		suffix = '_'..suffix
	else
		suffix = ''
	end

	-- Take off the FlagBits suffix on the type name
	if string.sub(name, -8) == 'FlagBits' then
		name = string.sub(name, 1, -9)
	else error(name) end

	-- Now we convert the CamelCase to CAPITAL_UNDERSCORES
	name = string.gsub(name, '(%u)', '_%1')		-- Add underscores
	name = string.sub(name, 2)	-- Remove the extra first _
	name = string.upper(name)	-- Uppercase it all

	return '^'..name..'_([%w_]-)'..suffix..ext..'$'
end

local function bm2typ(bm)
	local ext = string.match(bm, '(%u+)$')
	if ext then bm = string.sub(bm, 1, -#ext-1)
	else ext = '' end
	return string.sub(bm, 1, -9)..'Flags'..ext
end

local function typ2bm(typ)
	local ext = string.match(typ, '(%u+)$')
	if ext then typ = string.sub(typ, 1, -#ext-1)
	else ext = '' end
	return string.sub(typ, 1, -6)..'FlagBits'..ext
end

local bmvs, bmcs = {},{}
local function addbm(bm, const, protect)
	if not bmvs[bm] then bmvs[bm] = {} end
	if not bmcs[bm] then bmcs[bm] = {} end
	local n = string.match(const, bmfixes(bm, protect))
	if string.sub(n, -4) == '_BIT' then	-- Not all consts have a suffix
		n = string.sub(n, 1, -4)
	end
--[[
	if string.sub(n, -4) == '_KHR' then	-- For VK_EXT_debug_report
		n = string.sub(n, 1, -4)
	end
--]]
	n = string.lower(n)
	bmvs[bm][const] = n
	bmcs[bm][const] = protect
end

for _,es in cpairs(dom.root, {name='enums'}) do
	if es.attr.type == 'bitmask' then	-- We only handle bitmasks here
		local fix = bmfixes(es.attr.name)
		for _,e in cpairs(es, {name='enum'}) do
			if e.attr.bitpos then
				-- Some bitmasks have "convenience" constants,
				-- which are OR'd other values. We don't care.
				addbm(es.attr.name, e.attr.name)
			end
		end
	end
end

for _,ext in cpairs(first(dom.root, {name='extensions'}), {name='extension'}) do
	if ext.attr.supported == 'vulkan' then
	for _,r in cpairs(ext, {name='require'}) do
		for _,e in cpairs(r, {name='enum'}) do
			if e.attr.extends and bmvs[e.attr.extends] then
				addbm(e.attr.extends, e.attr.name,
					ext.attr.name)
			end
		end
	end
	end
end

out([[
// WARNING: Generated file. Do not edit manually.
// This file is include'd into lvulkan.c. Files were split for readability.

#ifdef IN_LVULKAN

]])

for e,vs in pairs(bmvs) do
	out('static const char* '..e..'_names[] = {')
	for c,n in pairs(vs) do
		if bmcs[e][c] then out('#ifdef '..bmcs[e][c]) end
		out('\t"'..n..'",')
		if bmcs[e][c] then out('#endif') end
	end
	out('\tNULL};')

	out('static const '..e..' '..e..'_values[] = {')
	for c,n in pairs(vs) do
		if bmcs[e][c] then out('#ifdef '..bmcs[e][c]) end
		out('\t'..c..',')
		if bmcs[e][c] then out('#endif') end
	end
	out('\t0};')

	local t = bm2typ(e)

	fout([[
#define size_`type`(L, O)
#define to_`type`(L, D, R) ({ \
	(D) = 0; \
	for(int i=0; i<sizeof(`enum`_values)/sizeof(`enum`); i++) { \
		lua_getfield(L, -1, `enum`_names[i]); \
		if(lua_toboolean(L, -1)) (D) |= `enum`_values[i]; \
		lua_pop(L, 1); \
	} \
})
#define push_`type`(L, D) ({ \
	lua_newtable(L); \
	for(int i=0; i<sizeof(`enum`_values)/sizeof(`enum`); i++) { \
		lua_pushboolean(L, (D) & `enum`_values[i]); \
		lua_setfield(L, -2, `enum`_names[i]); \
	} \
})
#define size_`enum`(L) size_`type`(L)
#define to_`enum`(L, D, R) to_`type`(L, D, R)
#define push_`enum`(L, D) push_`type`(L, D)

]], {type=t, enum=e})
end

out('')

-- There are a bunch of bitmasks reserved for future use. In general, they don't
-- have an <enums> tag. Thus, we must hunt them down using their <type> tag.
for _,t in cpairs(first(dom.root, {name="types"}), {name='type'}) do
	if t.attr.category == 'bitmask' then
		local t = first(t, {name='name'}, {type='text'}).value
		local n = typ2bm(t)
		if not bmvs[n] then
			out('#define size_'..t..'(L, O)')
			out('#define to_'..t..'(L, D, R) ({ (D) = 0; })')
			out('#define push_'..t..'(L, D) lua_pushnil(L)')
		end
	end
end

out('#endif // IN_LVULKAN')

if waserr > 0 then
	error('Errors happened: '..waserr..' to be exact!')
end

local f = io.open(arg[1], 'w')
f:write(table.concat(outtab, '\n'))
f:close()
