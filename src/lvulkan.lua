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

io.output(arg[1])

local function out(s) io.write(s..'\n') end
local function print(...)
	local t = table.pack(...)
	for i,o in ipairs(t) do t[i] = tostring(o) end
	io.stderr:write(table.concat(t, '\t')..'\n')
end

out([[
// WARNING: Generated file. Do not edit manually.

#ifdef Vv_ENABLE_VULKAN

#include "lua.h"
#include "vivacious/vulkan.h"
]])

local typest = first(dom.root, {name='types'})
local cmdst = first(dom.root, {name='commands'})
for _,t in cpairs(dom.root, {name='feature'}) do
	local reqtypes = {}
	local mems = {}
	local function addtype(type)
		if not reqtypes[type] then
			local t = first(typest, {name='type',attr={name=type}})
			if t and t.attr.category == 'struct' and not
				t.attr.returnedonly then
			reqtypes[type] = 'struct'
			mems[type] = {}
			for _,t in cpairs(t, {name='member'}) do
				local typ = first(t, {name='type'})
				typ = first(typ, {type='text'})
				typ = typ and typ.value
				local nam = first(t, {name='name'})
				nam = first(nam, {type='text'}).value
				local ptr = 0
				for _,t in cpairs(t, {type='text'}) do
					ptr = ptr + #string.gsub(
						t.value, '[^%[%*]', '')
				end
				mems[type][nam] = {
					type=typ, ptr=ptr,
					values=t.attr.values,
				}
				addtype(typ)
			end
			elseif t and t.attr.category == 'enum' then
			reqtypes[type] = 'enum'
			mems[type] = {}
			t = first(dom.root, {name='enums',
				attr={name=type}})
			local pre = type
			if t.attr.type == 'bitmask' and
				string.sub(type, -8) == 'FlagBits' then
				reqtypes[type] = 'bitmask'
				pre = string.sub(type, 1, -9)
			end
			pre = string.gsub(pre, '(%u)', '_%1')
			pre = string.sub(pre, 2)
			pre = string.upper(pre)
			for _,t in cpairs(t, {name='enum'}) do
				local nam = string.match(t.attr.name,
					pre..'(.*)')
				if nam then
					nam = string.sub(nam, 2)
					nam = string.lower(nam)
					mems[type][t.attr.name] = nam
					table.insert(mems[type], t.attr.name)
				end
			end
			end
		end
	end

	for _,t in cpairs(t, {name='require'}) do
		for _,t in cpairs(t, {name='type'}) do
			addtype(t.attr.name)
		end
		for _,t in cpairs(t, {name='command'}) do
			for _,ct in cpairs(cmdst, {name='command'}) do
				if first(ct, {name='proto'}, {name='name'},
					{type='text'}).value == t.attr.name then
					t = ct
					break
				end
			end
			for _,t in cpairs(t, {name='proto'}) do
				t = first(t, {name='type'}, {type='text'})
				if t then
					addtype(t.value)
				end
			end
			for _,t in cpairs(t, {name='param'}) do
				t = first(t, {name='type'}, {type='text'})
				if t then
					addtype(t.value)
				end
			end
		end
	end

	local const = t.attr.name
	local ver = t.attr.number
	out([[
#ifdef ]]..const..[[
]])
	for n in pairs(reqtypes) do
		out('static void fill_'..n..'('..n..'*, lua_State*, int);')
	end
	out([[
]])
	for n,t in pairs(reqtypes) do
		out([[
static void fill_]]..n..[[(]]..n..[[* x, lua_State* L, int ind) {]])
		if t == 'struct' then

		for nam,mem in pairs(mems[n]) do
			local typ = mem.type
			local ptr = mem.ptr
			if reqtypes[typ] and ptr == 0 then
				out('\tlua_getfield(L, ind, "'..nam..'");')
				out('\tfill_'..typ..'(&x->'..nam..', L, -1);')
				out('\tlua_pop(L, 1);')
			elseif typ == 'VkStructureType' then
				out('\tx->'..nam..' = '..mem.values..';')
			else
				print('Unsupported member! '..
					typ..string.rep('*',ptr)..'\t'..
					n..'.'..nam)
			end
		end

		elseif t == 'enum' then

		out('\tconst char* names[] = {')
		for _,const in ipairs(mems[n]) do
			out('\t\t"'..mems[n][const]..'",')
		end
		out('\t"NOTANAME", NULL};')
		out('\tswitch(luaL_checkoption(L, ind, "NOTANAME", names)) {')
		for i,const in ipairs(mems[n]) do
			out('\tcase '..i..': *x = '..const..'; break;')
		end
		out('\tdefault: *x = 0; };')

		elseif t == 'bitmask' then

		out('\t*x = 0;')
		for _,const in ipairs(mems[n]) do
			out('\tlua_getfield(L, ind, "'..mems[n][const]..'");')
			out('\tif(lua_toboolean(L, -1)) *x |= '..const..';')
			out('\tlua_pop(L, 1);')
		end

		else
		out('#error // '..n)
		end
		out('}')
	end
	out([[
#endif // ]]..const..[[

]])
end

out([[
void loadLVulkan(lua_State* L) {
	lua_pushnil(L);
}

#endif // vV_ENABLE_VULKAN
]])
