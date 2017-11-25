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
	return setmetatable({}, {__concat=function(_,w) ref(w) end,
		__call=function(_,w,o) conv(w,o) end})
end

local function tins(t)
	return t, function(y, x, r)
		if not r then y,x,r = nil,y,x end
		if r then x = string.gsub(x, '~', r) end
		if y then table.insert(t, y, x)
		else table.insert(t, x) end
	end
end

local function simpletype(t, c) return newtype(
	function(w) w(t..' ~') end,
	function(w,o) w(c(o)) end)
end
function integer() return simpletype('int', function(o) return ('%d'):format(o) end) end
function boolean() return simpletype('bool', function(o) return o and 'true' or 'false' end) end

function callback(arg)
	local ret = newtype(function(w) w('void ~') end)
	local args = {}

	local aend = 0
	for i,a in ipairs(arg) do
		if type(a[1]) == 'string' then aend = i else break end
	end

	local cmain
	for i=aend+1,#arg do if arg[i].c_main then cmain = i; break end end
	cmain = cmain or aend+1
	if arg[cmain] then ret = table.remove(arg, cmain)[1] end

	return newtype(function(w)
		local start
		local parts,p = tins{}
		for i=1,aend do _=arg[i][2]..function(s) p(s, arg[i][1]) end end
		for i=aend+1,#arg do _=arg[i][1]..function(s) p(s, '*') end end

		local retdone
		_=ret..function(s)
			if retdone then p(s, '*') else start = s:gsub('~', '(*~)(') end
			retdone = true
		end

		w(start..table.concat(parts, ', ')..')')
	end, function(w,o) w('NULL') end)
end

local structnums = 0
local function object(arg, newmeth)
	local meta,meth,tnam = {},{},'struct _self_ref_'..structnums
	structnums = structnums + 1
	function meta:__index(k)
		local M,m,p = string.match(tostring(k), 'v(%d+)_(%d+)_(%d+)')
		if M then
			return setmetatable({}, {__newindex=function(_, k, v)
				table.insert(v, 1, {'self', newtype(function(w) w(tnam..'* ~') end)})
				table.insert(meth, {M=M, m=m, p=p, n=k, t=callback(v)})
				if newmeth then newmeth(k, '~->_methods->'..k..'(~, ') end
			end})
		end
	end
	function meta:__concat(w)
		local tab,t = tins{tnam..' {', '\tstruct {'}
		table.sort(meth, function(a,b)
			if a.M ~= b.M then return a.M < b.M
			elseif a.m ~= b.m then return a.m < b.m
			elseif a.p ~= b.p then return a.p < b.p
			else return a.n < b.n end
		end)
		for _,m in ipairs(meth) do _=m.t..function(s) t('\t\t'..s..';', m.n) end end
		t'\t} *_methods;'
		t'} ~'
		return w(table.concat(tab, '\n'))
	end
	meta.header = arg.header
	return setmetatable({}, meta)
end

local outdir = table.remove(arg, 1)..'/'
local apis = setmetatable({}, {__index=function(self, k)
	self[k] = {defines = {}, includes = {}, types = {}, meths={}}
	return self[k]
end})
for _,a in ipairs(arg) do
	local env = setmetatable({}, {
		__index = _G,
		__newindex = function(self, k, v)
			local api
			local obj = object(v, function(n, s) table.insert(api.meths, {n=n, s=s, t=k}) end)
			local meta = {__call=function(_,n) return k..' '..n end, __index=obj}
			rawset(self, k, setmetatable({}, meta))
			api = apis[getmetatable(obj).header or k..'.h']
			api.types[k] = obj
		end
	})
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
	if #api.includes > 0 then f:write(table.concat(api.includes, '\n')..'\n') end
	f:write'\n'

	-- Typedefs
	for n,t in pairs(api.types) do
		_=t..function(s) f:write('typedef '..s:gsub('~', '*Vv'..n)..';\n\n') end
	end

	-- Method macros
	f:write('#ifdef Vv_'..an..'_ENABLED\n')
	for _,m in ipairs(api.meths) do
		m.s = m.s:gsub('~', '_SELF')
		f:write(string.gsub([[
#define vV`n(SELF, ...) ({ Vv`t _SELF = (SELF); `s__VA_ARGS__); })
]], '`(.)', m)..'')
	end
	f:write('#endif // Vv_'..an..'_ENABLED\n')

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
