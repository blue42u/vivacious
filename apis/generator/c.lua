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
local std = dofile 'generator/stdc.lua'
package.loaded.standard = setmetatable(std,
	{__index=function(_,k) return false end})

local apis = require 'apis'
local apiset = {}
for _,a in ipairs(apis) do apiset[a] = true end

local inapi = 1
local extras = {{}}
local oldrequire = require
function std.define(s) table.insert(extras[inapi], '#define '..s) end
function std.include(s) table.insert(extras[inapi], '#include <'..s..'>') end
function require(s)
	local out
	if apiset[s] then
		table.insert(extras[inapi], '#include <vivacious/'..s..'.h>')
		extras[s] = extras[s] or {}

		local myapi = inapi
		inapi = s
		out = oldrequire(s)
		inapi = myapi
	else out = oldrequire(s) end
	return out
end

-- First write up all of the API headers
for _,a in ipairs(apis) do
	local f = io.open(arg[1]..'/'..a..'.h', 'w')
	f:write('// File generated from apis/'..a..'.lua, do not edit\n')
	f:write('#ifndef H_vivacious_'..a..'\n')
	f:write('#define H_vivacious_'..a..'\n\n')

	local api = require(a)
	local names = {}
	for n,t in pairs(api) do if not t.notdef then
		names[t] = 'Vv'..api.api.shortname..'_'..n
	end end
	names[api.api] = 'Vv'..api.api.shortname

	f:write'#include <vivacious/core.h>\n'
	if #extras[a] > 0 then f:write(table.concat(extras[a], '\n')..'\n') end
	f:write'\n'

	local Vv = {std.external{'const Vv*'}}
	local function modfunc(t)
		if t._from == 'func' then table.insert(t, 1, Vv)
		else t:_def(modfunc) end
	end
	modfunc(api.api)

	local tdefd = {}
	local function writetdef(t)
		if not tdefd[t] then
			t:_def(writetdef)

			if names[t] then
				local ref = t._ref
				function t:_ref(w, n)
					t:_sref(w, names[self], n)
				end
				ref(t, function(s)
					f:write('typedef ')
					f:write(s)
					f:write(';\n')
				end, names[t], true)

				if t._macro then
					t:_macro(function(s)
						f:write(s..'\n')
					end, names[t])
				end

				f:write('\n')
			end

			tdefd[t] = true
		end
	end
	for _,t in pairs(api) do writetdef(t) end

	local aName, aname = api.api.shortname, api.api.shortname:lower()
	f:write('const Vv'..aName..'* vV'..aname..'(const Vv*);\n')

	f:write('#ifdef Vv_'..aname..'_ENABLED\n')
	local function writedef(t, name, path)
		if t._from == 'func' then
			if #t > 1 or #t.returns > 1 then
				f:write('#define vV'..aname..'_'..name
					..'(...) '..path
					..'(&(Vv_CHOICE), __VA_ARGS__)\n')
			else
				f:write('#define vV'..aname..'_'..name
					..'() '..path
					..'(&(Vv_CHOICE))\n')
			end
		elseif t._from == 'external' and t.func then
			f:write('#define vV'..aname..'_'..name
				..'(...) '..path
				..'(__VA_ARGS__)\n')
		else
			t:_def(function(st, pre, post, nam)
				writedef(st, nam or name, pre..path..post)
			end)
		end
	end
	writedef(api.api, nil, '(Vv_CHOICE).'..aname)
	f:write'#endif\n\n'

	f:write('#endif')
	f:close()
end

-- Then write up the core.h
do
	local f = io.open(arg[1]..'/core.h', 'w')
	f:write'// Generated from apis/generator/c.lua, do not edit\n'
	f:write'#ifndef H_vivacious_core\n'
	f:write'#define H_vivacious_core\n\n'
	f:write'#include <stdlib.h>\n\n'

	-- First the "choice" structure, Vv
	f:write'typedef struct {\n'
	for _,a in ipairs(apis) do
		local api = require(a)
		f:write('\tconst struct Vv'..api.api.shortname..'* '
			..api.api.shortname:lower()..';\n')
	end
	f:write'} Vv;\n\n'

	-- Then the implementation defines (ad nauseum)
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
