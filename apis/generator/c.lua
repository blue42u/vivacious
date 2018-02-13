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

local G = {default={simple={}}, bound={simple={}, custom={}}}
G.default.simple.number = {def='float `e`', conv='`v:%f`', default=0}
G.default.simple.integer = {def='int `e`', conv='`v:%d`', default=0}
G.default.simple.boolean = {def='bool `e`', default=false}
function G.default.simple.boolean:conv(c, e, v) c[e] = v and 'true' or 'false' end
G.default.simple.string = {def='const char* `e`', conv='`v:%q`', default=''}
G.default.simple.memory = {def='void* `e`', conv=error}
G.default.simple.generic = {def='void* `e`', conv=error}
G.default.simple.index = {def='int `e`', default=1}
function G.default.simple.index:conv(c, e, v) c[e] = string.format('%u', v-1) end

G.bound.simple.unsigned = {def='uint32_t `e`', conv='`v:%d`', default=0}

-- Raw C type, for the bound varient
G.bound.custom.raw_arg = {
	realname = true,	-- The name of the bound C type
	conversion = false,	-- Conversion string for the C type
}
function G.bound.custom:raw(arg)
	self.def = arg.realname..' `e`'
	if type(arg.conversion) == 'string' then
		self.conv = '`v:'..arg.conversion..'`'
	elseif type(arg.conversion) == 'function' then
		function self:conv(c, e, v) c[e] = arg.conversion(v) end
	else self.conv = error end
end

-- A strange type found in Vulkan, for the bound varient
G.bound.custom.flexmask_arg = {
	[1] = true,		-- Type of the array elements
	bits = true,	-- Number of bits per element
	lenvar = true,	-- Length variable
}
function G.bound.custom:flexmask(arg)
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

-- Arrays, sequences in Lua, pointers to memory in C
function G.default:array(arg)
	function self:def(c, e)
		if arg.fixedsize then
			arg[1]'def'(c, e..'['..arg.fixedsize..']')
		else
			c[e..'Cnt'] = 'size_t '..e..'Cnt'
			arg[1]'def'(c, '*'..e)
		end
	end
	function self:conv(c, e, v)
		if not arg.fixedsize then c[e..'Cnt'] = ('%d'):format(#v) end
		if #v == 0 then c[e] = 'NULL' else
			local els = newcontext()
			for i,vv in ipairs(v) do arg[1]'conv'(els, i, vv) end
			c[e] = '{'..els', '..'}'
		end
	end
end
G.bound.array_arg = {
	lenvar = false,		-- The variable that will contains the length
}
function G.bound:array(arg)
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

-- Flags, tables or strings in Lua, bitwise-OR of enum values in C
function G.default:flags(arg)
	function self:def(c, e, ex)
		ex = ex or {}
		if ex.simple then c[e] = 'enum '..e..' '..e else
			local fs = {}
			for i,f in ipairs(arg) do fs[i] = e..'_'..f end
			fs = table.concat(fs, ',\n')
			if ex.named then c[e] = 'enum '..e..' {\n'..fs..'\n}'
			else c[e] = 'enum {\n'..fs..'\n} '..e end
		end
	end
	function self:conv(c, e, v)
		local bs = {}
		for _,f in ipairs(arg) do if v[f] then table.insert(bs, e..'_'..f) end end
		if #bs == 0 then c[e] = '0' else c[e] = table.concat(bs, ' | ') end
	end
end
G.bound.flags_arg = {
	realname = true,	-- The name of the bound C enum
}
function G.bound:flags(arg)
	self.def = arg.realname..' `e`'
	function self:conv(c, e, v)
		local bs = {}
		for k in pairs(v) do table.insert(bs, k) end
		if #bs == 0 then c[e] = '0'
		else c[e] = table.concat(bs, ' | ') end
	end
end

-- Options, strings in Lua, enums in C
G.bound.options_arg = {
	realname = true,	-- The name of the bound C enum
}
function G.bound:options(arg)
	self.def = arg.realname..' `e`'
	self.conv = '`v`'
end

-- Callables, functions in Lua, function pointers + udata in C
local void = newtype('void', {def='void `e`', conv=error})
function G.default:callable(arg)
	local rs = arg.returns or {}
	local ret = table.remove(rs, 1) or void
	function self:def(c, e, ex)
		ex = ex or {}
		local args = newcontext()
		if ex.asarg then std.default.generic'def'(args, 'udata') end
		for _,a in ipairs(arg) do a[2]'def'(args, a[1], {asarg=true}) end
		for i,r in ipairs(rs) do r'def'(args, '*ret'..i) end
		local rets = ret'def'('~')
		for i=2,#rets do
			local ri = i-1+#rs
			args['*ret'..ri] = rets[i]:gsub('~', '*ret'..ri)
		end
		if ex.asarg then std.default.generic'def'(c, e..'_udata') end
		c[e] = rets[1]:gsub('~', '(*'..e..')('..args', '..')')
	end
	self.conv = error
end
G.bound.callable_arg = {
	realname = true,	-- The name of the bound C function pointer
}
function G.bound:callable(arg)
	self.def = arg.realname..' `e`'
	self.conv = error
end

-- Compounds, tables in Lua, structs in C
function G.default:compound(arg)
	local typs = {}
	for _,e in ipairs(arg) do typs[e[1]] = e[2] end
	function self:def(c, e, ex)
		ex = ex or {}
		if ex.simple then c[e] = 'struct '..e..' '..e else
			local ents = newcontext()
			for _,a in ipairs(arg) do a[2]'def'(ents, a[1]) end
			ents = ents('', function(e) return '\t'..e:gsub('\n', '\n\t')..';\n' end)
			if ex.named then c[e] = 'struct '..e..' {\n'..ents..'}'
			else c[e] = 'struct {\n'..ents..'} '..e end
		end
	end
	function self:conv(c, e, v)
		local ps = newcontext()
		for k,sv in pairs(v) do typs[k]'conv'(ps, k, sv) end
		c[e] = '{'..ps(', ', '.`e`=`v`')..'}'
	end
end
G.bound.compound_arg = {
	realname = true,	-- The name of the bound C structure
}
function G.bound:compound(arg)
	local typs = {}
	for _,e in ipairs(arg) do typs[e[1]] = e[2] end
	self.def = arg.realname..' `e`'
	function self:conv(c, e, v)
		local ps = newcontext()
		for k,sv in pairs(v) do typs[k]'conv'(ps, k, sv) end
		c[e] = '('..arg.realname..'){'..ps(', ', '.`e`=`v`')..'}'
	end
end

-- The Reference internal type. This is where the bound varient is very different
function G.default:reference(n, t, cp)
	local tn = 'Vv'..n:gsub('%.', '')
	local d = n:gsub('.*%.', ''):lower()
	function self:def(c, e)
		if t then
			cp[n] = 'typedef '..t'def'(tn, {simple=true})[1]..';'
			cp[n..'_real'] = t'def'(tn, {named=true})[1]..';'
			cp[n..'_magic'] = '#define '..tn..'_V(...) ({ '
				..tn..' _x = '..t'conv'(tn)[1]..'; '
				..'VvMAGIC(__VA_ARGS__); _x; })'
		end
	end
	function self:def_recursive(c, e, ex)
		e = e or d
		c[e] = tn..' '..e
	end
	function self:conv(c, e, v) t'conv'(c, e, v) end
	return tn
end
function G.bound:reference(n, t, cp, ex)
	local d = n:gsub('.*%.', ''):gsub('%u?%u%u$', ''):lower()
	n = n:gsub('.*%.', '')
	if n ~= ex.prefix then n = ex.prefix..n end
	function self:def(c, e)
		e = e or d
		if t then
			cp[n] = '#define '..n..'_V(...) ({ '
				..t'def'('_x')[1]..' = '..t'conv'(n)[1]..'; '
				..'VvMAGIC(__VA_ARGS__); _x; })'
			c[e] = t'def'(e)[1]
		else c[e] = 'Vv'..n..' '..e end
	end
	function self:conv(c, e, v) t'conv'(c, e or d, v) end
	return 'Vv'..n
end

-- The Behavior structure.
function G.default:behavior(arg)
	function self:def(c, e, es)
		c[e..'_doc'] = '/* Behavior '..e
			..'\n\t'..arg.doc:gsub('\n', '\n\t')
			..'\n*/'

		c[e..'_typedef'] = 'typedef struct '..e..'* '..e..';'
		table.insert(es, 1, {'m', 'destroy', std.default.callable{{'self', self}}})
		local ms = newcontext()
		for _,em in ipairs(es) do if em[1] == 'm' then
			em[3]'def'(ms, em[2])
			c[em[2]] = '#define vV'..em[2]..'(_S, ...) ({ '
				..'__typeof__ (_S) _s = (_S); '
				..'_s->_M->'..em[2]..'(_s, __VA_ARGS__); })'
		end end
		ms = ms('', function(s)
			return '\t\t'..s:gsub('\n', '\n\t\t')..';\n' end)

		local ds = newcontext()
		for _,ed in ipairs(es) do if ed[1] == 'rw' then
			ed[3]'def'(ds, ed[2])
		elseif ed[1] == 'ro' then
			ed[3]'def'(ds, 'const '..ed[2])
		end end
		for _,b in ipairs(arg) do b'def'(ds) end
		ds = ds('', function(s)
			return '\t'..s:gsub('\n', '\n\t')..';\n' end)

		c[e] = 'struct '..e..' {\n'
			..'\tconst struct '..e..'_M {\n'
			..ms
			..'\t} * _M;\n'
			..ds
			..'\tstruct '..e..'_I* _I;\n'
			..'};'

		if not arg.issub then
			local cf = {returns={self}}
			for _,b in ipairs(arg) do table.insert(cf, {'', b}) end
			cf = std.default.callable(cf)
			c[e..'_c'] = cf'def'('~')[1]:gsub('%(%*~%)', 'vVcreate'..e:match'Vv(.+)')..';'
		end
	end
	self.conv = error
end
G.bound.behavior_arg = {
	wrapperfor = false,	-- Name of the C type that this Behavior wraps
	directives = false,	-- List of extra directives to add to this Behavior
	prefix = true,		-- Extra prefix for contents of this Behavior
	consts = false,		-- Const-enabled default typedefs
}
function G.bound:behavior(arg)
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
			table.insert(da, {'real', std.bound.raw{realname=arg.wrapperfor}}) end
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
		da = std.default.callable(da)

		table.insert(es, 1, {'m', 'destroy', std.default.callable{{'self', self}}})
		local ms = newcontext()
		for _,em in ipairs(es) do if em[1] == 'm' then
			em[3]'def'(ms, em[2])
			c[em[2]] = '#define vV'..em[2]..'(_S, ...) ({ '
				..'__typeof__ (_S) _s = (_S); '
				..'_s->_M->'..em[2]..'('..(em[2]=='destroy' and '_s' or du)..', __VA_ARGS__); })'
			if arg.consts and arg.consts[em[2]] then
				local cn,as = table.unpack(arg.consts[em[2]])
				c[em[2]..'_const'] = '#ifndef '..cn..'\n'
					..as'def'(em[3]'def'('')())('\n', 'typedef `v`;')..'\n#endif'
			end
		end end
		ms = ms('', function(s)
			return '\t\t'..s:gsub('\n', '\n\t\t')..';\n' end)

		local ws = ''
		if arg.wrapperfor then ws = '\t'..arg.wrapperfor..' real;\n' end

		c[e] = 'struct '..e..' {\n'
			..ws
			..'\tconst struct '..e..'_M {\n'
			..ms
			..'\t} * _M;\n'
			..ds
			..'\tstruct '..e..'_I* _I;\n'
			..'};'

		c[e..'_c'] = da'def'('~')[1]:gsub('%(%*~%)',
			'vV'..(arg.wrapperfor and 'wrap' or 'create')..e:match'Vv(.+)')..';'
	end
	self.conv = error
	return {prefix=arg.prefix}
end

-- The environment construct. This is naturally the same between varients
function G.default:environment()
	function self:def(c, e, ds, f)
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
