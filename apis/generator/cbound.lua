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

local G = {simple={}, custom={}, customarg={}}
G.simple.number = {def='float `e`', conv='`v:%f`', default=0}
G.simple.integer = {def='int32_t `e`', conv='`v:%d`', default=0}
G.simple.unsigned = {def='uint32_t `e`', conv='`v:%d`', default=0}
G.simple.boolean = {def='bool `e`', conv=tostring, default=false}
G.simple.string = {def='const char* `e`', conv='`v:%q`', default=''}
G.simple.memory = {def='void* `e`', conv=error}
G.simple.generic = {def='void* `e`', conv=error}
G.simple.index = {def='int `e`', conv=function(v)
	return string.format('%u', v-1) end, default=1}

G.customarg.raw = {
	realname = true,	-- The name of the bound C type
}
function G.custom.raw(arg)
	return {
		def = arg.realname..' `e`',
		conv = error,
	}
end

G.customarg.flexmask = {
	[1] = true,		-- Type of the array elements
	bits = true,	-- Number of bits per element
	lenvar = true,	-- Length variable
}
function G.custom.flexmask(arg)
	return {
		def = function(c, e) arg[1]'def'(c, '*'..e) end,
		conv = function(c, e, v)
			local maxbit = 0
			for i in pairs(v) do maxbit = math.max(maxbit, i) end
			c[arg.lenvar] = ('%d'):format(math.ceil(maxbit / arg.bits))
			if maxbit == 0 then c[e] = 'NULL' else
				local els = {}
				for i=1,math.ceil(maxbit / arg.bits) do
					els[i] = tostring(e)
					for j=1,arg.bits do if v[(i-1)*arg.bits+j] then
						els[i] = els[i] | 1<<(j-1)
					end end
				end
			end
			c[e] = '{'..table.concat(els, ', ')..'}'
		end,
	}
end

G.arrayarg = {
	lenvar = false,		-- The variable that will contains the length
}
function G.array(arg)
	return {
		def = function(c, e)
			if arg.fixedsize then
				arg[1]'def'(c, e..'['..arg.fixedsize..']')
			else
				arg[1]'def'(c, '*'..e)
			end
		end,
		conv = function(c, e, v)
			if not arg.fixedsize then c[arg.lenvar] = ('%d'):format(#v) end
			if #v == 0 then c[e] = 'NULL' else
				local els = std.context()
				for i,vv in ipairs(v) do arg[1]'conv'(els, i, vv) end
				c[e] = '{'..els', '..'}'
			end
		end,
	}
end

G.flagsarg = {
	realname = true,	-- The name of the bound C enum
}
function G.flags(arg)
	return {
		def = arg.realname..' `e`',
		conv = function(c,e,v)
			local bs = {}
			for k in pairs(v) do table.insert(bs, k) end
			c[e] = table.concat(bs, ' | ')
		end,
	}
end

G.optionsarg = {
	realname = true,	-- The name of the bound C enum
}
function G.options(arg)
	return {
		def = arg.realname..' `e`',
		conv = '`v`',
	}
end

G.callablearg = {
	realname = true,	-- The name of the bound C function pointer
}
function G.callable(arg)
	return {
		def = arg.realname..' `e`',
		conv = error,
	}
end

G.compoundarg = {
	realname = true,	-- The name of the bound C structure
	addptr = true,		-- Add an extra pointer when converting
}
function G.compound(arg)
	local typs = {}
	for _,e in ipairs(arg) do typs[e[1]] = e[2] end
	return {
		def = arg.realname..' `e`',
		conv = function(c, e, v)
			local ps = std.context()
			for k,sv in pairs(v) do typs[k]'conv'(ps, k, sv) end
			c[e] = '('..arg.realname..(arg.addptr and '*' or '')
				..'){'..ps(', ', '.`e`=`v`')..'}'
		end,
	}
end

G.reference = {
	def=function(c, e, n) c[e] = n..' '..e end,
	conv=function(c, e, t) t'conv'(c, e) end,
}
function G.refname(e)
	return 'Vv'..e:gsub('%..+%.', '.'):gsub('%.', '')
end
function G.reftype() end

G.behaviorarg = {
	wrapperfor = false,	-- Name of the C type that this Behavior wraps
}
function G.behavior(arg)
	return {
		def = function(c, e, es)
			c[e..'_typedef'] = '// Behavior '..e
				..'\ntypedef struct '..e..'* '..e..';'

			-- Data is silently ignored.

			local ds,du = std.context(),{}
			for i,b in ipairs(arg) do
				b'def'(ds, b'behaves':match('Vv(.+)'):lower())
				table.insert(du, '_s->part'..i)
			end
			ds = ds('', function(s)
				return '\t'..s:gsub('\n', '\n\t')..';\n' end)
			du = table.concat(du, ', ')

			local ms = std.context()
			for _,em in ipairs(es) do if em[1] == 'm' then
				em[3]'def'(ms, em[2])
				c[em[2]] = '#define vV'..em[2]..'(_S, ...) ({ '
					..'__typeof__ (_S) _s = (_S); '
					..'_s->_M->'..em[2]..'(_s->real, '..du..', __VA_ARGS__); })'
			end end
			ms = ms('', function(s)
				return '\t\t'..s:gsub('\n', '\n\t\t')..';\n' end)

			c[e] = 'struct '..e..' {\n'
				..'\tconst struct '..e..'_M {\n'
				..ms
				..'\t} * const _M;\n'
				..ds
				..'\t'..(arg.wrapperfor and arg.wrapperfor..' real;'
					or 'struct '..e..'_I _I;')..'\n'
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
