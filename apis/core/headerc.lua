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

local gen = require 'apis.core.generation'

-- Nab the arguments, and get ready for the storm.
local specname,outdir = ...
local f = assert(io.open(outdir..package.config:match'^(.-)\n'..specname..'.h', 'w'))
local spec = require(specname)

-- Whitespace management helper
local function indent(s, pre)
	pre = pre or '\t'
	local lines = {}
	for l in s:gmatch '[^\n]+' do table.insert(lines, pre..l) end
	return table.concat(lines, '\n')
end

-- Check if an expression (from __raw.*.value[s]) will work as C code, and
-- perform any nessesary transformations to make it valid C.
-- Returns the C expression and the base variables it references
local callit
local function exptoC(ex, env, opt, raw)
	if type(ex) ~= 'string' then ex = ex[1] end
	return ex:gsub('[%w.]+', function(ref)
		if not ref:find '%.' then return ref else
			local isptr,m = {},{}
			for _,e in ipairs(env or {}) do
				if e.name then
					isptr[e.name],m[e.name] = callit(e.type, ''):find '%*', e.type
				end
			end
			if opt and opt.self then
				isptr.self = callit(opt.self, 'self'):find '%*'
				m.self = opt.self
			end

			local new = {}
			for p in (ref..'.'):gmatch '([^.]+)%.' do
				new[#new+1] = p
				new[#new+1] = isptr[p] and '->' or '.'
				local ty = m[p]
				isptr,m = {},{}
				for _,e in ipairs(ty.__index or {}) do if not e.aliasof then
					isptr[e.name],m[e.name] = callit(e.type, '', {noself=true}):find '%*', e.type
				end end
			end
			table.remove(new)
			return table.concat(new)
		end
	end):gsub('#([%w.>-]+)', '%1_cnt')
end

-- Get a string representing a typed name.
local basetypes = {
	integer = 'long', number = 'float',
	index = 'int',
	string = 'const char*',
	lightuserdata = 'void*',
	boolean = 'bool',
}
function callit(ty, na, opt)
	local sna = na and ' '..na or ''
	local asna = (opt and opt.inarr and '' or '*')..sna
	if type(ty) == 'string' then return basetypes[ty]..sna
	elseif ty.__raw and (not opt or not opt.noraw) then
		assert(ty.__raw.C, "No C field for "..tostring(ty.__raw))
		if ty.__raw.dereference then
			return ty.__raw.C..((opt and (opt.ret or opt.inarr)) and '' or '*')..sna
		else return ty.__raw.C..sna end
	elseif ty.__name then return 'Vv'..ty.__name..asna
	elseif ty.__call then
		local as = {}

		-- Add in the nessesary self or udata argument
		if not opt or not opt.noself then
			if ty.__call.method then
				assert(opt and opt.self, "No available self for method!")
				table.insert(as, callit(opt.self, 'self'))
			else table.insert(as, callit('lightuserdata', 'udata')) end
		end

		-- Handy markings
		local raws = {}
		for _,re in ipairs(ty.__raw and ty.__raw.call or {}) do
			if re.value then raws[re.value] = re else
				for _,x in ipairs(re.values) do raws[x] = re end
			end
		end

		-- Gather up the real arguments
		local rets = {}
		for _,a in ipairs(ty.__call) do
			if a.ret then rets[#rets+1] = a else
				-- If we have an array (or need the length), we need to include its length
				local lname = '#'..a.name
				if a.type.__index and a.type.__index[1].name == '__sequence' or raws[lname] then
					local lentype = {__raw={C='size_t'}}
					if raws[lname] and raws[lname].type then lentype = raws[lname].type end
					as[#as+1] = callit(lentype, a.name..'_cnt')
				end
				-- Add in the argument
				as[#as+1] = callit(a.type, a.name)
			end
		end

		-- Decide what should be the return for C
		local ret
		for _,r in ipairs(rets) do
			if r.mainret then assert(not ret, 'Multiple mainrets!'); ret = r end
		end
		if not ret then	-- If there are no mainret's, then just use the first one
			ret = rets[1]
			if ret and ret.type.__index and ret.type.__index[1].name == '__sequence' then
				ret = nil	-- Arrays aren't returned that way
			end
		end
		if ty.__call.nomainret then ret = nil end

		-- Add the leftover returns as arguments
		for _,r in ipairs(rets) do if r ~= ret then
			local inarr = r.type.__index and r.type.__index[1].name == '__sequence'
			local lname = '#'..r.name
			if inarr or raws[lname] then
				local lentype = {__raw={C='size_t'}}
				if raws[lname] and raws[lname].type then lentype = raws[lname].type end
				as[#as+1] = callit(lentype, '*'..(r.name and r.name..'_cnt' or ''), {ret=true})
			end
			as[#as+1] = callit(r.type, (inarr and '' or '*')..(r.name or ''), {ret=true})
		end end

		-- The final result
		ret = ret and ret.type or {__raw={C='void'}}
		if opt and opt.proto then
			return callit(ret, (na or '')..'('..table.concat(as,', ')..')')
		else
			return callit(ret, '(*'..(na or '')..')('..table.concat(as,', ')..')')
		end
	elseif ty.__index then
		local out = {}
		local udatad = false
		for _,e in ipairs(ty.__index or {}) do
			if e.name == '__sequence' then
				assert(#ty.__index == 1, '__sequence __index fields must be alone')
				return callit(e.type,
					(opt and opt.ret and '' or 'const')..' *'..(na or ''), {inarr=true})
			else
				if not udatad and e.type.__call then
					table.insert(out, callit('lightuserdata', 'udata'))
					udatad = true
				end
				if e.type.__index and e.type.__index[1].name == '__sequence' then
					table.insert(out, 'size_t '..e.name..'_cnt')
				end
				table.insert(out, callit(e.type, e.name))
			end
		end
		for i,s in ipairs(out) do out[i] = indent(s)..';\n' end
		na = na or ''
		return 'struct {\n'..table.concat(out)..'} '..na
	else
		for k,v in pairs(ty) do print('>', k, v) end
		print('>>', ty, na)
		error 'Unable to handle type properly, probably should be named!'
	end
end

-- The main traversal
gen.traversal.df(spec, function(ty)
	if ty.__name then if not ty.__raw then
		if ty.__directives then
			for _,d in ipairs(ty.__directives) do f:write('#'..d..'\n') end
		end

		if ty.__index then
			f:write('typedef struct Vv'..ty.__name..' Vv'..ty.__name..';\n')
			coroutine.yield 'post'
			f:write('struct Vv'..ty.__name..' {\n')
			local foundone,rawcall = false, {}
			for _,e in ipairs(ty.__index) do if not e.aliasof then
				local ifdef,ifndef
				if e.type.__ifdef then
					local ss = {}
					for i,s in ipairs(e.type.__ifdef) do ss[i] = 'defined('..s..')' end
					ifdef = table.concat(ss, ' && ')
					ifndef = assert(e.type.__ifndef, "Type with __ifdef but not __ifndef")
				end

				if e.type.__call and e.type.__call.method then
					if not foundone then
						f:write('\tconst struct Vv'..ty.__name..'_M {\n')
						foundone = true
					end
					if ifdef then f:write('#if '..ifdef..'\n') end
					f:write(indent(callit(e.type, e.name, {self=ty}), '\t\t')..';\n')
					if ifdef then
						f:write '#else\n'
						f:write(indent(callit(ifndef, e.name, {self=ty}), '\t\t')..';\n')
						f:write '#endif\n'
					end
					if e.type.__raw then	-- Raw callables are special...
						rawcall[e] = ifdef or false
					else
						f:write('#ifdef __GNUC__\n#define vV'..e.name
							..'(_S, ...) ( __typeof__(_S) _s = (_S),  _s->_M->'..e.name
							..'(_s, ##__VA_ARGS__ ) )\n#endif\n')
					end
				end
			end end
			if foundone then f:write('\t} *_M;\n') end
			local udatad = false
			for _,e in ipairs(ty.__index) do if not e.aliasof then
				if not udatad and e.type.__call and not e.type.__call.method then
					f:write('\tvoid* udata;\n')
					udatad = true
				end
				if e.type.__index and e.type.__index[1]
					and e.type.__index[1].name == '__sequence' then
						f:write('\tsize_t '..e.name..'_cnt;\n')
				end
				if not e.type.__call or not e.type.__call.method then
					if e.type.__ifdef then
						local ss = {}
						for _,s in ipairs(e.type.__ifdef) do ss[#ss+1] = 'defined('..s..')' end
						f:write('#if '..table.concat(ss, ' && ')..'\n')
					end
					f:write(indent(callit(e.type, e.name, {self=ty}))..';\n')
					if e.type.__ifdef then
						f:write '#else\n'
						assert(e.type.__ifndef, 'Type with __ifdef but not __ifndef!')
					f:write(indent(callit(e.type.__ifndef, e.name, {self=ty}))..';\n')
						f:write '#endif\n'
					end
				end
			end end
			f:write('};\n\n')
			coroutine.yield 'post'
			for e,ifdef in pairs(rawcall) do
				local args = {}
				for _,re in ipairs(e.type.__raw.call) do
					local ex = exptoC(re.value or re.values, e.type.__call,
						{self=ty}, e.type.__raw.call)
					args[#args+1] = ex
				end

				if ifdef then f:write('#if '..ifdef..'\n') end
				f:write('static inline '..callit(e.type, 'vV'..e.name,
					{self=ty, proto=true, noraw=true})..' {\n')
				f:write('\treturn self->_M->'..e.name..'('..table.concat(args, ', ')..');\n')
				f:write '}\n'
				if ifdef then f:write '#endif\n' end
			end
		end
	end elseif ty == spec then
		coroutine.yield 'sub'	-- Wait for sub-things
		f:write '\n'
		if ty.__index then
			for _,e in ipairs(ty.__index) do
				f:write(callit(e.type, 'vV'..e.name, {proto=true, noself=true})..';\n')
			end
		end
	end
end)

-- Close up, to be nice to the OS
f:close()
