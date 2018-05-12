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

local gen = require 'core.generation'

-- Nab the arguments, and get ready for the storm.
local spec,outdir = ...
assert(spec and outdir, "Usage: lua btest.lua <spec name> <out directory>")
local f = io.open(outdir..package.config:match'^(.-)\n'..spec..'.md', 'w')
spec = require(spec)

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
	if type(ty) == 'string' then return (na and na..' ' or '')..'('..ty..')'
	elseif ty.__name then return (na and na..' ' or '')..'('..ty.__name..')'
	elseif ty.__call then
		local as,rs = {},{}
		for _,a in ipairs(ty.__call) do
			if a.name == 'return' then table.insert(rs, callit(a.type))
			else table.insert(as, callit(a.type, a.name)) end
		end
		as = '('..table.concat(as, ', ')..')'
		if #rs > 0 then rs = ' -> '..table.concat(rs, ', ') else rs = '' end
		return (ty.__call.method and ':' or '.')..(na or 'function')..as..rs
	elseif ty.__index then
		local out = {}
		local fin = {}
		for _,e in ipairs(ty.__index or {}) do
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
gen.traversal.df(spec, function(ty, res)
	assert(type(ty) == 'table', "Trying to handle a non-type-y type of type "..type(ty)
		..' ('..tostring(ty)..')')

	if ty.__name then
		res.__name, res.__doc = true, true
		f:write(('## %s\n%s\n'):format(ty.__name,
			rewhite(ty.__doc or 'No documentation.', '\t')))

		function res.__index(es)
			f:write '### Contents\n'
			for _,e in ipairs(es) do
				assert(e.name, 'Anonymous __index fields are not allowed')
				assert(e.version, 'No version for __index field '..e.name)
				assert(e.version:match '%d+%.%d+%.%d+', 'Invalid version '..e.version)
				assert(e.type, 'No type for __index field '..e.name)
				f:write(('\t- %s *[Added in v%s]*\n%s\n'):format(
					callit(e.type, e.name), e.version,
					rewhite(e.doc or 'No documentation.', '\t\t')))
			end
		end

		function res.__mask(vals)
			f:write '### Bitmask Values\n'
			for _,e in ipairs(vals) do
				f:write('\t- '..e.name..' \''..e.flag..'\' ('..e.raw..')\n')
			end
			f:write '\n'
		end

		function res.__enum(vals)
			f:write '### Possible Values\n'
			for _,e in ipairs(vals) do
				f:write('\t- '..e.name..' ('..e.raw..')\n')
			end
			f:write '\n'
		end

		function res.__directives(dirs)
			f:write '### Directives\n'
			for _,d in ipairs(dirs) do f:write('- #'..d..'\n') end
			f:write '\n'
		end

		res.__raw = true

		return function()
			f:write '\n'
		end
	elseif ty == spec then
		function res.__index(es) return function()
			f:write '## Global Contents\n'
			for _,e in ipairs(es) do
				assert(e.name, 'Anonymous __index fields are not allowed')
				assert(e.version, 'No version for __index field '..e.name)
				assert(e.version:match '%d+%.%d+%.%d+', 'Invalid version '..e.version)
				assert(e.type, 'No type for __index field '..e.name)
				f:write(('\t- %s *[Added in v%s]*\n%s\n'):format(
					callit(e.type, e.name), e.version,
					rewhite(e.doc or 'No documentation.', '\t\t')))
			end
		end end
	else
		for k,v in pairs(ty) do print('>', k, v) end
		error 'Anonymous type that isn\' the spec!'
	end
end)

-- Close up, to be nice to the OS
f:close()
