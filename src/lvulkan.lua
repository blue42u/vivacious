--[========================================================================[
   Copyright 2016 Jonathon Anderson

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

-- This piece figures out when a command will be availible at compile-time
local cmdconsts = {}
for _,feat in cpairs(dom.root, {name='feature'}) do
	local const = feat.attr.name
	for _,r in cpairs(feat, {name='require'}) do
		for _,c in cpairs(r, {name='command'}) do
			local cmd = c.attr.name
			cmdconsts[cmd] = cmdconsts[cmd] or {}
			cmdconsts[cmd][const] = true
		end
	end
end
for _,ext in cpairs(first(dom.root, {name='extensions'}), {name='extension'}) do
	local const = ext.attr.name
	for _,r in cpairs(ext, {name='require'}) do
		for _,c in cpairs(r, {name='command'}) do
			local cmd = c.attr.name
			cmdconsts[cmd] = cmdconsts[cmd] or {}
			cmdconsts[cmd][const] = true
		end
	end
end

-- This piece concatinates all text tags in the tree with the given root
local function tconcat(...)
	local out = {}
	for _,tag in ipairs(table.pack(...)) do
		if tag.kids then
			for _,t in ipairs(tag.kids) do
				table.insert(out, tconcat(t))
			end
		elseif tag.type == 'text' then
			table.insert(out, tag.value)
		end
	end
	return table.concat(out)
end

-- This piece gathers info on either a param or a member
local function tomem(tag)
	local mem = {}
	local typei, namei
	for i,t in ipairs(tag.kids) do
		if t.name == 'type' then typei = i end
		if t.name == 'name' then namei = i end
	end
	local pretype = tconcat(table.unpack(tag.kids, 1, typei-1))
	local posttype = tconcat(table.unpack(tag.kids, typei+1, namei-1))
	local postname = tconcat(table.unpack(tag.kids, namei+1))
	mem.type = tconcat(tag.kids[typei])
	mem.name = tconcat(tag.kids[namei])
	mem.len = tag.attr.len
	if pretype == 'const' then mem.isconst = true
	elseif pretype == 'struct' then mem.needstruct = true
	elseif pretype ~= '' then
		error('Bad pretype?: '..pretype..' '..mem.name)
	end
	if string.sub(postname, 1, 1) == '[' then
		mem.arr = string.match(postname, '%[(.*)%]')
	elseif postname ~= '' then
		error('Bad postname?: '..postname..' '..mem.name)
	end
	if posttype == '* const*' then posttype = '**' end
	if string.gsub(posttype, '[^%*]', '') ~= posttype then
		error('Bad posttype?: '..posttype..' '..mem.name)
	end
	mem.ptr = #posttype
	if mem.type == 'char' and mem.ptr > 0 then
		mem.ptr = mem.ptr-1
		mem.type = 'string'
	end
	if mem.type == 'void' and mem.ptr > 0 then
		mem.ptr = mem.ptr-1
		mem.type = 'voidptr'
	end
	return mem
end

-- This piece gathers data about types
local function totyp(tag)
	local typ = {}
	typ.name = tag.attr.name or first(tag,{name='name'},{type='text'}).value
	if tag.attr.category == 'handle' then
		typ.cat = 'handle'
	elseif tag.attr.category == 'enum' then
		typ.cat = 'enum'
	elseif tag.attr.category == 'bitmask' then
		typ.cat = 'bitmask'
	elseif tag.attr.category == 'struct' then
		typ.cat = 'struct'
		typ.mems = {}
		for _,mem in cpairs(tag, {name='member'}) do
			table.insert(typ.mems, tomem(mem))
		end
	elseif tag.attr.category == 'union' then
		typ.cat = 'union'
	elseif tag.attr.category == 'basetype'
		or tag.attr.requires == 'vk_platform' then
		typ.cat = 'basetype'	-- For us, basic C types are basetypes
	end
	return typ
end

local types = {}
for _,tt in cpairs(first(dom.root, {name='types'}), {name='type'}) do
	tt = totyp(tt)
	types[tt.name] = tt
end

-- This piece gathers enum data, and the constants needed for that
local function enumfix(name)
	if name == 'VkResult' then return 'VK','' end	-- Odd exception
	local suf = string.match(name, '(%u+)$')
	if suf then
		suf = '_'..suf
		name = string.sub(name, 1, -#suf)
	end
	name = string.gsub(name, '(%u)', '_%1')	-- CamelCase to under_scores
	name = string.sub(name, 2)	-- Remove the first underscore
	name = string.upper(name)	-- Uppercase for C #defines
	return name, suf or ''
end

local enums = {}
for _,et in cpairs(dom.root, {name='enums'}) do
	local enum = {}
	enum.name = et.attr.name
	enum.prefix,enum.suffix = enumfix(enum.name)
	enum.type = et.attr.type
	enums[enum.name] = enum
	table.insert(enums, enum)
	for _,e in cpairs(et, {name='enum'}) do
		local v = {}
		v.value = e.attr.value or 2^e.attr.bitpos
		v.value = math.tointeger(v.value)
		v.name = string.sub(e.attr.name, #enum.prefix+2)
		v.name = string.sub(v.name, 1, -#enum.suffix-1)
		v.name = string.lower(v.name)
		table.insert(enum, v)
	end
end
local base,range = 1000000000, 1000	-- These values are from the Style Guide
for _,ext in cpairs(first(dom.root, {name='extensions'}), {name='extension'}) do
	for _,rt in cpairs(ext, {name='require'}) do
		for _,e in cpairs(rt, {name='enum'}) do
			local enum = enums[e.attr.extends]
			if e.attr.extends and enum then
				local v = {}
				if e.attr.offset then
					v.value = (ext.attr.number-1)*range
						+ base + e.attr.offset
				elseif e.attr.value then
					v.value = e.attr.value
				else
					v.value = 2^e.attr.bitpos
				end
				v.value = math.tointeger(v.value)
				if e.attr.dir == '-' then v.value = -v.value end
				v.name = string.sub(e.attr.name, #enum.prefix+2)
				v.name = string.lower(v.name)
				v.const = ext.attr.name
				table.insert(enum, v)
			end
		end
	end
end

-- This piece gathers some basic info on the commands, specifically the params
local cmds = {}
for _,ct in cpairs(first(dom.root, {name='commands'}), {name='command'}) do
	local cmd = {}
	cmd.name = first(ct, {name='proto'}, {name='name'}, {type='text'}).value
	table.insert(cmds, cmd)
	cmd.consts = cmdconsts[cmd.name]
	cmd.ret = first(ct, {name='proto'}, {name='type'}, {type='text'}).value
	cmd.params = {}		-- These are the C parameters to the cmd
	local lens = {}
	for _,par in cpairs(ct, {name='param'}) do
		par = tomem(par)
		if not par.isconst and par.ptr > 0 then
			par.isret = true
		end
		if par.len then
			lens[par.len] = true
		end
		table.insert(cmd.params, par)
	end
	cmd.args = {}		-- These are the Lua arguments to the cmd
	cmd.rets = {}		-- These are the Lua return values - VkResult
	for _,par in ipairs(cmd.params) do
		if not lens[par.name] and not par.isret then
			table.insert(cmd.args, par)
		elseif par.isret then
			table.insert(cmd.rets, par)
			par.retind = #cmd.rets
		end
	end
end

-- This piece builds the framework of pointers and arrays for an argument
local function setup(type, name, arr, nodef)
	if not nodef then
		out('\t'..type..' '..name..(arr and '['..arr..']' or '')..';')
	end
	if arr then out('\tfor(int i=0; i<'..arr..'; i++) {') end
	if types[type] and types[type].cat == 'struct' then
		for _,mem in ipairs(types[type].mems) do
			if mem.ptr == 0 then
				setup(mem.type, name..'.'..mem.name, mem.arr,
					true)
			elseif mem.ptr == 1 then
				local memname = string.gsub(name, '%.', '_')
					..'_'..mem.name
				setup(mem.type, memname, mem.arr)
				out('\t'..name..'.'..mem.name..' = &'
					..memname..';')
			else
				error(mem.type..string.rep('*', mem.ptr)
					..' '..mem.name)
			end
		end
	end
	if arr then out('\t}') end
end

-- Now we stitch all that together into a nice and huge C file
out([[
// WARNING: Generated file. Do not edit manually.

#ifdef Vv_ENABLE_VULKAN

#include <stdlib.h>
#include <string.h>

#include "lua.h"
#include "vivacious/vulkan.h"

typedef const char* string;
typedef void* voidptr;
]])
for _,e in ipairs(enums) do
	if e.type == 'enum' then
	out('static void push_'..e.name..'(lua_State* L, '..e.name..' val) {')
	for _,v in ipairs(e) do
		if v.const then out('#ifdef '..v.const) end
		out('\tif(val == '..v.value..') lua_pushliteral(L, "'
			..v.name..'"); return;')
		if v.const then out('#endif // '..v.const) end
	end
	out('}')

	out('static '..e.name..' to_'..e.name..'(lua_State* L, int ind) {')
	out('\tint tmp;')
	out('\tind = lua_absindex(L, ind);')
	for _,v in ipairs(e) do
		if v.const then out('#ifdef '..v.const) end
		out('\tlua_pushliteral(L, "'..v.name..'");')
		out('\ttmp = lua_compare(L, -1, ind, LUA_OPEQ);')
		out('\tlua_pop(L, 1);')
		out('\tif(tmp) return '..v.value..';')
		if v.const then out('#endif // '..v.const) end
	end
	out('\treturn 0;\n}')
	end
end
out([[
static int vkerror(lua_State* L, VkResult r) {
	push_VkResult(L, r);
	return luaL_error(L, "Vulkan error: %s!", lua_tostring(L, -1));
}
]])

for _,cmd in ipairs(cmds) do
	local strs = {}
	for c in pairs(cmd.consts) do table.insert(strs, 'defined('..c..')') end
	out([[
#if ]]..table.concat(strs, ' | ')..[[ //
static int l_]]..cmd.name..[[(lua_State* L) {]])
	local params = {}
	for _,par in ipairs(cmd.params) do
		if par.ptr == 0 then
			setup(par.type, par.name, par.arr)
			table.insert(params, par.name)
		elseif par.ptr == 1 then
			setup(par.type, par.name, par.arr)
			table.insert(params, '&'..par.name)
		else error('Ptr too big (again!)') end
	end
	out('\n\tlua_settop(L, '..#cmd.args..');\n')
	for i,arg in ipairs(cmd.args) do
		out('\tlua_pushvalue(L, '..i..');')
		out('// ARG '..arg.name..' '..arg.type..string.rep('*',arg.ptr)
			..(arg.arr and '['..arg.arr..']' or ''))
		out('\tlua_pop(L, 1);')
		out('')
	end
	out('\tlua_settop(L, '..#cmd.args+#cmd.rets..');\n')
	for i,ret in ipairs(cmd.rets) do
		out('// RET '..ret.name..' '..ret.type..string.rep('*',ret.ptr))
		out('')
	end
	out('')
	if cmd.ret == 'VkResult' then
		out('\tVkResult r = '..cmd.name..'('
			..table.concat(params, ', ')..');')
		out('\tif(r < 0) return vkerror(L, r);')
		out('\tlua_pushstring(L, "");')
		out('\treturn '..1+#cmd.rets..';')
	else
		out('\t'..cmd.name..'('..table.concat(params, ', ')..');')
		out('\treturn '..#cmd.rets..';')
	end
	out([[
}
#endif
]])
end

out([[
void loadLVulkan(lua_State* L) {
	lua_pushnil(L);
}

#endif // vV_ENABLE_VULKAN
]])

if waserr > 0 then
	error('Errors happened: '..waserr..' to be exact!')
end

local f = io.open(arg[1], 'w')
f:write(table.concat(outtab, '\n'))
f:close()
