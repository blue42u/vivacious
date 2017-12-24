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

G.simple.number = {def='float `e`', conv='`v:%f`', default=0}
G.simple.integer = {def='int `e`', conv='`v:%d`', default=0}
G.simple.boolean = {def='bool `e`', conv=tostring, default=false}
G.simple.string = {def='const char* `e`', conv='`v:%q`', default=''}
G.simple.memory = {def='void* `e`', conv=error}
G.simple.generic = {def='void* `e`', conv=error}

local sl

function G.array(arg)
	return {
		def = function(c, e)
			if arg.fixedsize then
				arg[1]'def'(c, e..'['..arg.fixedsize..']')
			else
				c[e..'Cnt'] = 'size_t '..e..'Cnt'
				arg[1]'def'(c, '*'..e)
			end
		end,
		conv = function(c, e, v)
			if not arg.fixedsize then c[e..'Cnt'] = ('%d'):format(#v) end
			if #v == 0 then c[e] = 'NULL' else
				local els = sl.C()
				for i,vv in ipairs(v) do arg[1]'conv'(els, i, vv) end
				c[e] = '{'..els', '..'}'
			end
		end,
	}
end

function G.callable(arg)
	local ret = table.remove(arg.returns or {}, 1)
		or sl.T{def='void `e`', conv=error}
	return {
		def = function(c, e)
			local args = sl.C()
			for _,a in ipairs(arg) do a[2]'def'(args, a[1]) end
			for _,r in ipairs(arg.returns or {}) do r'def'(args, '*') end
			ret'def'(c, '(*'..e..')('..args', '..')')
		end,
		conv = function() error("Callables don't support Lua conversion") end
	}
end

function G.compound(arg)
	local ents = sl.C()
	for _,e in ipairs(arg) do e[2]'def'(ents, e[1]) end
	ents = ents('', function(e) return '\t'..e:gsub('\n', '\n\t')..';\n' end)

	local typs = {}
	for _,e in ipairs(arg) do typs[e[1]] = e[2] end
	return {
		def = 'struct `e` {\n'..ents..'} `e`',
		conv = function(c, e, v)
			local ps = sl.C()
			for k,sv in pairs(v) do typs[k]'conv'(ps, k, sv) end
			c[e] = '{'..ps(', ', '.`e`=`v`')..'}'
		end,
	}
end

G.reference = {
	def=function(c, e, n) c[e] = n..' '..e end,
	conv=function(c, e, t) t'conv'(c, e) end,
}
function G.refname(e) return e:gsub('%.', '') end
function G.reftype(c, e, c2) c[e] = 'typedef '..c2[1]..';' end
function G.behavior()
	return {
		def = function(c, e, es)
			c[e..'_typedef'] = '// Behavior '..e
				..'\ntypedef struct '..e..'* '..e..';'
			local ms = sl.C()
			for _,em in ipairs(es) do if em[1] == 'm' then
				em[3]'def'(ms, em[2])
				c[em[2]] = '#define vV'..em[2]..'(_S, ...) ({ '
					..'__typeof__ (_S) _s = (_S); '
					..'_s->_M->'..em[2]..'(_s, __VA_ARGS__); })'
			end end
			ms = ms('', function(s)
				return '\t\t'..s:gsub('\n', '\n\t\t')..';\n' end)

			local ds = sl.C()
			for _,ed in ipairs(es) do if ed[1] == 'rw' then
				ed[3]'def'(ds, ed[2])
			elseif ed[1] == 'ro' then
				ed[3]'def'(ds, 'const '..ed[2])
			end end
			ds = ds('', function(s)
				return '\t'..s:gsub('\n', '\n\t')..';\n' end)

			c[e] = 'struct '..e..' {\n'
				..'\tconst struct '..e..'_M {\n'
				..ms
				..'\t} * const _M;\n'
				..ds
				..'};'
		end,
		conv = error,
	}
end

-- Now load in all the specs
package.path = './?.lua;./generator/?.lua'
sl = require 'stdlib'
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

	for _,e in ipairs(env'def'('Vv')) do f:write(e..'\n\n') end

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
		f:write('#define VvMAGIC_FA_'..i..'(what, x, ...) what(x); '
			..'VvMAGIC_FA_'..(i-1)..'(__VA_ARGS__)\n')
	end
	f:write'#define VvMAGIC_NA(...) VvMAGIC_AN(__VA_ARGS__'
	for i=maxmagic,0,-1 do f:write(','..i) end
	f:write')\n#define VvMAGIC_AN('
	for i=1,maxmagic do f:write('_'..i..',') end
	f:write[[N, ...) N

#define VvMAGIC_C(A, B) VvMAGIC_C2(A, B)
#define VvMAGIC_C2(A, B) A##B
#define VvMAGIC_FA(what, ...) VvMAGIC_C(VvMAGIC_FA_, \
	VvMAGIC_NA(__VA_ARGS__))(what, __VA_ARGS__)

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
