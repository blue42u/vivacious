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

-- Construct a Type from the functions or strings that make it up.
local function T(t)
	if not t then return nil end
	local m = {}
	function m.__call(_,k) return m[k] end

	local function handle(key, arghandlers)
		local function totab(e,...)
			local tab = {e=e}
			local tp = table.pack(...)
			for i,h in ipairs(arghandlers) do h(tab, tp[i]) end
			return tab
		end
		if type(t[key]) == 'function' then
			m[key] = function(c,...)
				local addedkeys,cc = {},{}
				t[key](setmetatable(cc, {__newindex=function(s,k,v)
					rawset(s, k, v)
					table.insert(addedkeys, k)
				end}), ...)
				for _,k in ipairs(addedkeys) do
					c[cc[k]] = k
					table.insert(c, cc[k])
				end
				return c
			end
		elseif type(t[key]) == 'string' then
			m[key] = function(c,e,...)
				local v = strapply(t[key], totab(e,...))
				c[v] = e
				table.insert(c, v)
				return c
			end
		elseif type(t[key]) == 'table' then
			m[key] = function(c,e,...)
				local tab = totab(e,...)
				for k,v in pairs(t[key]) do
					k,v = strapply(k,tab), strapply(v,tab)
					c[v] = k
					table.insert(c, v)
				end
				return c
			end
		else error('Making a type with an odd '..key..' value!') end
	end

	handle('def', {})
	handle('conv', {function(tab,v)
		if v == nil then v = t.default end
		tab.v = v
	end})

	return setmetatable({}, m)
end

-- Construct a type, but wrap a few of the arguments...
local function Tw(w)
	local t = T(w[1])
	if w.v then	-- Wrap values before they enter
		local conv = getmetatable(t).conv
		getmetatable(t).conv = function(c,e,v) conv(c,e, w.v(v)) end
	end
	return t
end

-- A handful of types are "simple," and all generators should support them.
assert(G.simple, 'Generator does not support simpletypes!')
for t in pairs{
	integer=true, number=true, boolean=true, string=true,
	generic=true, memory=true,
} do stdlib[t] = assert(T(G.simple[t]), 'Generator does not support the '
	..t..' simpletype!') end

-- If the generator doesn't overload it, indicies are just integers.
stdlib.index = T(G.simple.index) or stdlib.integer

-- Simple optional & required argument checker. Test should error to indicate failure.
local function checkarg(arg, opts, arr, test)
	if not test then test = function() end end
	for k,v in pairs(arg) do
		if not (arr and math.type(k) == 'integer') or not pcall(test,k,v) then
			assert(opts[k] ~= nil, 'Invalid argument '..tostring(k)..'!')
		end
	end
	for k,r in pairs(opts) do if r then
		assert(arg[k], 'Required argument '..k..' not provided!')
	end end
end

-- Arrays are tables in Lua. The generator can add more functionality.
local arrayopts = {
	[1] = true,			-- The Type of the elements in the array.
	fixedsize = false,	-- The size of the array at maximum.
}
function stdlib.array(arg)
	checkarg(arg, arrayopts)
	return Tw{assert(G.array, 'Generator does not support arrays!')(arg),
		v=function(v)
			if arg.fixedsize then
				assert(#v < arg.fixedsize, "Conversion for array is too large!")
			end
			return v
		end
	}
end

-- Options are strings, treated similarly to how luaL_checkoption operates.
local optionsopts = {
	-- The array component of arg lists the names of the valid options
	default = false,	-- Default option if none is given.
}
function stdlib.options(arg)
	checkarg(arg, optionsopts, true)
	assert(#arg > 0, 'Cowardly refusing to create an empty options')
	local opts = {}
	for _,o in ipairs(arg) do opts[o] = o end
	return Tw{assert(G.array, 'Generator does not support options!')(arg),
		v = function(v) return assert(opts[v], 'Invalid option '..tostring(v)) end,
	}
end

-- Flags are strings or tables, with the strings using the shorthand names for
-- the flag values, and the table can use either. The generator will always be
-- given a table with the proper names for flag values.
-- If a value's proper name is one character long, it will accepted as shorthand,
-- while shorthands must be one character long.
local flagsopts = {
	-- [integer] = (string) proper name OR (table) {<proper>, <shorthand>}
}
function stdlib.flags(arg)
	checkarg(arg, flagsopts, true)
	local shorts = {}
	for _,e in ipairs(arg) do
		local p,s
		if type(e) == 'string' then
			p, s = e, #e == 1 and e or nil
		else p, s = e[1], e[2] end
		assert(#p > 0, 'Invalid flag proper name '..('%q'):format(p))
		if s then
			assert(#s == 1, 'Invalid flag shorthand '..('%q'):format(e))
			shorts[s] = p
		end
	end
	return Tw{assert(G.flags, 'Generator does not support flags!')(arg),
		v = function(v)
			local o = setmetatable({}, {__index=v})
			if type(v) == 'string' then
				for c in string.gmatch(v, '.') do
					assert(shorts[c], 'Invalid flag shorthand '..c)
					o[shorts[c]] = true
				end
			else
				for s,p in pairs(shorts) do
					if v[s] then o[p] = true end
				end
			end
			return o
		end,
	}
end

-- Callables are functions (since 'function' is a keyword in Lua). These have
-- an expected set of arguments and return values, and implicitly hold context.
local callableopts = {
	returns = false,	-- Table of Types for the returned values
	-- [integer] = (table) {<argument name> (string), <Type>}
}
function stdlib.callable(arg)
	checkarg(arg, callableopts, true)
	for k in pairs(arg.returns or {}) do
		assert(math.type(k) == 'integer', 'Non-sequence key in returns') end
	for i,a in ipairs(arg) do
		assert(type(a[1]) == 'string' and a[2], 'Invalid argument entry '..i) end
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
local compoundopts = {
	-- None as of yet.
}
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
		if static == nil then error('Cowardly refusing to construct an empty compound') end
	end

	-- Check the arguments
	checkarg(arg, compoundopts, static, static
		and function(_,e) assert(type(e[1]) == 'string' and #e[1] > 0 and e[2]) end
		or function(k,v)
			assert(type(k) == 'string')
			assert(k:match'v%d+_%d+_%d+')
			for _,e in ipairs(v) do
				assert(type(e[1]) == 'string' and #e[1] > 0 and e[2])
			end
		end)

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
	return Tw{g, v=function(v)
			local o = setmetatable({}, {__index=v})
			for k,d in pairs(def) do if o[k] == nil then o[k] = d end end
			return o
		end,
	}
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
