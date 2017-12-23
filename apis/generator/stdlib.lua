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

local G = require 'generator'
local stdlib = setmetatable({}, {__index=_ENV})

-- Handy string-application with formatting
local function strapply(s, t)
	return string.gsub(s, '`(%a+):?(.-)`', function(k, f)
		assert(t[k], 'Invalid strapply for key '..k..': '..string.format('%q', s))
		if #f > 0 then return string.format(f, t[k])
		else return t[k] end
	end)
end

-- Contexts are returned from calling Type's hooks, and are designed to help
-- with common operations on the results of the hook. In particular:
-- 1. c[e] -> Result for element e
-- 2. c[i] -> Result for the i'th element
-- 3. pairs(c) -> Iterate over elements
-- 4. c() -> table.concat(<results>)
-- 5. c(s) -> table.concat(<results>, s)
-- 6. c(s, f) -> table.concat({f(<result>, <elem name>), ...}, s)
-- 7. c(s, fs) -> table.concat(strapply(fs, {e=<elem name>, v=<result>}), s)
-- 8. #c -> Number of elements
local function C(x)
	if getmetatable(x) then return x end
	local m = {}

	local ord,res = {},{}
	function m.__len() return #ord end
	function m:__index(k) return self[ord[k]] end
	function m:__newindex(k,v)
		rawset(self, k, v)
		table.insert(ord, k)
		table.insert(res, v)
	end
	function m.__call(_,s,f)
		local r = {}
		if f then for i,v in ipairs(res) do
			if type(f) == 'string' then r[i] = strapply(f, {e=ord[i],v=v})
			else r[i] = f(v) end
		end end
		return table.concat(f and r or res, s)
	end

	return setmetatable(x or {}, m)
end

-- Construct a Type from the functions or strings that make it up.
-- Types are called with one of the "hook" names ('def' or 'conv'),
-- and the resulting function is called with an optional Context and element name.
local function T(t, extra)
	if not t then return nil end
	local m = {}
	function m.__call(_,k) return m[k] end

	local ah = {}
	function ah.e(o,v) return v end
	function ah.v(o,v)
		if v == nil then v = t.default end
		if extra and extra.v then v = extra.v(v) or v end
		return v
	end

	local function handle(key, as)
		if type(t[key]) == 'function' then
			m[key] = function(c, e, ...)
				if type(c) == 'string' then c,e = C(),c else c = C(c) end
				local a = table.pack(...)
				for i,an in ipairs(as) do a[i] = ah[an](a[i]) end
				t[key](c, e, table.unpack(a))
				return c
			end
		elseif type(t[key]) == 'string' then
			m[key] = function(c, e, ...)
				if type(c) == 'string' then c,e = C(),c else c = C(c) end
				local a,r = table.pack(...),{e=e}
				for i,an in ipairs(as) do r[an] = ah[an](a[i]) end
				c[e] = strapply(t[key], r)
				return c
			end
		elseif type(t[key]) == 'table' then
			m[key] = function(c, e, ...)
				if type(c) == 'string' then c,e = C(),c else c = C(c) end
				local a,r = table.pack(...),{e=e}
				for i,an in ipairs(as) do r[an] = ah[an](a[i]) end
				for k,v in pairs(t[key]) do c[strapply(k, r)] = strapply(v, r) end
				return c
			end
		else error('Making a type with an odd '..key..' value!') end
	end

	handle('def', {})
	handle('conv', {'v'})
	return setmetatable({}, m)
end

-- A handful of types are "simple," and all generators should support them.
assert(G.simple, 'Generator does not support simpletypes!')
for t in pairs{
	integer=true, number=true, boolean=true, string=true,
	generic=true, memory=true,
} do stdlib[t] = assert(T(G.simple[t]),
	'Generator does not support the '..t..' simpletype!') end

-- If the generator doesn't overload it, indicies are just integers.
stdlib.index = T(G.simple.index) or stdlib.integer

-- Simple optional & required argument checker. Test should error on failure.
local function checkarg(arg, opts)
	local function optfor(k)
		if opts[k] then return opts[k] end
		if math.type(k) == 'integer' then return opts._integer end
		if type(k) == 'string' then
			for ok,o in pairs(opts) do
				ok = type(ok) == 'string' and string.match(ok, '^~(.+)$')
				if ok and string.match(k, '^'..ok..'$') then return o end
			end
		end
	end

	if opts._integer == true then assert(arg[1], 'Required sequence is empty') end
	for k,o in pairs(opts) do
		if o == true then assert(arg[k], 'Required argument '..k..' is nil') end
	end

	for k,v in pairs(arg) do
		local o = optfor(k)
		assert(o, 'Invalid argument '..tostring(k))
		if type(o) == 'function' then
			local r,r2 = pcall(o, v)
			if r2 == false then r = false end
			assert(r, 'Malformed argument '..k)
		end
	end
end

-- Arrays are tables in Lua. The generator can add more functionality.
function stdlib.array(arg)
	checkarg(arg, {
		[1] = true,		-- Type of the array elements
		fixedsize = false,	-- Maximum size of the array
	})
	return T(assert(G.array, 'Generator does not support arrays!')(arg),
		arg.fixedsize and {
			v=function(v) assert(#v < arg.fixedsize, "Array is too large!") end
		})
end

-- Options are strings, treated similarly to how luaL_checkoption operates.
function stdlib.options(arg)
	checkarg(arg, {
		_integer = true,	-- Names of valid options
		default = false,	-- Default option if none is given
	})
	local opts = {}
	for _,o in ipairs(arg) do opts[o] = o end
	return T(assert(G.array, 'Generator does not support options!')(arg), {
		v=function(v) return assert(opts[v], 'Invalid option '..tostring(v)) end,
	})
end

-- Flags are strings or tables, with the strings using the shorthand names for
-- the flag values, and the table can use either. The generator will always be
-- given a table with the proper names for flag values.
-- If a value's proper name is one character long, it will accepted as shorthand,
-- while shorthands must be one character long.
function stdlib.flags(arg)
	checkarg(arg, {
		_integer = function(v)
			if type(v) == 'string' then return #v > 0 end
			if type(v) == 'table' then
				for k in pairs(v) do assert(k == 1 or k == 2) end
				assert(type(v[1]) == 'string' and type(v[2]) == 'string')
				return #v[1] > 0 and #v[2] == 1
			end
		end,	-- proper name OR {<proper name>, <shorthand>}
	})
	local shorts = {}
	for _,e in ipairs(arg) do
		local p,s
		if type(e) == 'string' then p, s = e, #e == 1 and e or nil
		else p, s = e[1], e[2] end
		if s then shorts[s] = p end
	end
	return T(assert(G.flags, 'Generator does not support flags!')(arg), {
		v = function(v)
			local o = setmetatable({}, {__index=v})
			if type(v) == 'string' then
				for c in string.gmatch(v, '.') do
					assert(shorts[c], 'Invalid flag shorthand '..c)
					o[shorts[c]] = true
				end
			else
				for s,p in pairs(shorts) do if v[s] then o[p] = true end end
			end
			return o
		end,
	})
end

-- Callables are functions (since 'function' is a keyword in Lua). These have
-- an expected set of arguments and return values, and implicitly hold context.
function stdlib.callable(arg)
	checkarg(arg, {
		returns = function(v)
			for k in pairs(v) do assert(math.type(k) == 'integer') end
		end,	-- Sequence of Types for returned values
		_integer = function(a)
			assert(type(a[1]) == 'string' and a[2])
		end,	-- Arguments, as {<name>, <Type>}
	})
	return T(assert(G.callable, 'Generator does not support callables!')(arg))
end

--[[
	Compounds are tables, with defaults for when a value is not given (or nil).
	There are two forms for the compounds, the 'static' one being fixed between
	versions of Vv, and the 'mutable' one being allowed to change.

	The 'static' case uses the array component of arg to specify the elements of
	the compound, as tables of the form {<name>, <Type>, [<default>]}.

	The 'mutable' case uses keys of the form v<M>_<m>_<p> to hold tables with
	the element entries, where <M>.<m>.<p> is the version of Vv it was added in.

	It should be noted that 'mutable' compounds are the only type that can
	change between versions of Vv, and as such follows the rules of semver.

	The generator hook is always given a 'static' case argument, and on
	conversion default values are applied.
]]
function stdlib.compound(arg)
	-- First decide between 'static' and 'mutable'.
	local static
	if arg[1] then static = true else
		for k in pairs(arg) do
			if string.match(tostring(k), '^v%d+_%d+_%d+$') then
				static = false
				break
			end
		end
		if static == nil then
			error('Cowardly refusing to construct an empty compound') end
	end

	-- Check the arguments
	checkarg(arg, {
		_integer = static and function(v)
			assert(type(v[1]) == 'string' and v[2])
		end or nil,		-- Elements, as {<name>, <Type>, [<def>]}
		['~%d+_%d+_%d+'] = (not static) and function(v)
			for k,e in pairs(v) do
				assert(math.type(k) == 'integer')
				assert(type(e[1]) == 'string' and e[2])
			end
		end or nil,		-- Elements, as {<name>, <Type>, [<def>]}
	})

	-- Now if its mutable, order the elements for the generator
	local garg
	if static then garg = arg else
		garg = setmetatable({}, {__index=arg})
		local vers = {}
		for k,v in pairs(arg) do
			local M,m,p = string.match(k, 'v(%d+)_(%d+)_(%d+)')
			if M then
				vers[#vers+1] = {tonumber(M), tonumber(m), tonumber(p), v}
			end
		end
		table.sort(vers, function(a,b)
			if a[1] ~= b[1] then return a[1] < b[1]
			elseif a[2] ~= b[2] then return a[2] < b[2]
			else return a[3] < b[3] end
		end)
		for _,v in ipairs(vers) do table.move(v[4], 1, #v[4], #garg+1, garg) end
	end

	-- Get the default elements, using garg, and remove the default value.
	local def = {}
	for _,e in ipairs(garg) do def[e[1]], e[3] = e[3], nil end

	local g = assert(G.compound, 'Generator does not support compounds!')(garg)
	g.default = function(c, e) g.conv(c, e, def) end
	return T(g, {v=function(v)
			local o = setmetatable({}, {__index=v})
			for k,d in pairs(def) do if o[k] == nil then o[k] = d end end
			return o
		end,
	})
end

--[[
	Behaviors are the main construct in Vv, they are mostly-opaque objects with
	methods that give them capabilities. In Lua these are Userdata. Similar to
	compounds, these create a context for the elements inside them; unlike
	compounds, there are 5 different contexts for 4 different areas:

	1. Methods are callable elements, and are contained in one context.
	2. Data are elements in the Behavior that are accessable from outside, and
	   form a second context. Some Data is read-only, which forms the third.
	3. Named Types are Types that are given a special name connected to the
	   Behavior, and form the fourth context.
	4. Sub-Behaviors are Behaviors that are tethered to their super-Behavior
	   and so have Methods of their own. These form the fifth context.

	Behaviors are created by setting the argument table to the name in _ENV,
	that is as a global. Then to fill the 3 areas, the Behavior is accessed
	with the version and specifics about the area. If the created Behavior
	was named "B", and we were adding for version M.m.p, then

	1. Methods are added by `B.vM_m_p.<methodname> = {... callback arg ...}`.
	2. Data are added by `B.vM_m_p.rw.<name> = <Type>`.
	3. Read-only Data are added by `B.vM_m_p.ro.<name> = <Type>`.
	4. Named types are added by `B.type.<name> = <Type>`, and the <Type> can be
	   later referenced as `B.<name>`.
	5. Sub-Behaviors are added by `B.<name> = {... behavior arg ...}`, and can
	   be later referenced as `B.<name>`.

	In application code, Behaviors are created by global functions which have
	optional arguments for parent Behaviors. The actual algorithms and content
	of the Behavior can change based on the given arguments, which can allow
	implementers of Vv's API to choose the best implementation.

	It should be noted that the Types returned by the Behavior are not identical
	to the ones used, they defer to the actual type and will only function
	properly after the main Type has been `def`'d.

	The generator behavior hook acts a little different than the others. It
	should return a table with the following entries:
	- subtype(<name>, <Type>) -> Type
	  Called when new Named Types are added, and can return a different Type.
	- def(c, e, {{<name>, <Type>},...}, {{'m' | 'rw' | 'ro', <name>, <Type>},...})
	  Called as usual for the def hook, but with the contents of the Behavior.
]]
local behavioropts = {
	-- [integer] = parent Behaviors, can also be sub-Behaviors.
}
local function behavior(arg, name)
	checkarg(arg, behavioropts, true)
	for i,b in ipairs(arg) do
		assert(b'behaves', 'Invalid parent Behavior at #'..i)
	end
	local g = assert(G.behavior, "Generator does not support Behaviors!")(arg)

	local types,vers,subs,isubs = {},{},{},{}
	local me = T{
		def = function(c, e)
			table.sort(vers, function(a,b)
				if a.M ~= b.M then return a.M < b.M
				elseif a.m ~= b.m then return a.m < b.m
				else return a.p < b.p end
			end)
			local ents = {}
			for _,v in ipairs(vers) do table.move(v.e, 1, #v.e, #ents+1, ents) end
			g.def(c, e, types, ents)
			for k,b in pairs(subs) do b'def'(c, e..k) end
		end,
		conv = function() error("Behaviors cannot be converted from Lua") end,
	}
	local myself = T(g.subtype(name, '', me))

	assert(name, "Behaviors need to know their names!")
	local meta = getmetatable(myself)
	meta.behaves = name
	function meta.__index(_, k)
		local M,m,p = string.match(tostring(k), '^v(%d+)_(%d+)_(%d+)$')
		M,m,p = tonumber(M), tonumber(m), tonumber(p)
		if k == 'type' then
			return setmetatable({}, {__newindex=function(_,n,ty)
				table.insert(types, {n, ty})
				types[n] = T(g.subtype(name, n, ty))
			end})
		elseif M then
			if not vers[k] then
				vers[k] = {M=M,m=m,p=p,e={}}
				vers[#vers+1] = vers[k]
			end
			local vr = vers[k].e
			return setmetatable({}, {
				__index = function(_, k2)
					if k2 == 'rw' then
						return setmetatable({}, {__newindex=function(_,n,ty)
							table.insert(vr, {'rw', n, ty})
						end})
					elseif k2 == 'ro' then
						return setmetatable({}, {__newindex=function(_,n,ty)
							table.insert(vr, {'ro', n, ty})
						end})
					end
				end,
				__newindex = function(_, n, ca)
					table.insert(vr, {'m', n, stdlib.callable(ca)})
				end
			})
		else return types[k] or isubs[k] end
	end
	function meta.__newindex(_, k, ba)
		assert(#ba == 0, "Sub-Behaviors can't have extra parents")
		local i,o = behavior(ba, name..k)
		i.v0_0_0.ro.parent = myself
		subs[k],isubs[k] = o,i
	end

	for _,b in ipairs(arg) do
		myself.v0_0_0.ro[b'behaves'] = b
	end
	return myself, me
end

-- The generator is the one to actually load the spec files, so we provide some
-- helper functions to make life easier.
local sl = {lib=stdlib, T=T}
local function stdenv()
	local res = {}
	return setmetatable({}, {
		__index=stdlib,
		__newindex=function(env, k, v)
			local i,o = behavior(v, k)
			rawset(env, k, i)
			res[k] = o
		end
	}), res
end
function sl.load(a,b,c)
	local env,res = stdenv()
	local f,err = load(a,b,c,env)
	if not f then res = err end
	return f,res
end
function sl.loadfile(a,b)
	local env,res = stdenv()
	local f,err = loadfile(a,b,env)
	if not f then res = err end
	return f,res
end
function sl.preload(n, f)
	local fn,err = package.searchpath(f or n, package.path)
	if err then error(err) end
	local res
	package.preload[n],res = sl.loadfile(fn, 't')
	return res
end
function sl.require(n) local res = sl.preload(n); return require(n),res end
return sl
