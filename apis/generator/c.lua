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

local G = {simple={}}
package.preload.generator = function() return G end

local function simple(n, t, f, d)
	G.simple[n] = {def = t..' `e`', default=d}
	if type(f) == 'string' then
		G.simple[n].conv = '`v:'..f..'`'
	elseif type(f) == 'function' then
		G.simple[n].conv = function(c,e,v) c[e] = f(v) end
	else
		G.simple[n].conv = function() error("Simpletype "..n.." has no conversion") end
	end
end
simple('number', 'float', '%f', 0)
simple('integer', 'int', '%d', 0)
simple('memory', 'void*')
simple('boolean', 'int', function(v) return v and '1' or '0' end, false)
simple('generic', 'void*')
simple('string', 'const char*', '%q', '')

package.path = './?.lua;./generator/?.lua'
local sl = require 'stdlib'

local function append(t)
	return setmetatable({}, {__newindex=function(_,_,v) table.insert(t, v) end})
end

local void = sl.T{def='void `e`', conv=error}
function G.callable(arg)
	local ret = table.remove(arg.returns or {}, 1) or void
	local args = {}
	for _,a in ipairs(arg) do a[2]'def'(append(args), a[1]) end
	for _,r in ipairs(arg.returns or {}) do r'def'(append(args), '*') end
	args = table.concat(args, ', ')

	local cc = {}
	ret'def'(append(cc), '(*`e`)('..args..')')
	return {
		def = cc[1],
		conv = function() error("Callables don't support Lua conversion") end
	}
end

function G.compound(arg)
	local ents = {}
	for _,e in ipairs(arg) do
		e[2]'def'(setmetatable({}, {__newindex = function(_,_,s)
			table.insert(ents, '\t'..s:gsub('\n', '\n\t')..';\n')
		end}), e[1])
	end
	ents = table.concat(ents)

	local typs = {}
	for _,e in ipairs(arg) do typs[e[1]] = e[2] end
	return {
		def = 'struct `e` {\n'..ents..'} `e`',
		conv = function(c, e, v)
			local cc = {}
			for k,sv in pairs(v) do typs[k]'conv'(cc, k, sv) end
			c[e] = 'struct '..e..' {'
			for k,s in pairs(cc) do c[e] = c[e]..'.'..k..' = '..s..', ' end
			c[e] = c[e] .. '}'
		end,
	}
end

function G.behavior()
	return {
		def = function(c, e, ts, es)
			c[e] = 'typedef struct Vv'..e..'* Vv'..e..';'
			for _,t in ipairs(ts) do
				local cc = {}
				t[2]'def'(cc, 'Vv'..t[1])
				for k,v in pairs(cc) do c[k] = 'typedef '..v..';' end
				cc = {}
				t[2]'conv'(cc, 'Vv'..t[1])
				for k,v in pairs(cc) do
					c[k] = '#define '..k..'_DEF '..v
				end
			end

			local meths = {}
			for _,em in ipairs(es) do if em[1] == 'm' then
				em[3]'def'(setmetatable({}, {__newindex = function(_,_,s)
					table.insert(meths, '\t\t'..s:gsub('\n', '\n\t\t')..';\n')
				end}), em[2])
				c[em[2]] = '#define '..em[2]..'(_S, ...) ({ __typeof__ (_S) _s = (_S); '
					..'_s->_M->'..em[2]..'(_s, __VA_ARGS__); })'
			end end
			meths = table.concat(meths)

			local dats = {}
			for _,ed in ipairs(es) do if ed[1] == 'rw' then
				ed[3]'def'(setmetatable({}, {__newindex = function(_,_,s)
					table.insert(dats, '\t'..s:gsub('\n', '\n\t')..';\n')
				end}), ed[2])
			elseif ed[1] == 'ro' then
				ed[3]'def'(setmetatable({}, {__newindex = function(_,_,s)
					s = s:gsub('\n', '\n\t'):gsub('%*', '%*const ')
					table.insert(dats, '\tconst '..s..';\n')
				end}), ed[2])
			end end
			dats = table.concat(dats)

			c[e] = 'struct '..e..' {\n'
				..'\tstruct '..e..'_M {\n'
				..meths
				..'\t} *_M;\n'
				..dats
				..'}'
		end,
		subtype = function(n, ty)
			return {
				def=function(c,e) c[e] = 'Vv'..n..' '..e end,
				conv=ty'conv',
			}
		end,
	}
end

-- Now load in all the specs
local outdir = table.remove(arg, 1)..'/'
local envs = {}
for _,a in ipairs(arg) do envs[a] = sl.preload(a) end
for _,a in ipairs(arg) do require(a) end

-- First thing to write, the API headers. Each spec turns into one of these.
for an,env in pairs(envs) do
	local f = io.open(outdir..an..'.h', 'w')
	f:write(([[
// Generated file, do not edit directly, edit apis/~.lua instead
#ifndef H_vivacious_~
#define H_vivacious_~

#include "core.h"

]]):gsub('~', an)..'')

	for n,b in pairs(env) do
		f:write('// Behavior '..n..'\n')
		b'def'(setmetatable({}, {__newindex=function(_,_,s) f:write(s..'\n') end}), n)
		f:write'\n'
	end

	f:write('#endif // H_vivacious_'..an)
	f:close()
end

-- Then write up the core.h. This is mostly hardcoded.
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

-- And last but not least, write vivacious.h, which include's all the others.
do
	local f = io.open(outdir..'vivacious.h', 'w')
	f:write[[
// Generated from apis/generator/c.lua, do not edit
#ifndef H_vivacious_vivacious
#define H_vivacious_vivacious

]]
	for a in pairs(envs) do
		f:write('#include <vivacious/'..a..'.h>\n')
	end
	f:write'\n#endif'
	f:close()
end
