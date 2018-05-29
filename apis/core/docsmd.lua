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
assert(specname and outdir, "Usage: lua btest.lua <spec name> <out directory>")
local f = assert(io.open(outdir..package.config:match'^(.-)\n'..specname..'.md', 'w'))
local spec = require(specname)
spec.__spec = specname

-- Docstring whitespace manager.
local function rewhite(base, pre)
	local whitepre = base:match '^%s*'
	local lines = {}
	for l in base:gmatch '[^\n]+' do if l:match '%g' then
		table.insert(lines, pre..(l:gsub(whitepre, '')))
	end end
	return table.concat(lines, '\n')
end

-- Find a suffix to indicate a type.
local function callit(ty, na)
	assert(ty, "Nil type!")
	if type(ty) == 'string' then return (na and na..' ' or '')..'('..ty..')'
	elseif ty.__name then return (na and na..' ' or '')..'('..ty.__name..')'
	elseif ty.__call then
		local as,rs = {},{}
		for _,a in ipairs(ty.__call) do
			assert(a.name, 'Anonymous __call fields are not allowed')
			assert(a.type, 'No type for __call field '..a.name)
			local x,y = '',''
			if a.canbenil then x,y = '[',']' end
			if a.name == 'return' then table.insert(rs, x..callit(a.type)..y)
			else table.insert(as, x..callit(a.type, a.name)..y) end
		end
		as = '('..table.concat(as, ', ')..')'
		if #rs > 0 then rs = ' -> '..table.concat(rs, ', ') else rs = '' end
		return (ty.__call.method and ':' or '.')..(na or 'function')..as..rs
	elseif ty.__index then
		local out = {}
		local fin = {}
		for _,e in ipairs(ty.__index or {}) do
			assert(e.name, 'Anonymous __index fields are not allowed')
			assert(e.type, 'No type for __index field '..e.name)
			if e.name == '__sequence' then
				table.insert(fin, callit(e.type))
				table.insert(fin, '...')
			else table.insert(out, callit(e.type, e.name)) end
		end
		for _,v in ipairs(fin) do table.insert(out, v) end
		return (na and na..' ' or '')..'{'..table.concat(out, ', ')..'}'
	else
		for k,v in pairs(ty) do print('>', k, v) end
		print('>>', ty, na)
		error 'Unable to handle type properly, probably should be named!'
	end
end

-- The main traversal
gen.traversal.df(spec, function(ty)
	assert(type(ty) == 'table', "Trying to handle a non-type-y type of type "
		..type(ty)..' ('..tostring(ty)..')')

	if ty.__name then
		f:write(('## %s%s\n%s\n'):format(ty.__name,
			ty.__raw and ' :{'..ty.__raw..'}' or '',
			rewhite(ty.__doc or 'No documentation.', '\t')))

		if ty.__call then
			f:write '### Calling Convention\n'
			f:write('\t'..callit({__call=ty.__call}, ty.__name)..'\n')
		end

		if ty.__index then
			f:write '### Contents\n'
			for _,e in ipairs(ty.__index) do
				assert(e.name, 'Anonymous __index fields are not allowed (in '..ty.__name..')')
				assert(e.version, 'No version for __index field '..e.name)
				assert(e.version:match '%d+%.%d+%.%d+', 'Invalid version '..e.version)
				assert(e.type, 'No type for __index field '..e.name)
				f:write(('\t- %s%s%s *[Added in v%s]*\n%s\n'):format(
					e.canbenil and '[' or '', callit(e.type, e.name),
					e.canbenil and ']' or '', e.version,
					rewhite(e.doc or 'No documentation.', '\t\t')))
				if e.setto then
					local a = {}
					for _,s in ipairs(e.setto) do a[#a+1] = ('`%s`'):format(s) end
					f:write('\t\t*Assigned as '..table.concat(a, ' or ')..'*\n')
				end
			end
		end

		if ty.__mask then
			f:write '### Bitmask Values\n'
			for _,e in ipairs(ty.__mask) do
				assert(e.name, 'Anonymous __mask fields are not allowed (in '..ty.__name..')')
				local flag = e.flag and " '"..e.flag.."'" or ''
				local raw = e.raw and " :{"..e.raw.."}" or ''
				f:write('\t- '..e.name..flag..raw..'\n')
			end
		end

		if ty.__enum then
			f:write '### Possible Values\n'
			for _,e in ipairs(ty.__enum) do
				assert(e.name, 'Anonymous __enum fields are not allowed (in '..ty.__name..')')
				local raw = e.raw and " :{"..e.raw.."}" or ''
				f:write('\t- '..e.name..raw..'\n')
			end
		end

		if ty.__directives then
			f:write '### Directives\n'
			for _,d in ipairs(ty.__directives) do f:write('- #'..d..'\n') end
		end

		f:write '\n'
	elseif ty == spec then
		coroutine.yield()
		if ty.__index then
			f:write '## Global Contents\n'
			for _,e in ipairs(ty.__index) do
				assert(e.name, 'Anonymous __index fields are not allowed')
				assert(e.version, 'No version for __index field '..e.name)
				assert(e.version:match '%d+%.%d+%.%d+', 'Invalid version '..e.version)
				assert(e.type, 'No type for __index field '..e.name)
				f:write(('\t- %s *[Added in v%s]*\n%s\n'):format(
					callit(e.type, e.name), e.version,
					rewhite(e.doc or 'No documentation.', '\t\t')))
				if e.setto then
					local a = {}
					for _,s in ipairs(e.setto) do a[#a+1] = ('`%s`'):format(s) end
					f:write('\t\t*Assigned as '..table.concat(a, ' or ')..'*\n')
				end
			end
		end
	else
		for k,v in pairs(ty) do print('>', k, v) end
		error 'Anonymous type that isn\'t the spec!'
	end
end)

-- Close up, to be nice to the OS
f:close()
