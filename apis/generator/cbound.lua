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

local C = require 'c'.sl

local G = {simple={}, custom={}, customarg={}}
G.simple.number = {def='float `e`', conv='`v:%f`', default=0}
G.simple.integer = {def='int32_t `e`', conv='`v:%d`', default=0}
G.simple.unsigned = {def='uint32_t `e`', conv='`v:%d`', default=0}
G.simple.boolean = {def='bool `e`', default=false}
function G.simple.boolean:conv(c, e, v) c[e] = v and 'true' or 'false' end
G.simple.string = {def='const char* `e`', conv='`v:%q`', default=''}
G.simple.memory = {def='void* `e`', conv=error}
G.simple.generic = {def='void* `e`', conv=error}
G.simple.index = {def='int `e`', default=1}
function G.simple.index:conv(c, e, v) c[e] = string.format('%u', v-1) end

G.customarg.raw = {
	realname = true,	-- The name of the bound C type
	conversion = false,	-- Conversion string for the C type
}
function G.custom:raw(arg)
	self.def = arg.realname..' `e`'
	if type(arg.conversion) == 'string' then
		self.conv = '`v:'..arg.conversion..'`'
	elseif type(arg.conversion) == 'function' then
		function self:conv(c, e, v) c[e] = arg.conversion(v) end
	else self.conv = error end
end

G.customarg.flexmask = {
	[1] = true,		-- Type of the array elements
	bits = true,	-- Number of bits per element
	lenvar = true,	-- Length variable
}
function G.custom:flexmask(arg)
	function self:def(c, e) arg[1]'def'(c, '*'..e) end
	function self:conv(c, e, v)
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
			c[e] = '{'..table.concat(els, ', ')..'}'
		end
	end
end

G.arrayarg = {
	lenvar = false,		-- The variable that will contains the length
}
function G:array(arg)
	function self:def(c, e)
		if arg.fixedsize then
			arg[1]'def'(c, e..'['..arg.fixedsize..']')
		else
			arg[1]'def'(c, '*'..e)
		end
	end
	function self:conv(c, e, v)
		if not arg.fixedsize then c[arg.lenvar] = ('%d'):format(#v) end
		if #v == 0 then c[e] = 'NULL' else
			local els = newcontext()
			for i,vv in ipairs(v) do arg[1]'conv'(els, i, vv) end
			c[e] = '{'..els', '..'}'
		end
	end
end

G.flagsarg = {
	realname = true,	-- The name of the bound C enum
}
function G:flags(arg)
	self.def = arg.realname..' `e`'
	function self:conv(c, e, v)
		local bs = {}
		for k in pairs(v) do table.insert(bs, k) end
		if #bs == 0 then c[e] = '0'
		else c[e] = table.concat(bs, ' | ') end
	end
end

G.optionsarg = {
	realname = true,	-- The name of the bound C enum
}
function G:options(arg)
	self.def = arg.realname..' `e`'
	self.conv = '`v`'
end

G.callablearg = {
	realname = true,	-- The name of the bound C function pointer
}
function G:callable(arg)
	self.def = arg.realname..' `e`'
	self.conv = error
end

G.compoundarg = {
	realname = true,	-- The name of the bound C structure
}
function G:compound(arg)
	local typs = {}
	for _,e in ipairs(arg) do typs[e[1]] = e[2] end
	self.def = arg.realname..' `e`'
	function self:conv(c, e, v)
		local ps = newcontext()
		for k,sv in pairs(v) do typs[k]'conv'(ps, k, sv) end
		c[e] = '('..arg.realname..'){'..ps(', ', '.`e`=`v`')..'}'
	end
end

function G:reference(n, t, cp, ex)
	local d = n:gsub('.*%.', ''):gsub('%u?%u%u$', ''):lower()
	n = n:gsub('.*%.', '')
	if n ~= ex.prefix then n = ex.prefix..n end
	function self:def(c, e)
		e = e or d
		if t then
			cp[n] = '#define '..n..'(...) ({ '
				..t'def'('_x')[1]..' = '..t'conv'(n)[1]..'; '
				..'VvMAGIC(__VA_ARGS__); _x; })'
		end
		c[e] = (t and '' or 'Vv')..n..' '..e
	end
	function self:conv(c, e, v) t'conv'(c, e or d, v) end
	return 'Vv'..n
end

G.behaviorarg = {
	wrapperfor = false,	-- Name of the C type that this Behavior wraps
	directives = false,	-- List of extra directives to add to this Behavior
	prefix = true,		-- Extra prefix for contents of this Behavior
}
function G:behavior(arg)
	function self:def(c, e, es)
		if arg.directives then
			local d = {}
			for i,l in ipairs(arg.directives) do d[i] = '#'..l end
			c[e..'_dir'] = table.concat(d, '\n')
		end

		c[e..'_doc'] = '/* Behavior '..e
			..'\n\t'..arg.doc:gsub('\n', '\n\t')
			..'\n*/'

		c[e..'_typedef'] = 'typedef struct '..e..'* '..e..';'

		-- Data is silently ignored.

		local ds,du,da = newcontext(),{},{returns={self}}
		if arg.wrapperfor then
			table.insert(da, {'real', std.raw{realname=arg.wrapperfor}}) end
		for _,b in ipairs(arg) do
			b'def'(ds)
			table.insert(da, {'', b})
		end
		if arg.issub then for k in pairs(ds) do
			table.insert(du, '_s->'..k..', ')
		end end
		table.insert(du, arg.wrapperfor and '_s->real' or '_s')
		ds = ds('', function(s)
			return '\t'..s:gsub('\n', '\n\t')..';\n' end)
		du = table.concat(du)
		da = C.callable(da)

		table.insert(es, 1, {'m', 'destroy', C.callable{{'self', self}}})
		local ms = newcontext()
		for _,em in ipairs(es) do if em[1] == 'm' then
			em[3]'def'(ms, em[2])
			c[em[2]] = '#define vV'..em[2]..'(_S, ...) ({ '
				..'__typeof__ (_S) _s = (_S); '
				..'_s->_M->'..em[2]..'('..du..', __VA_ARGS__); })'
		end end
		ms = ms('', function(s)
			return '\t\t'..s:gsub('\n', '\n\t\t')..';\n' end)

		local ws = ''
		if arg.wrapperfor then ws = '\t'..arg.wrapperfor..' real;\n' end

		c[e] = 'struct '..e..' {\n'
			..ws
			..'\tconst struct '..e..'_M {\n'
			..ms
			..'\t} * const _M;\n'
			..ds
			..'\tstruct '..e..'_I _I;\n'
			..'};'

		c[e..'_c'] = da'def'('~')[1]:gsub('%(%*~%)',
			'vV'..(arg.wrapperfor and 'wrap' or 'create')..e:match'Vv(.+)')..';'
	end
	self.conv = error
	return {prefix=arg.prefix}
end

function G:environment()
	function self:def(c, e, ds, f, ...)
		f:write(([[
// Generated file, do not edit directly, edit apis/~.lua instead
#ifndef H_vivacious_~
#define H_vivacious_~

#include <vivacious/core.h>
]]):gsub('~', e)..'')
		for _,d in ipairs(ds) do
			f:write('#include <vivacious/'..d..'.h>\n') end
		f:write('\n')
		for _,l in ipairs(c) do f:write(l..'\n\n') end

		f:write('#endif // H_vivacious_'..e)
	end
	self.conv = error
end

return G
