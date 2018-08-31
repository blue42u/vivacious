--[========================================================================[
   Copyright 2016-2018 Jonathon Anderson

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
-- luacheck: std lua53, new globals gen

-- Some types are basic.
local basetypes = {
	integer = 'long', number = 'float', index = 'int',
	string = 'const char*', userdata = 'void*',
	boolean = 'bool',
}

local g = gen.rules()

function g:postfooter()
	if self.specname then
		return '\n#undef IMP_CONST\n#endif // H_Vv_'..self.specname
	end
end

function g:footer() if self.specname then return false end end

function g:main()
	local out = gen.collector()
	if self.specname then
		out ''
		-- Specs are just plain different. As such, we handle them differently
		assert(not self.__enum, "Specs shouldn't have enums!")
		assert(not self.__newindex, "Specs need to be fully read-only!")
		assert(not self.__call, "A __call-able spec... NYI.")
		if self.__index then
			for n,e in pairs(self.__index) do
				if e.type then
					out((e.type.pref or e.type.ref or 'ERR `'):gsub('`', 'vV'..e.name),';')
				else
					out('// ',n,' = ',e.aliasof)
				end
			end
		end
		return out
	end

	-- Otherwise, divert to the three possible forms for this Type
	if not self.israw then
		if self.enum then out(self.enum)
		elseif self.struct then out(self.struct)
		else out(self.call) end
		out ''
	end

	if self.ismain then return out end
end

-- Method to propagate directives upwards to the spec
function g:directives()
	local dir = {}
	if self.__directives then
		for _,d in ipairs(self.__directives) do dir[d],dir[#dir+1] = #dir+1,d end
	end
	for _,sub in pairs(self) do
		for _,d in ipairs(sub.directives) do
			if dir[d] then dir[dir[d]] = false end
			dir[d],dir[#dir+1] = #dir+1,d
		end
	end
	return dir
end

-- Method to figure out the arguments list for __call-able Types
g:addrule('callret', 'callargs', 'callmargs', function(self)
	if not self.__call then return end
	-- First collect the arguments and decide on a return value
	local as,rs = {},{}
	local function addarg(e, ret)
		if e.type.isarray then
			assert(e.name, "Unnamed array!")
			table.insert(as, 'unsigned int '..(ret and '*' or '')..e.name..'_cnt')
			table.insert(as, (e.type.ref:gsub('`', e.name or '')))
		else
			if e.type.basic == 'string' and ret then
				assert(e.name, "Unnamed returning string!")
				table.insert(as, 'size_t *'..e.name..'_len')
			elseif e.type.basic == 'userdata' then
				assert(e.name, "Unnamed returning userdata!")
				table.insert(as, 'size_t '..(ret and '*' or '')..e.name..'_size')
			end
			table.insert(as, (e.type.ref:gsub('`', (ret and not e.type.needsderef and '*' or '')..(e.name or ''))))
		end
	end

	local mainret
	for _,e in ipairs(self.__call) do
		if e.ret then
			if e.mainret then
				assert(not mainret, "More than one mainret!")
				mainret = e
			end
			table.insert(rs, e)
		else addarg(e) end
	end
	if not mainret then mainret = rs[1] end	-- If nothing was marked mainret, use the first one
	if mainret and mainret.type.isarray then mainret = nil end -- Arrays aren't returned
	if self.__call.nomainret then mainret = nil end

	-- Collect the remaining returns as arguments
	for _,e in ipairs(rs) do if e ~= mainret then addarg(e, true) end end

	as = table.concat(as, ', ')
	return mainret, as, #as == 0 and '#' or '#, '..as
end)

-- Some Types don't have (much) output. This provides the ref in those cases.
g:addrule('israw', 'ref', 'header', 'wrap', function(self)
	if self.specname then
		local out = gen.collector()
		out [[
// Automatically generated file, do not edit directly

#include <stdlib.h>
#include <stdbool.h>]]
		for _,d in ipairs(self.directives) do out('#'..d) end
		out('\n#ifndef H_Vv_',self.specname,'\n#define H_Vv_',self.specname)
		out('\n#ifdef Vv_IMP_',self.specname,'\n#define IMP_CONST')
		out('#else\n#define IMP_CONST const\n#endif\n')
		return false, nil, out
	end

	if self.basic then
		local b = basetypes[self.basic]
		assert(b, "No basetype for "..self.basic)
		if self.__name then
			return 'Vv'..self.__name..' `', 'typedef '..b..' Vv'..self.__name..';'
		else return true, b..' `' end
	elseif self.__raw then
		assert(self.__raw.C, "No __raw C field for "..self.name)
		local r = self.__raw.C..(self.__raw.dereference and '*' or '')..' `'
		local wrap
		if self.__call and self.__raw.call then
			wrap = function(selfty)
				local as = {}
				for _,re in ipairs(self.__raw.call) do
					as[#as+1] = gen.express(re.values or re.value, {
						len = function(n) return n..'_cnt' end,
						udlen = function(n) return n..'_size' end,
						ref = function(...)
							local ns = {...}
							local t = ns[1] == 'self' and selfty or self.__call.e[ns[1]].type
							local o = ns[1]
							for i=2,#ns do
								o = o..(t.needsderef and '->' or '.')..ns[i]
								t = t.__index and t.__index.e[ns[i]].type or t.__newindex and t.__newindex.e[ns[i]].type
							end
							return o
						end
					}, self.__call.e, selfty)
				end
				return '`('..table.concat(as, ', ')..')'
			end
		end
		return true, r, '', wrap
	end
end)

function g:needsderef()
	if self.basic then return false end
	return not not self.ref:find('%*%s*`')
end

-- Arrays are fairly well-defined, and easy to handle when they pop up.
g:addrule('isarray', '-ref', function(self)
	local ty,rep
	if self.__index and self.__index[1] and self.__index[1].name == '__sequence' then
		assert(not self.__newindex, "C can't handle arrays with more stuff!")
		assert(#self.__index == 1, "C can't handle arrays with other items!")
		ty,rep = self.__index[1].type, 'IMP_CONST`'
	elseif self.__newindex and self.__newindex[1] and self.__newindex[1].name == '__sequence' then
		assert(not self.__index, "C can't handle arrays with more stuff!")
		assert(#self.__newindex == 1, "C can't handle arrays with other items!")
		ty,rep = self.__newindex[1].type, '`'
	end
	if ty then
		if not (ty.__raw and ty.__raw.dereference) then rep = rep:gsub('`', '* `') end
		return true, ty.ref:gsub('`', rep)
	else return false end
end)

-- Enums are probably the simplest Types to handle
g:addrule('enum', '-ref', '-header', function(self)
	if not self.__enum or self.__raw then return end

	local out = gen.collector()
	out('enum ',self.__name and 'Vv'..self.__name,' {')
	for _,e in ipairs(self.__enum) do out('\t',e.name,',') end
	out '};'

	if self.__name then
		return out, 'Vv'..self.__name..' `', 'typedef enum Vv'..self.__name..' Vv'..self.__name..';'
	else return out end
end)

-- When a Type needs to be written out as a struct, this handles the pieces
-- Split into parts to handle recursion.
function g:isstruct()
	if not self.__index and not self.__newindex or self.isarray then return end
	return true
end
g:addrule('-ref', '-header', function(self)
	if not self.isstruct then return end
	if self.__name then
		return 	'Vv'..self.__name..'* `',
			'typedef struct Vv'..self.__name..' Vv'..self.__name..';'
	else return self.structref end
end)
g:addrule('struct', 'structref', '-footer', function(self)
	if not self.isstruct then return end

	local out,sref = gen.collector(), gen.collector()
	if self.__name then out('struct Vv'..self.__name..' {')
	else out 'struct {' end
	if self.__index then out('\tconst struct Vv',self.__name,'_M {') end
	out(self.scallm)
	out(self.indexm)
	out(self.newindexm)
	if self.__index then out('\t} *_M;') end
	out(self.scall)
	out(self.index)
	out(self.newindex)
	sref(out)
	sref '} `'
	out('};')
	local fout = gen.collector()
	fout(self.scalla)
	fout(self.indexa)
	fout(self.newindexa)
	return out, sref, fout
end)

-- Structified component for __call
g:addrule('scall', 'scallm', 'scalla', function(self)
	if not self.__call then return end
	-- TODO: Figure out the C way to put callables in
	local mout,aout = gen.collector(), gen.collector()
	mout('\t',
		(self.callret and self.callret.type.ref or 'void `'):gsub('`','(*_activate)('..self.callargs..')'),
	';')
	aout '#ifdef __GNUC__'
	aout('#define vV(_S, ...) ({ __auto_type _s = (_S); _s->_M->_activate(_s, ##__VA_ARGS__ ); })')
	aout '#endif'
	return nil, mout, aout
end)

g:addrule('ifdefpre', 'ifdefelse', 'ifdefpost', function(self)
	if not self.__ifdef then return end
	local consts = {}
	for i,c in ipairs(self.__ifdef) do consts[i] = 'defined('..c..')' end

	local els = gen.collector()
	if self.__ifndef then
		els '#else'
		els '\t`'
	end

	return '#if '..table.concat(consts, ' && '), els, '#endif'
end)

-- Structified component for __index
g:addrule('index', 'indexm', 'indexa', function(self)
	if not self.__index or self.isarray then return end

	local mout,out,aout = gen.collector(),gen.collector(),gen.collector()
	local sref
	if self.__name then
		sref = 'Vv'..self.__name..'* self'	-- Result from structification
	end
	for n,e in pairs(self.__index) do
		if e.type then
			if e.type.isarray then
				out('\tIMP_CONST unsigned int ',n,'_cnt;')
			end
			if not e.type.wrap and e.type.mref and sref then
				mout(e.type.ifdefpre)
				local rep = {['`']=n, ['#']=sref}
				mout('\t',e.type.mref:gsub('[`#]',rep),';')
				mout(e.type.ifdefelse and tostring(e.type.ifdefelse)
					:gsub('`', (e.type.__ifndef.mref or e.type.__ifndef.ref):gsub('[`#]', rep)..';'))
				mout(e.type.ifdefpost)

				aout '#ifdef __GNUC__'
				aout('#define vV',n,'(_S, ...) ({ __auto_type _s = (_S); ',
					'_s->_M->',n,'(_s, ##__VA_ARGS__ ); })')
				aout '#endif'
			else
				out(e.type.ifdefpre)
				out('\t',e.type.ref:gsub('`', 'IMP_CONST '..n),';')
				out(e.type.ifdefelse and tostring(e.type.ifdefelse)
					:gsub('`', e.type.__ifndef.ref:gsub('`', 'IMP_CONST '..n)..';'))
				out(e.type.ifdefpost)
				if e.type.wrap then	-- It's a __raw __call-able
					assert(sref, "Raw __callables can only be part of named things!")
					aout(e.type.ifdefpre)
					aout('static inline ',
						e.type.pmref:gsub('[`#]', {['`']='vV'..n, ['#']=sref}),' {')
					aout('\t',e.type.callret and 'return ','self->',e.type.wrap(self):gsub('`',n),';')
					aout '}'
					aout(e.type.ifdefpost)
				end
			end
		else
			out('\t// ',e.name,' = ',e.aliasof)
		end
	end
	return out, mout, aout
end)

-- Structified component for __newindex
g:addrule('newindex', 'newindexm', 'newindexa', function(self)
	if not self.__newindex or self.isarray then return end

	local out = gen.collector()
	for n,e in pairs(self.__newindex) do
		if e.type then
			if e.type.isarray then out('\tunsigned int ',n,'_cnt;') end
			out('\t',e.type.ref:gsub('`',n),';')
		else out('\t// ',n,' = ',e.aliasof) end
	end
	return out
end)

-- The final form is that of a pure callable. This handles that case.
g:addrule('call', '-ref', '-mref', '-pref', '-pmref', '-header', function(self)
	if not self.__call then return end

	local mref = self.callret and self.callret.type.ref or 'void `'
	if self.__name then
		return nil,
			'Vv'..self.__name..' `',	-- Version for structure elements
			'Vv'..self.__name..' `',	-- Version for structure method elements
			mref:gsub('`', '`('..self.callargs..')'),	-- Form for prototypes
			mref:gsub('`', '`('..self.callmargs..')'),	-- Form for prototypical methods
			'typedef '..mref:gsub('`', '(*Vv'..self.__name..')('..self.callargs..')')..';'
	else
		return nil,
			mref:gsub('`', '(*`)('..self.callargs..')'),	-- For structure elements
			mref:gsub('`', '(*`)('..self.callmargs..')'),	-- For structure methods
			mref:gsub('`', '`('..self.callargs..')'),	-- For prototypes
			mref:gsub('`', '`('..self.callmargs..')')	-- For prototypical methods
	end
end)

return g
