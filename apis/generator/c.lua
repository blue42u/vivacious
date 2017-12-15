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

package.path = './?.lua'

local function tins(t)
	return t, function(y, x, r)
		if not r then y,x,r = nil,y,x end
		if r then x = string.gsub(x, '~', r) end
		if y then table.insert(t, y, x)
		else table.insert(t, x) end
	end
end

local function simpletype(t, c) return function(w, o)
	if o == nil then w(t..' ~') else w('~', c(o)) end
end end
integer = simpletype('int', function(o) return ('%d'):format(o) end)
index = simpletype('int', function(o) return ('%d'):format(o-1) end)
boolean = simpletype('bool', function(o) return o and 'true' or 'false' end)
size = simpletype('size_t', function(o) return ('%d'):format(o) end)
number = simpletype('float', function(o) return ('%f'):format(o) end)
str = simpletype('const char*', function(o) return o == '' and 'NULL' or ('%q'):format(o) end)
general = simpletype('void*', function(o) return o and error('No format for general ('..tostring(o)..')') or 'NULL' end)
ptr = simpletype('void*', function(o) return o and error'No format for ptr' or 'NULL' end)
function c_external(n) return setmetatable({}, {
		__tostring = function() return n end,
		__add = function(_,b) return c_external('('..n..'+'..tostring(b)..')') end,
		__sub = function(_,b) return c_external('('..n..'-'..tostring(b)..')') end,
		__mul = function(_,b) return c_external('('..n..'*'..tostring(b)..')') end,
		__div = function(_,b) return c_external('('..n..'/'..tostring(b)..')') end,
		__unm = function() return c_external('-('..n..')') end,
		__band = function(_,b) return c_external('('..n..'&'..tostring(b)..')') end,
		__bor = function(_,b) return c_external('('..n..'|'..tostring(b)..')') end,
		__bxor = function(_,b) return c_external('('..n..'^'..tostring(b)..')') end,
		__bnot = function() return c_external('~('..n..')') end,
}) end
function c_rawtype(t) return simpletype(t, tostring) end
function c_bitmask(t) return function(w, o)
	if o == nil then w(t..'* ~')
	elseif not next(o) then w('~', 'NULL')
	else error"c_bitmask doesn't support custom conversions yet" end
end end

function array(arg)
	local st,t = arg.sizetype or size, arg[1]
	return function(w, o)
		if o == nil then
			st(function(s) w(s:gsub('~', '~Cnt')) end)
			t(function(s) w(s:gsub('~', '*~')) end)
		else
			size(function(n,s) w(arg.c_len or n..'Cnt', s) end, #o)
			if #o == 0 then w('~', 'NULL') else
				local tnam
				t(function(s) tnam = s:gsub('~', '[]') end)
				local parts,p = tins{}
				for _,v in ipairs(o) do t(p, v) end
				w('~', '('..tnam..'){'..table.concat(parts, ', ')..'}')
			end
		end
	end
end

function enum(arg)
	local vals = {}
	local lastval = 0
	for _,e in ipairs(arg) do
		if e[2] then lastval, vals[e[1]] = e[2], tostring(e[2])
		else lastval,vals[e[1]] = lastval+1, tostring(lastval+1) end
	end

	return function(w, o)
		if o == nil then
			local parts, p = tins{}
			p('enum {\n')
			for _,e in ipairs(arg) do
				p('\t~='..vals[e[1]]:gsub('\n', '\n\t')..',\n', e[1])
			end
			p('} ~')
			return table.concat(parts, '')
		else w('~', vals[o] or error(tostring(o)..' not a valid value!')) end
	end
end

function bitmask(arg)
	local vals = {}
	local lastval = 0
	for _,e in ipairs(arg) do
		if e[2] then lastval, vals[e[1]] = e[2], tostring(e[2])
		else lastval,vals[e[1]] = lastval+1, tostring(lastval<<1) end
	end

	return function(w, o)
		if o == nil then
			local parts, p = tins{}
			p('enum {\n')
			for _,e in ipairs(arg) do
				p('\t~='..vals[e[1]]:gsub('\n', '\n\t')..',\n', e[1])
			end
			p('} ~')
			return table.concat(parts, '')
		else
			local v = c_external'0'
			for b in pairs(o) do v = v | (vals[b] or error(tostring(b)..' not valid in bitmask!')) end
			w('~', tostring(v))
		end
	end
end

function callback(arg)
	local aend
	for i,a in ipairs(arg) do
		if aend then assert(type(a[1]) ~= 'string')
		elseif type(a[1]) ~= 'string' then aend = i-1 end
	end
	aend = aend or #arg

	local args = table.move(arg, 1, aend, 1, {})
	local rets = table.move(arg, aend+1, #arg, 1, {})

	local cmain
	for i,r in ipairs(rets) do
		if r.c_main then assert(not cmain); cmain = i end
	end
	local ret = function(w,o) assert(o==nil); w('void ~') end
	if #rets > 1 then ret = table.remove(rets, cmain or 1)[1] end

	return function(w, o)
		if o == nil then
			local parts,p = tins{}
			for _,a in ipairs(args) do a[2](function(s)
				p('\t'..string.gsub(s, '\n', '\n\t'), a[1]) end) end
			for _,r in ipairs(rets) do r[1](function(s)
				p('\t'..string.gsub(s, '\n', '\n\t'), '*') end) end

			local me
			ret(function(s)
				if me then p(s, '*') else me = s:gsub('~', '(*~)') end
			end)

			w(me..'(\n'..table.concat(parts, ',\n')..')')
		else w('~', 'NULL') end
	end
end

function compound(arg)
	local vers = {}
	for v,t in pairs(arg) do
		local M,m,p = string.match(v, 'v(%d+)_(%d+)_(%d+)')
		if M then table.insert(vers, {M=M, m=m, p=p, t=t}) end
	end
	table.sort(vers, function(a,b)
		if a.M ~= b.M then return a.M < b.M
		elseif a.m ~= b.m then return a.m < b.m
		else return a.p < b.p end
	end)

	local mems = {}
	for _,v in ipairs(vers) do for _,e in ipairs(v.t) do
		table.insert(mems, e)
		mems[e[1]] = e
	end end

	local me = {structname = '', extraptr=not arg.static}
	function me:__call(w, o)
		local parts,p = tins{}
		if o == nil then
			for _,e in ipairs(mems) do
				e[2](function(s) p('\t'..s:gsub('\n', '\n\t')..';\n', e[1]) end)
			end
			local pre = me.structname..' {\n'
			local post = me.novar and '}' or '}'..(arg.static and '' or '*')..' ~'
			w(pre..table.concat(parts, '')..post)
		else
			for k,v in pairs(o) do
				local m = mems[k]
				if m then m[2](function(n,s) p('.'..n..' = '..s, m[1]) end, v) end
			end
			w('~', (arg.static and '' or '&')..'('..me.structname..'){'..table.concat(parts, ', ')..'}')
		end
	end
	return setmetatable({}, me)
end

-- Now for the Object bits
local apis = setmetatable({}, {__index=function(self, k)
	self[k] = {types = {}, meths={}, creates={}}
	return self[k]
end})

local function object(arg, name, api, top)
	local meta,meths,tdefs = {name=name},{},{}

	arg.v0_0_0 = arg.v0_0_0 or {}
	local cargs = {}
	for i,obj in ipairs(arg) do
		cargs[i] = getmetatable(obj).name
		arg.v0_0_0[i] = {string.lower(getmetatable(obj).name), obj}
	end
	cargs = table.concat(cargs, ', ')

	local myself = setmetatable({}, meta)
	function meta:__index(k)
		local M,m,p = string.match(tostring(k), 'v(%d+)_(%d+)_(%d+)')
		if M then
			return setmetatable({},
				{__newindex=function(_,k2,v) table.insert(meths, {v=k, a=v, n=k2}) end})
		elseif k == 'typedef' then
			return setmetatable({}, {__newindex=function(_,n,v)
				local vn = 'Vv'..n
				if getmetatable(v) then getmetatable(v).structname = 'struct '..vn end
				local exname
				table.insert(tdefs, function(w)
					if not exname then
						v(function(s) w('typedef '..string.gsub(s, '~', vn)..';') end)
						w''
					end
				end)
				rawset(myself, n, setmetatable({}, {
					__call=function(_,w,o)
						if o == nil then w((exname or vn)..' ~') else v(w,o) end end,
					__newindex=function(_,k,def)
						if k == 'default' then
							table.insert(tdefs, function(w)
								v(function(n,s)
									local x = ''
									if getmetatable(v) and getmetatable(v).extraptr and exname then
										x = '*'
									end
									w(('#define ~(...) ({ ~'..x..' _x = '..s..'; VvMAGIC(__VA_ARGS__); _x; })')
										:gsub('~', exname or vn))
									w''
								end, def)
							end)
						elseif k == 'c_external' then
							exname = def
							if getmetatable(v) then
								getmetatable(v).structname = exname
								getmetatable(v).external = true
							end
						else error('Unknown typedef command '..k) end
					end}))
			end})
		else error('Attempt to reference subtype '..k) end
	end
	function meta:__newindex(k, a)
		a.v0_0_0 = a.v0_0_0 or {}
		table.insert(a.v0_0_0, {'parent', myself})
		assert(#a == 0)
		rawset(self, k, object(a, name..k, api, false))
	end
	function meta:__call(w, o)
		if o == nil then w('Vv'..name..' ~')
		else w('~', 'NULL') end
	end

	table.insert(api, function(w)
		-- Construct the _M methods sub-struct
		local mcomp = {}
		table.sort(meths, function(a,b) return a.n < b.n end)
		for _,m in ipairs(meths) do
			table.insert(m.a, 1, {'self', myself})
			mcomp[m.v] = mcomp[m.v] or {}
			table.insert(mcomp[m.v], {m.n, callback(m.a)})
		end
		mcomp = compound(mcomp)
		getmetatable(mcomp).structname = 'struct Vv'..name..'_M'
		local function mc(w,o) mcomp(function(s) w('const '..s) end) end

		-- Write out the typedefs
		for _,t in ipairs(tdefs) do t(w) end

		-- Write out the full structure
		arg.v0_0_0 = arg.v0_0_0 or {}
		table.insert(arg.v0_0_0, 1, {'const _M', mc})
		if arg.wrapper then table.insert(arg.v0_0_0, 1, {'_R', arg.wrapper}) end
		arg.v1000000000_0_0 = {{'_I', c_rawtype('struct Vv'..name..'_I')}}
		local comp = compound(arg)
		getmetatable(comp).structname = 'struct Vv'..name
		getmetatable(comp).novar = true
		w('typedef struct Vv'..name..'* Vv'..name..';')
		comp(function(s) w(s..';') end)

		-- Write out the creation function
		if top then w('Vv'..name..' vVcreate'..name..'(void*);') end

		-- Write out all the method macros
		for _,m in ipairs(meths) do
			w('#define vV'..m.n..'(_S, ...) ({ __typeof__(_S) _s = (_S); '
				..'_s->_M->'..m.n..'(_s, __VA_ARGS__); })')
		end
	end)

	return myself
end

local outdir = table.remove(arg, 1)..'/'
for _,a in ipairs(arg) do
	apis[a] = {pres={}}
	local env = setmetatable({}, {__index = _G,
		__newindex = function(_, k, v)
			if k == 'c_define' then table.insert(apis[a].pres, '#define '..v)
			elseif k == 'c_include' then table.insert(apis[a].pres, '#include <'..v..'>')
			else rawset(_G, k, object(v, k, apis[a], true)) end
		end})
	package.preload[a] = loadfile(a..'.lua', 't', env)
end
for _,a in ipairs(arg) do require(a) end

-- First write up all of the API headers
for an,api in pairs(apis) do
	local f = io.open(outdir..an..'.h', 'w')
	f:write(([[
// Generated file, do not edit directly, edit apis/*.lua instead
#ifndef H_vivacious_~
#define H_vivacious_~

#include "core.h"
]]):gsub('~', an)..'')

	for _,p in ipairs(api.pres) do
		f:write(p..'\n')
	end
	f:write'\n'

	-- Run all the collected writing functions
	for _,o in ipairs(api) do
		o(function(s) f:write(s..'\n') end)
		f:write'\n'
	end

	f:write('#endif // H_vivacious_'..an)
	f:close()
end

-- Then write up the core.h
do
	local f = io.open(outdir..'core.h', 'w')
	f:write[[
// Generated from apis/generator/c.lua, do not edit
#ifndef H_vivacious_core
#define H_vivacious_core

#include <stdlib.h>
#include <stdbool.h>

#ifndef __GNUC__
#define __typeof__ typeof
#endif

#define Vv_LEN(...) sizeof(__VA_ARGS__)/sizeof((__VA_ARGS__)[0])
#define Vv_ARRAY(N, ...) .N##Cnt = Vv_LEN((__VA_ARGS__)), .N=(__VA_ARGS__)

#define VvMAGIC_FA_1(what, x, ...) what(x);
]]
	local maxmagic = 100
	for i=2,maxmagic do
		f:write('#define VvMAGIC_FA_'..i..'(what, x, ...) what(x); VvMAGIC_FA_'..(i-1)..'(__VA_ARGS__)\n')
	end
	f:write'#define VvMAGIC_NA(...) VvMAGIC_AN(__VA_ARGS__'
	for i=maxmagic,0,-1 do f:write(','..i) end
	f:write')\n#define VvMAGIC_AN('
	for i=1,maxmagic do f:write('_'..i..',') end
	f:write[[N, ...) N

#define VvMAGIC_C(A, B) VvMAGIC_C2(A, B)
#define VvMAGIC_C2(A, B) A##B
#define VvMAGIC_FA(what, ...) VvMAGIC_C(VvMAGIC_FA_, VvMAGIC_NA(__VA_ARGS__))(what, __VA_ARGS__)

#define VvMAGIC_x(A) _x A
#define VvMAGIC(...) VvMAGIC_FA(VvMAGIC_x, __VA_ARGS__)

#endif
]]
	f:close()
end

-- And finish up with vivacious.h
do
	local f = io.open(outdir..'vivacious.h', 'w')
	f:write[[
// Generated from apis/generator/c.lua, do not edit
#ifndef H_vivacious_vivacious
#define H_vivacious_vivacious

]]
	for a in pairs(apis) do
		f:write('#include <vivacious/'..a..'.h>\n')
	end
	f:write'\n#endif'
	f:close()
end
