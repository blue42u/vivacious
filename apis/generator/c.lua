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

local function newtype(ref, conv)
	return function(w, o) if o == nil then ref(w) else conv(w, o) end end
end

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
function integer() return simpletype('int', function(o) return ('%d'):format(o) end) end
function boolean() return simpletype('bool', function(o) return o and 'true' or 'false' end) end

function callback(arg)
	local aend
	for i,a in ipairs(arg) do
		if aend then assert(type(a[1]) ~= 'string')
		elseif type(a[1]) ~= 'string' then aend = i-1 end
	end
	aend = aend or 0

	local args = table.move(arg, 1, aend, 1, {})
	local rets = table.move(arg, aend+1, #arg, 1, {})

	local cmain
	for i,r in ipairs(rets) do
		if r.c_main then assert(not cmain); cmain = i end
	end
	local ret = table.remove(rets, cmain or 1)[1]
		or function(w,o) assert(o==nil); w('void ~') end

	return function(w, o)
		if o == nil then
			local parts,p = tins{}
			for _,a in ipairs(args) do a[2](function(s) p(s, a[1]) end) end
			for _,r in ipairs(rets) do r[1](function(s) p(s, '*') end) end

			local me
			ret(function(s)
				if me then p(s, '*') else me = s:gsub('~', '(*~)') end
			end)

			w(me..'('..table.concat(parts, ', ')..')')
		elseif o then w('~', 'NULL') end
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
		if e[3] then assert(arg.c_typedefname); mems[e[1]] = e end
	end end

	return function(w, o)
		local parts,p = tins{}
		if o == nil then
			for _,e in ipairs(mems) do
				e[2](function(s) p('\t'..s:gsub('\n', '\n\t')..';\n', e[1]) end)
			end
			local pre = 'struct '..(arg.c_structname or '')..' {\n'
			local post = arg.c_novar and '}' or '}* ~'
			w(pre..table.concat(parts, '')..post)
		else
			for k,v in pairs(o) do
				local m = mems[k]
				if m then m[2](function(n,s) p('.'..n..'='..y, m[1]) end, m[3]) end
			end
			w('~', '&('..arg.c_typedefname..'){'..table.concat(parts, ', ')..'}')
		end
	end
end

-- Now for the Object bits
local apis = setmetatable({}, {__index=function(self, k)
	self[k] = {types = {}, meths={}, creates={}}
	return self[k]
end})

local function object(arg, name, api)
	local meta,meths = {name=name},{}

	arg.v0_0_0 = arg.v0_0_0 or {}
	local cargs = {}
	for i,obj in ipairs(arg) do
		cargs[i] = getmetatable(obj).name
		arg.v0_0_0[i] = {getmetatable(obj).name:lower(), obj}
	end
	cargs = table.concat(cargs, ', ')

	local myself = setmetatable({}, meta)
	function meta:__index(k)
		local M,m,p = string.match(tostring(k), 'v(%d+)_(%d+)_(%d+)')
		if M then
			return setmetatable({},
				{__newindex=function(_,k2,v) table.insert(meths, {v=k, a=v, n=k2}) end})
		end
	end
	function meta:__newindex(k, a)
		a.v0_0_0 = a.v0_0_0 or {}
		table.insert(a.v0_0_0, {'parent', myself})
		assert(#a == 0)
		rawset(self, k, object(a, name..k, api))
	end
	function meta:__call(w, o)
		assert(o == nil)
		w('Vv'..name..' ~')
	end

	table.insert(api.objects, function(w)
		local mcomp = {c_structname='Vv'..name..'_M'}
		table.sort(meths, function(a,b) return a.n < b.n end)
		for n,m in pairs(meths) do
			table.insert(m.a, 1, {'self', myself})
			mcomp[m.v] = mcomp[m.v] or {}
			table.insert(mcomp[m.v], {m.n, callback(m.a)})
		end
		mcomp = compound(mcomp)

		arg.v0_0_0 = arg.v0_0_0 or {}
		table.insert(arg.v0_0_0, 1, {'_M', mcomp})
		arg.c_structname = 'Vv'..name
		arg.c_novar = true
		w('typedef struct Vv'..name..'* Vv'..name..';')
		compound(arg)(function(s) w(s..';') end)
	end)

	return myself
end

local outdir = table.remove(arg, 1)..'/'
for _,a in ipairs(arg) do
	apis[a] = {objects={}}
	local env = setmetatable({}, {__index = _G,
		__newindex = function(self, k, v) rawset(self, k, object(v, k, apis[a])) end})
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

#include <vivacious/core.h>

]]):gsub('~', an)..'')

	-- Objects
	for _,o in ipairs(api.objects) do
		o(function(s) f:write(s..'\n') end)
		f:write'\n'
	end

--[=[
	-- Method macros
	f:write('#ifdef Vv_'..an..'_ENABLED\n')
	for _,m in ipairs(api.meths) do
		m.s = m.s:gsub('~', '_SELF')
		f:write(string.gsub([[
#define vV`n(SELF, ...) ({ Vv`t _SELF = (SELF); `s__VA_ARGS__); })
]], '`(.)', m)..'')
	end
	f:write('#endif // Vv_'..an..'_ENABLED\n')
]=]

	f:write('\n#endif // H_vivacious_'..an)
	f:close()
end

--[=[

-- Then write up the core.h
do
	local f = io.open(arg[1]..'/core.h', 'w')
	f:write[[
// Generated from apis/generator/c.lua, do not edit
#ifndef H_vivacious_core
#define H_vivacious_core

#include <stdlib.h>
#include <stdbool.h>
]]

	-- The Vv_*_ENABLED macros, as defined by the Vv_IMP_* macros
	local function allowlayer(l)
		for _,v in ipairs(l) do
			if type(v) == 'table' then allowlayer(v)
			else
				local api = require(v)
				local n = api.api.shortname:lower()
				f:write('#define Vv_'..n..'_ENABLED\n')
			end
		end
	end
	f:write'#if 0\n'
	for i=#apis,1,-1 do
		local a = apis[i]
		local api = require(a)
		local N,n = api.api.shortname, api.api.shortname:lower()
		f:write('#elif defined(Vv_IMP_'..n..')\n')
		for _,v in ipairs(apis.layers[a]) do
			if type(v) == 'table' then allowlayer(v) end
		end
	end
	f:write'#else\n'
	for _,a in ipairs(apis) do allowlayer({a}) end
	f:write'#endif\n\n'

	f:write[[
#define Vv_LEN(...) sizeof(__VA_ARGS__)/sizeof((__VA_ARGS__)[0])
#define Vv_ARRAY(N, ...) .N##Cnt = Vv_LEN((__VA_ARGS__)), .N=(__VA_ARGS__)

#endif
]]
	f:close()
end

-- And finish up with vivacious.h
do
	local f = io.open(arg[1]..'/vivacious.h', 'w')
	f:write'// Generated from apis/generator/c.lua, do not edit\n'
	f:write'#ifndef H_vivacious_vivacious\n'
	f:write'#define H_vivacious_vivacious\n\n'

	-- Include all the API headers
	for _,a in ipairs(apis) do
		f:write('#include <vivacious/'..a..'.h>\n')
	end
	f:write'\n'

	-- Add a macro to get the default Vv.
	f:write'#define vV() ({ \\\n	Vv V; \\\n'
	for _,a in ipairs(apis) do
		local n = require(a).api.shortname:lower()
		f:write('\tV.'..n..' = vV'..n..'(&V); \\\n')
	end
	f:write'	V; \\\n})\n\n'

	f:write'#endif'
	f:close()
end
]=]
