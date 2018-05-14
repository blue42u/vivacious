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
assert(specname and outdir, "Usage: lua *.lua <spec name> <out directory>")
local f = assert(io.open(outdir..package.config:match'^(.-)\n'..specname..'.h', 'w'))
local spec = require(specname)

-- Whitespace management helper
local function indent(s, pre)
	pre = pre or '\t'
	local lines = {}
	for l in s:gmatch '[^\n]+' do table.insert(lines, pre..l) end
	return table.concat(lines, '\n')
end

-- Get a string representing a typed name.
local basetypes = {
	integer = 'long', number = 'float',
	index = 'int',
	string = 'const char*',
	lightuserdata = 'void*',
	boolean = 'bool',
}
local function callit(ty, na, opt)
	assert(ty, "Nil type! "..tostring(na)..' '..tostring(opt))
	local sna = na and ' '..na or ''
	if type(ty) == 'string' then
		assert(basetypes[ty], 'Unknown basic type '..ty)
		return basetypes[ty]..sna
	elseif ty.__raw then return ty.__raw..sna
	elseif ty.__name then return 'Vv'..ty.__name..((opt and opt.inarr) and '' or '*')..sna
	elseif ty.__call then
		local as = {}
		if not opt or not opt.standard then
			if ty.__call.method then
				assert(opt and opt.self, 'Method __index without a self!')
				table.insert(as, callit(opt.self, 'self'))
			else table.insert(as, 'void* udata') end
		end
		local rets = {}
		for _,a in ipairs(ty.__call) do
			assert(a.name, 'Anonymous __call fields are not allowed')
			assert(a.type, 'No type for __call field '..a.name)
			if a.name == 'return' then table.insert(rets, a)
			else table.insert(as, callit(a.type, a.name)) end
		end
		local ret
		for _,r in ipairs(rets) do if r.mainret then
			assert(not ret, 'Multiple mainrets!'); ret = r end end
		if not ret then	-- If there are no mainret's, then try one that can't be nil
			local nrets = {}
			for _,r in ipairs(rets) do if not r.canbenil then table.insert(nrets, r) end end
			if #nrets > 0 then ret = nrets[1]
			else ret = rets[1] end	-- Just take the first one
		end
		for _,r in ipairs(rets) do if r ~= ret then table.insert(as, callit(r.type, '*')) end end
		ret = ret and ret.type or {__raw='void'}
		if opt and opt.standard then
			return callit(ret, (na or '')..'('..table.concat(as,', ')..')')
		else
			return callit(ret, '(*'..(na or '')..')('..table.concat(as,', ')..')')
		end
	elseif ty.__index then
		local out = {}
		local udatad = false
		for _,e in ipairs(ty.__index or {}) do
			assert(e.name, 'Anonymous __index fields are not allowed')
			assert(e.type, 'No type for __index field '..e.name)
			if e.name == '__sequence' then
				assert(#ty.__index == 1, '__sequence __index fields must be alone')
				return callit(e.type, 'const *'..(na or ''), {inarr=true})
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
local post = {}
gen.traversal.df(spec, function(ty)
	assert(type(ty) == 'table', "Trying to handle a non-type-y type of type "
		..type(ty)..' ('..tostring(ty)..')')

	if ty.__name then if not ty.__raw then
		if ty.__directives then
			for _,d in ipairs(ty.__directives) do f:write('#'..d..'\n') end
		end

		if ty.__index then
			f:write('typedef struct Vv'..ty.__name..' Vv'..ty.__name..';\n')
			table.insert(post, function()
				f:write('struct Vv'..ty.__name..' {\n')
				local foundone = false
				for _,e in ipairs(ty.__index) do
					if e.type.__call and e.type.__call.method then
						if not foundone then
							f:write('\tconst struct Vv'..ty.__name..'_M {\n')
							foundone = true
						end
						f:write(indent(callit(e.type, e.name, {self=ty}), '\t\t')..';\n')
					end
				end
				if foundone then f:write('\t} *_M;\n') end
				local udatad = false
				for _,e in ipairs(ty.__index) do
					assert(e.name, 'Anonymous __index fields are not allowed')
					assert(e.version, 'No version for __index field '..e.name)
					assert(e.version:match '%d+%.%d+%.%d+', 'Invalid version '..e.version)
					assert(e.type, 'No type for __index field '..e.name)
					if not udatad and e.type.__call and not e.type.__call.method then
						f:write('\tvoid* udata;\n')
						udatad = true
					end
					if e.type.__index and e.type.__index[1]
						and e.type.__index[1].name == '__sequence' then
							f:write('\tsize_t '..e.name..'_cnt;\n')
					end
					if not e.type.__call or not e.type.__call.method then
						f:write(indent(callit(e.type, e.name, {self=ty}))..';\n')
					end
				end
				f:write('};\n\n')
			end)
			return
		end

		if ty.__mask then error '__mask not handled in headerc yet' end

		if ty.__enum then error '__enum not handled in headerc yet' end

		f:write '\n'
	end elseif ty == spec then
		coroutine.yield()
		f:write '\n'
		if ty.__index then
			for _,e in ipairs(ty.__index) do
				assert(e.name, 'Anonymous __index fields are not allowed')
				assert(e.version, 'No version for __index field '..e.name)
				assert(e.version:match '%d+%.%d+%.%d+', 'Invalid version '..e.version)
				assert(e.type, 'No type for __index field '..e.name)
				f:write(callit(e.type, 'vV'..e.name, {standard=true})..';\n')
			end
		end
	else
		for k,v in pairs(ty) do print('>', k, v) end
		error 'Anonymous type that isn\'t the spec!'
	end
end)

f:write '\n'
for _,p in ipairs(post) do p() end

-- Close up, to be nice to the OS
f:close()
