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

-- This piece builds a tree to represent the types
local types = {}
local function regtype(tt)
	local nam = tt.attr.name or first(tt,{name='name'},{type='text'}).value
	local desc = {}
	types[nam] = desc
	if tt.attr.category == 'handle' then
		desc.cat = 'handle'
	elseif tt.attr.category == 'enum' then
		desc.cat = 'enum'
	elseif tt.attr.category == 'bitmask' then
		desc.cat = 'bitmask'
	elseif tt.attr.category == 'struct' then
		desc.cat = 'struct'
	elseif tt.attr.category == 'union' then
		desc.cat = 'union'
	elseif tt.attr.category == 'basetype'
		or tt.attr.requires == 'vk_platform' then
		desc.cat = 'basetype'	-- For us, basic C types are basetypes
	end
end

for _,tt in cpairs(first(dom.root, {name='types'}), {name='type'}) do
	regtype(tt)
end

-- This piece gathers some basic info on the commands, specifically the params
local cmds = {}
for _,ct in cpairs(first(dom.root, {name='commands'}), {name='command'}) do
	local nam = first(ct, {name='proto'}, {name='name'},
		{type='text'}).value
	local desc = {consts=cmdconsts[nam]}
	cmds[nam] = desc
	desc.ret = first(ct, {name='proto'}, {name='type'},
		{type='text'}).value
	local arg = 1
	desc.rets,desc.retenums = {},{}
	for _,par in cpairs(ct, {name='param'}) do
		local pd = {
			name=first(par, {name='name'}, {type='text'}).value,
			type=first(par, {name='type'}, {type='text'}).value,
			len=par.attr.len,
			ptr=0,
		}
		local arr
		for i,t in cpairs(par, {type='text'}) do
			pd.ptr = pd.ptr + #string.gsub(t.value,
				'[^%*]', '')
			if string.find(t.value, '%[') then arr = i end
		end
		if arr then
			if string.find(par.kids[arr].value, ']') then
				pd.arr = string.match(par.kids[arr].value,
					'%[(.+)]')
			else
				for _,t in cpairs(par.kids[arr+1],
					{type='text'}) do
					pd.arr = pd.arr .. t.value
				end
			end
		end
		pd.islen = false
		for _,other in cpairs(ct, {name='param'}) do
			if other.attr.len == pd.name then
				pd.islen = true
				break
			end
		end
		pd.arg = arg
		if not pd.islen then arg = arg + 1 end
		table.insert(desc, pd)
		desc[pd] = #desc
		desc[pd.name] = pd
	end
	desc.rets = {}
	for i,pd in ipairs(desc) do
		pd.lenpar = pd.len and desc[pd.len]
		if pd.ptr == 1  then
			if types[pd.type].cat == 'basetype' then
				table.insert(desc.rets, i)
				pd.ret = true
			elseif pd.len then
				if not pd.lenpar then
					print('Huh?',pd.type,pd.name,pd.len)
					print(desc[pd.len])
				end
				table.insert(desc.rets, i)
				pd.ret = true
			end
		end
	end
end

-- This function places code to create and fill a variable reasonably
local function setup(par, nams, neighbors, nam, cleanup)
	if not nam then
		nam = 'x'..(#nams+1)
		nams[#nams+1] = nam
		out('\t'..par.type..string.rep('*', par.ptr)..' '..nam
			..(par.arr and '['..par.arr..']' or '')..';');
	end
	if par.islen then
		if par.ptr == 0 then
			if par.lenpar and par.lenpar.ret then
				-- Then this is the len of some returned blob
				out('\t'..nam..' = lua_tointeger(L, -1);')
			else
				out('\tlua_len(L, -1);')
				out('\t'..nam..' = lua_tointeger(L, -1);')
				out('\tlua_pop(L, 1);')
			end
		elseif par.ptr == 1 then
			-- In this case, this param is part of a var-len return
		else error('ISLEN') end
	elseif par.arr then
		out('\tfor(int i=0; i<'..par.arr..'; i++) {')
		setup({
			type=par.type,
			name=par.name,
			ptr=par.ptr, len=par.len,
		}, nams, neighbors, nam..'[i]', cleanup)
		out('\t}')
	elseif par.ret then
		if types[par.type].cat == 'handle' then
			out('\t'..nam..' = lua_newuserdata(L, sizeof('..par.type..'));')
		elseif types[par.type].cat == 'basetype' then
			out('\t'..nam..' = malloc(sizeof('..par.type..'));')
		end
	elseif types[par.type].cat == 'handle' then
		out('\t'..nam..' = luaL_checkudata(L, -1, "'..par.type..'");')
	elseif types[par.type].cat == 'basetype' then
		if par.ptr == 1 then
			-- This is acutally a return param.
			out('\t'..nam..' = malloc(sizeof('..par.type..'));')
		elseif par.type == 'uint32_t' then
			out('\t'..nam..' = lua_tointeger(L, -1);')
		else
			print('Unhandled basetype: '..par.type..'!')
		end
	else
		out('\t// SETUP '..nam..' ('..(types[par.type].cat or 'BASE')
			..')')
	end
	return nam
end

-- Now we stitch all that together into a nice and huge C file
out([[
// WARNING: Generated file. Do not edit manually.

#ifdef Vv_ENABLE_VULKAN

#include <stdlib.h>

#include "lua.h"
#include "vivacious/vulkan.h"
]])

for nam,cmd in pairs(cmds) do
	local strs = {}
	for c in pairs(cmd.consts) do table.insert(strs, 'defined('..c..')') end
	out([[
#if ]]..table.concat(strs, ' | ')..[[ //
static int l_]]..nam..[[(lua_State* L) {
	lua_settop(L, ]]..cmd[#cmd].arg..[[);]])
	local nams,args,cleanup = {}, {}, {ret=0}
	for i,par in ipairs(cmd) do
		out('\tlua_pushvalue(L, '..par.arg..');')
		table.insert(args, setup(par, nams, cmd, nil, cleanup, true))
		out('\tlua_pop(L, 1);')
	end
	if cmd.ret == 'VkResult' then
		out('\tVkResult ret =')
	end
	out('\t'..nam..'('..table.concat(args, ', ')..');')
	out(table.concat(cleanup, '\n'))
	for _,r in ipairs(cmd.rets) do
		r = cmd[r]
		out('// RETURN '..r.type..string.rep('*', r.ptr)..' '..r.name)
	end
	out([[
	return 0;
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
