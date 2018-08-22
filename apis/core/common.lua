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

-- Common functions for specification files, to aid with common techniques.
-- Unlike usual, these are loaded into the global table.

-- Sequences of types are common. `array[<type>]` or `array(<type>)` will lazily
-- create a type that represents a sequence of `<type>`.
-- luacheck: new globals array
local arraymeta = {}
array = setmetatable({}, arraymeta)

function arraymeta:__call(k) return self[k] end

function arraymeta:__index(k)
	self[k] = {__newindex={{version='0.0.0', name='__sequence', type=k}}}
	return self[k]
end

-- This is the second form of array, which marks the resulting sequence type
-- as read-only, so that entries cannot be created or edited.
-- luacheck: new globals constarray
local carraymeta = {}
constarray = setmetatable({}, carraymeta)

function carraymeta:__call(k) return self[k] end

function carraymeta:__index(k)
	self[k] = {__index={{version='0.0.0', name='__sequence', type=k}}}
	return self[k]
end

-- Methods are implemented as __index-able fields that are __call-able, to match
-- with the standard Lua techique. This tends to look ugly in practice, so this
-- allows the use of `method{<name>, <doc>, {<name>, <type>}...}` as an
-- alternative. The varient `callable{...}` is similar, but does not mark the
-- result to be called with `:`, i.e. it has no self argument.
-- luacheck: new globals callable method

function callable(base)
	if type(base[1]) == 'string' then base.name = table.remove(base, 1) end
	if type(base[1]) == 'string' then base.doc = table.remove(base, 1) end
	base.type = {__call={}}
	for i,v in ipairs(base) do
		v.name,v.type = v.name or v[1], v.type or v[2]
		base.type.__call[i] = v
		base[i] = nil
	end
	return base
end

function method(base)
	base = callable(base)
	base.type.__call.method = true
	return base
end

-- Versions are attached to each __index entry, but usually multiple entries are
-- added in a single version. In addition, entries are usually added to the end
-- combined with an increase in version. `versioned` allows strings to appear
-- between __index entries, and an entry will obtain the last stated version.
-- luacheck: new globals versioned

function versioned(ind)
	local version
	local i = 1
	while ind[i] do
		if type(ind[i]) == 'string' then version = table.remove(ind, i) else
			ind[i].version = assert(version, 'Version not yet specified!')
			i = i + 1
		end
	end
	return ind
end

-- Sometimes an extra file needs to be accessed, which can be referenced by the
-- usual file paths. This function will search for and open a file with the
-- given extension on Lua's require paths, using '/' as the directory separator.
-- luacheck: new globals openfile

function openfile(path)
	local fn = assert(package.searchpath(path, package.path:gsub('%.lua', ''), '/'))
	return assert(io.open(fn, 'r'))
end
