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
G.simple.number = {def='float `e`', conv='`v:%f`', default=0}
G.simple.integer = {def='int `e`', conv='`v:%d`', default=0}
G.simple.boolean = {def='bool `e`', conv=tostring, default=false}
G.simple.string = {def='const char* `e`', conv='`v:%q`', default=''}
G.simple.memory = {def='void* `e`', conv=error}
G.simple.generic = {def='void* `e`', conv=error}
G.simple.index = {def='int `e`', conv=function(v)
	return string.format('%u', v-1) end, default=1}

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
				local els = std.context()
				for i,vv in ipairs(v) do arg[1]'conv'(els, i, vv) end
				c[e] = '{'..els', '..'}'
			end
		end,
	}
end

local void = std.type('void', {def='void `e`', conv=error})
function G.callable(arg)
	local ret = table.remove(arg.returns or {}, 1) or void
	return {
		def = function(c, e)
			local args = std.context()
			for _,a in ipairs(arg) do a[2]'def'(args, a[1]) end
			for _,r in ipairs(arg.returns or {}) do r'def'(args, '*') end
			ret'def'(c, '(*'..e..')('..args', '..')')
		end,
		conv = function() error("Callables don't support Lua conversion") end
	}
end

function G.compound(arg)
	local ents = std.context()
	for _,e in ipairs(arg) do e[2]'def'(ents, e[1]) end
	ents = ents('', function(e) return '\t'..e:gsub('\n', '\n\t')..';\n' end)

	local typs = {}
	for _,e in ipairs(arg) do typs[e[1]] = e[2] end
	return {
		def = 'struct `e` {\n'..ents..'} `e`',
		conv = function(c, e, v)
			local ps = std.context()
			for k,sv in pairs(v) do typs[k]'conv'(ps, k, sv) end
			c[e] = '{'..ps(', ', '.`e`=`v`')..'}'
		end,
	}
end

function G.reference(n, t, cp)
	local tn = 'Vv'..n:gsub('%.', '')
	local d = n:gsub('.*%.', ''):lower()
	return {
		def = function(c, e)
			e = e or d
			if t then
				cp[n] = 'typedef '..t'def'(tn)[1]..';'
				cp[n..'_magic'] = '#define '..tn..'(...) ({ '
					..e..' _x = '..t'conv'(tn)[1]..'; '
					..'VvMAGIC(__VA_ARGS__); _x; })'
			end
			c[e] = tn..' '..e
		end,
		conv = function(c, e) t'conv'(c, e) end,
	}
end

function G.behavior(arg)
	return {
		def = function(c, e, es)
			e = 'Vv'..e:gsub('%.', '')

			c[e..'_typedef'] = '// Behavior '..e
				..'\ntypedef struct '..e..'* '..e..';'
			local ms = std.context()
			for _,em in ipairs(es) do if em[1] == 'm' then
				em[3]'def'(ms, em[2])
				c[em[2]] = '#define vV'..em[2]..'(_S, ...) ({ '
					..'__typeof__ (_S) _s = (_S); '
					..'_s->_M->'..em[2]..'(_s, __VA_ARGS__); })'
			end end
			ms = ms('', function(s)
				return '\t\t'..s:gsub('\n', '\n\t\t')..';\n' end)

			local ds = std.context()
			for _,ed in ipairs(es) do if ed[1] == 'rw' then
				ed[3]'def'(ds, ed[2])
			elseif ed[1] == 'ro' then
				ed[3]'def'(ds, 'const '..ed[2])
			end end
			if not arg.issub then for i,b in ipairs(arg) do b'def'(ds) end end
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

function G.environment(_)
	return {
		def = function(c, e, f)
			f:write(([[
// Generated file, do not edit directly, edit apis/~.lua instead
#ifndef H_vivacious_~
#define H_vivacious_~

#include <vivacious/core.h>

]]):gsub('~', e)..'')

			for _,l in ipairs(c) do f:write(l..'\n\n') end

			f:write('#endif // H_vivacious_'..e)
		end,
		conv = error,
	}
end

return G
