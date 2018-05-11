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

-- Nab the arguments, and get ready for the storm.
local spec,outdir = ...
assert(spec and outdir, "Usage: lua btest.lua <spec name> <out directory>")
local f = io.open(outdir..package.config:match'^(.-)\n'..spec..'.md', 'w')
spec = require(spec)

-- Traversal function. Separated to allow for more interesting traversals.
-- `handler` is called with the type, and returns a set of keys that have been
-- handled and should be ignored, all others are considered sub-tree links. It
-- may also return a function that will be called once the entire sub-tree has
-- been traversed.
local function traverse(start, handler)
	local done = {}
	local function trav(ty)
		if done[ty] then return else done[ty] = true end
		local handled,post = handler(ty)
		if type(ty) == 'table' then
			for k,s in pairs(ty) do  if not handled[k] then trav(s) end end
		end
		if post then post() end
	end
	trav(start)
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

-- Docstring whitespace manager.
local function rewhite(base, pre)
	local whitepre = base:match '^%s*'
	local lines = {}
	for l in base:gmatch '[^\n]+' do if l:match '%g' then
		table.insert(lines, pre..(l:gsub(whitepre, '')))
	end end
	return table.concat(lines, '\n')
end

-- The main traversal
traverse(spec, function(ty)
	assert(type(ty) == 'table', "Trying to handle a non-type-y type of type "..type(ty)
		..' ('..tostring(ty)..')')
	local handled = setmetatable({__raw=true},
		{__index=function(_,k) assert(not k:match '^__', "Unhandled special "..k) end})
	if ty.__name then
		f:write(('## %s\n%s\n'):format(ty.__name,
			rewhite(ty.__doc or 'No documentation.', '\t')))
		handled.__name, handled.__doc = true,true

		if ty.__index then
			handled.__index = true
			f:write '### Contents\n'
			local version
			for _,e in ipairs(ty.__index) do
				if type(e) == 'string' then
					assert(e:match '%d+%.%d+%.%d+', 'Invalid version string: '..e)
					version = e
				else
					local v = e.version or version
					assert(e.name, 'Anonymous entries are not allowed!')
					assert(v, 'No version for entry '..e.name)
					assert(e.type, 'No type for entry '..e.name)
					f:write(('\t- %s *[Added in v%s]*\n%s\n'):format(
						callit(e.type, e.name), v,
						rewhite(e.doc or 'No documentation.', '\t\t')))
				end
			end
			f:write '\n'
		end

		if ty.__mask then
			handled.__mask = true
			f:write '### Bitmask Values\n'
			for _,e in ipairs(ty.__mask) do
				f:write('\t- '..e.name..' \''..e.flag..'\' ('..e.raw..')\n')
			end
			f:write '\n'
		end

		if ty.__enum then
			handled.__enum = true
			f:write '### Possible Values\n'
			for _,e in ipairs(ty.__enum) do
				f:write('\t- '..e.name..' ('..e.raw..')\n')
			end
			f:write '\n'
		end

		handled.__format, handled.__frommatch, handled.__fromtable, handled.__fromnil
			= true,true,true,true

		handled.__directives = true

		f:write '\n'
	elseif ty == spec then	-- The specification "type" is a little special...
		handled.__index,handled.__directives = true,true
		return handled, function()
			if ty.__index then
				f:write '## Global Contents\n'
				local version
				for _,e in ipairs(ty.__index) do
					if type(e) == 'string' then
						assert(e:match '%d+%.%d+%.%d+', 'Invalid version string: '..e)
						version = e
					else
						local v = e.version or version
						assert(e.name, 'Anonymous entries are not allowed!')
						assert(v, 'No version for entry '..e.name)
						assert(e.type, 'No type for entry '..e.name)
						f:write(('\t- %s *[Added in v%s]*\n%s\n'):format(
							callit(e.type, e.name), v,
							rewhite(e.doc or 'No documentation.', '\t\t')))
					end
				end
				f:write '\n'
			end
		end
	else
		for k,v in pairs(ty) do print('>', k, v) end
		error 'Anonymous type that isn\' the spec!'
	end
	return handled
end)

-- Close up, to be nice to the OS
f:close()
