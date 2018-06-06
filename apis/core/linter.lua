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

-- Set the default output for `print` to stderr
io.output(io.stderr)
local function assert(t, s, from)
	if from then s = ('%s (in %s)'):format(s, from) end
	if not t then error(s) end
	return t
end
local function suggest(t, s, from)
	if from then s = ('%s (in %s)'):format(s, from) end
	if not t then print(s) end
	return t
end

-- All of the generators should be called with two arguments: the name of the
-- spec file (basename, for require), and the output directory to write to.
local specname,outdir = ...
assert(specname and outdir, "Not enough arguments to linter.lua")
local fname = outdir..package.config:match'^(.-)\n'..specname..'.lint'
local f = assert(io.open(fname, 'w'))
f:close()
local spec = require(specname)
spec.__spec = true

-- These are the standard string types, others cause warnings.
local smalltypes = {
	lightuserdata = true, string=true, number=true, boolean=true, integer=true,
	index = true,	-- Like integer, but -1 for C
}

-- Raw values are written as a Lua expression that should be very close to the
-- equivalent C. This tests whether the expression is valid.
local function testexp(ex, env, opt, from)
	opt = opt or {}
	local general
	local gf = function() return general end
	general = setmetatable({}, {
		__len = gf,
		__add = gf, __sub = gf, __mul = gf, __div = gf,
		__isobj = true,
	})
	local function obj(ents, self)
		local m,todo = {},{}
		if self then m.self = self end
		for _,e in ipairs(ents) do
			if e.type then if e.name then m[e.name] = e.type end else todo[e] = true end
		end
		repeat
			for td in pairs(todo) do
				if m[td.aliasof] then
					m[td.name] = m[td.aliasof]
					todo[td] = nil
					break
				end
			end
		until not next(todo)
		return setmetatable({}, {
			__index=function(t,k)
				assert(m[k], "Invalid access in expression "..ex.." (field "..k..")", from)
				t[k] = m[k].__index and obj(m[k].__index) or general
				return t[k]
			end,
			__len = function(self)
				assert(self.__sequence, "Tried to get length in expression "..ex)
				return general
			end,
			__isobj = true,
		})
	end

	assert(not ex:find'[][{}:"\']', "Non-C compatible characters in expression "..ex)

	local envmap = obj(env, opt.self)
	local out = assert(load('return ('..ex..')', nil, 't', envmap))()
	assert(type(out) == 'number' or (getmetatable(out) and getmetatable(out).__isobj),
		"All expressions should result in numbers or object-likes, got "..tostring(out)
		.." from "..ex)
end

-- List of leftover _-keys to warn about
local _keys = {}

-- Types tend to form trees... This tests whether a type is correct.
local tested = {}
local function testit(ty, from, opt)
	local function lintfor_(t)
		for k in pairs(t) do if type(k) == 'string' then
			if _keys[k] then _keys[k] = _keys[k] + 1 else
				if not suggest(not k:match '^_[^_]',
					"_-marked key "..k.." is left over, but shouldn't cause an issue") then
					_keys[k] = 1
				end
			end
		end end
	end

	opt = opt or {}
	tested[ty] = tested[ty] or {}
	for optd in pairs(tested[ty]) do
		local same = true
		for k,v in pairs(optd) do
			if opt[k] ~= v then same = false; break end
		end
		if same then return end
	end
	tested[ty][opt] = true

	if ty.__name then
		assert(type(ty.__name) == 'string', "__names should always be a string", from)
		from = ty.__name
	end

	assert(ty, "Types cannot be nil")
	if type(ty) == 'string' then
		suggest(smalltypes[ty], "Non-standard string type "..ty, from)
	else
		assert(type(ty) == 'table', "Types must be strings or tables", from)
		lintfor_(ty)
		assert(not opt.named or ty.__name, "Anonymous type where it shouldn't be", from)
		if ty.__raw then
			assert(type(ty.__raw) == 'table', "__raw should be a table", from)
			lintfor_(ty.__raw)
			suggest(type(ty.__raw.C) == 'string', "__raw should include a C varient", from)
		end
		if ty.__enum then
			assert(not ty.__index, "__enum types cannot have an __index", from)
			assert(not ty.__call, "__enum types cannot have a __call", from)
			assert(type(ty.__enum) == 'table', "__enum should be a table", from)
			lintfor_(ty.__enum)
			suggest(#ty.__enum > 0 or ty.__mask, "Empty __enum that isn't a __mask", from)
			local names = {}
			local flags = {}
			for _,e in ipairs(ty.__enum) do
				assert(type(e) == 'table', "__enum fields need to be tables", from)
				lintfor_(e)
				assert(type(e.name) == 'string', "__enum fields need names", from)
				assert(not names[e.name], "__enum field names must be unique: "..e.name, from)
				names[e.name] = e
				assert(ty.__mask or not e.flag, "Non-__mask __enums cannot have flags", from)
				if e.flag then
					assert(not flags[e.name], "__mask flags must be unique", from)
					flags[e.name] = e
				end
			end
			if ty.__raw then
				assert(type(ty.__raw.enum) == 'table', "No __raw data for __enum", from)
				for en,rw in pairs(ty.__raw.enum) do
					assert(names[en], "__raw enum entry for a non-existant enum", from)
					assert(type(rw) == 'table', "__raw enum entries should be strings", from)
					lintfor_(rw)
					suggest(type(rw.C) == 'string', "__raw enum entries should have C", from)
				end
			end
		end
		if ty.__index then
			assert(not ty.__enum, "__index types cannot have an __enum", from)
			assert(type(ty.__index) == 'table', "__index should be a table", from)
			lintfor_(ty.__index)
			suggest(#ty.__index > 0, "Empty __index type", from)
			local names = {}
			for _,e in ipairs(ty.__index) do
				assert(type(e) == 'table', "__index fields need to be tables", from)
				lintfor_(e)
				assert(e.name, "__index fields need names", from)
				names[e.name] = true
				if not e.aliasof then
					assert(e.type, "Non-alias __index fields need types", from..'.'..e.name)
					testit(e.type, from..'.'..e.name, {inindex=ty})
				end
			end
			for _,e in ipairs(ty.__index) do
				if e.aliasof then
					assert(names[e.aliasof], "Invalid __index aliasof '"..e.aliasof.."'", from..'.'..e.name)
				end
			end
			if names.__sequence then
				suggest(not next(names, '__sequence'),
					"__sequence types shouldn't have other fields, for C", from)
			end
			if ty.__raw then
				assert(type(ty.__raw.index) == 'table', "No __raw data for __index", from)
				lintfor_(ty.__raw.index)
				for _,e in ipairs(ty.__raw.index) do
					if type(e) == 'string' then
						assert(names[e], "__raw index field for a non-existant field", from)
					else
						assert(type(e) == 'table',
							"__raw index fields must be tables", from)
						lintfor_(e)
						assert(type(e.name) == 'string',
							"__raw index fields should be named", from)
						assert(e.value or e.values, "__raw call fields need a value", from)
						if e.value then
							assert(type(e.value) == 'string',
								"__raw index values should be strings", from)
							assert(not e.values, "Don't use both value and values...", from)
							testexp(e.value, ty.__index, nil, from)
						else
							lintfor_(e.values)
							for _,s in ipairs(e.values) do
								assert(type(s) == 'string',
									"__raw index values should be strings", from)
								testexp(s, ty.__index, nil, from)
							end
						end
					end
				end
			end
		end
		if ty.__call then
			assert(not ty.__enum, "__call types cannot have an __enum", from)
			assert(type(ty.__call) == 'table', "__call should be a table", from)
			lintfor_(ty.__call)
			local names = {}
			for _,e in ipairs(ty.__call) do
				assert(type(e) == 'table', "__call fields need to be tables", from)
				lintfor_(e)
				assert(e.ret or type(e.name) == 'string', "non-return __call fields need names", from)
				if e.name then names[e.name] = true end
				assert(e.type, "__call fields need types", from..'('..(e.name or '-'))
				testit(e.type, from..'('..(e.name or '-'))
			end
			if ty.__call.method then
				assert(opt.inindex, "__call methods must be accessable via an __index", from)
			end
			if ty.__raw then
				assert(type(ty.__raw.call) == 'table', "No __raw data for __call", from)
				lintfor_(ty.__raw.call)
				for _,e in ipairs(ty.__raw.call) do
					if type(e) == 'string' then
						assert(names[e], "__raw call field for a non-existant field", from)
					else
						assert(type(e) == 'table',
							"__raw call fields must be tables", from)
						lintfor_(e)
						assert(e.value or e.values, "__raw call fields need a value", from)
						if e.value then
							assert(type(e.value) == 'string',
								"__raw call value should be a string: "..tostring(e.value), from)
							assert(not e.values, "Don't use both value and values...", from)
							testexp(e.value, ty.__call, {self=ty.__call.method and opt.inindex}, from)
						else
							for _,s in ipairs(e.values) do
								assert(type(s) == 'string',
									"__raw call values should be strings: "..tostring(s), from)
								testexp(s, ty.__call, {self=ty.__call.method and opt.inindex}, from)
							end
						end
					end
				end
			end
		end
	end
end

-- The main traversal
gen.traversal.df(spec, function(ty)
	assert(type(ty) == 'table', "All traversed types must be tables, found "
		..tostring(ty).."!")
	assert(ty.__name or ty.__spec, "Attempt to traverse an anonymous type!")
	local function lintfor_(t)
		for k in pairs(t) do if type(k) == 'string' then
			suggest(not k:match '^_[^_]',
				"_-marked key "..k.." will be traversed, probably not intentional...")
		end end
	end
	lintfor_(ty)
	if ty.__name then
		testit(ty, ty.__name, {named=true})
	elseif ty.__spec then
		assert(ty == spec, "__spec is not a valid marker...")
		assert(not ty.__call, "__specs cannot be called")
		assert(not ty.__enum, "__specs cannot be enums")
		testit(ty, specname)
	end
	for k in pairs(ty) do
		assert(type(k) == 'string', "Only string keys are allowed in types")
		suggest(not k:match '^_[^_]', "_Key that will be traversed: "..k)
	end
end)

for k,c in pairs(_keys) do
	suggest(false, c.." appearances of _-marked key "..k)
end
