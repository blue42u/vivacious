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
	end
	return base
end

function method(base)
	base = callable(base)
	base.type.__call.method = true
	return base
end
