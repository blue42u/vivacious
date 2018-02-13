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

local G,D = ...
G.behavior = G.behavior or D.behavior
G.environment = G.environment or D.environment
local stdlib = {}

-- A handful of types are "simple," and all generators should support them.
for n,t in pairs(G.simple or {}) do stdlib[n] = newtype(n, t) end

-- Simple optional & required argument checker. Test should error on failure.
local function checkarg(name, arg, opts1, opts2)
	local opts
	if opts2 then opts = setmetatable({}, {__index=function(_,k)
			local v = opts1[k]
			if v ~= nil then return v else return opts2[k] end
		end})
	else opts = opts1 end
	opts2 = opts2 or {}

	local function optfor(k)
		if opts[k] ~= nil then return opts[k] end
		if math.type(k) == 'integer' then return opts._integer end
		if type(k) == 'string' then
			for ok,o in pairs(opts1) do
				ok = type(ok) == 'string' and string.match(ok, '^~(.+)$')
				if ok and string.match(k, '^'..ok..'$') then return o end
			end
			for ok,o in pairs(opts2) do
				ok = type(ok) == 'string' and string.match(ok, '^~(.+)$')
				if ok and string.match(k, '^'..ok..'$') then return o end
			end
		end
	end

	if opts._integer == true then assert(arg[1], 'Sequence for '..name..' is empty') end
	for k,o in pairs(opts1) do
		if o == true and k ~= '_integer' then
			assert(arg[k] ~= nil, 'Required argument '..k..' for '..name..' is nil') end
	end
	for k,o in pairs(opts2) do
		if o == true and k ~= '_integer' then
			assert(arg[k] ~= nil, 'Required argument '..k..' for '..name..' is nil') end
	end

	for k,v in pairs(arg) do
		local o = optfor(k)
		assert(o ~= nil, 'Invalid argument '..tostring(k)..' for '..name)
		if type(o) == 'function' then
			local r,r2 = pcall(o, v)
			if r2 == false then r = false end
			assert(r, 'Malformed argument '..k..' for '..name)
		end
	end
end

-- Generators are able to add custom functions for more specific cases. The
-- main specs shouldn't use these to improve the portability.
if G.custom then for k,f in pairs(G.custom) do
	if k:match'_arg$' then k = k:gsub('_arg$', '') end
	local opts = G.custom[k..'_arg'] or {}
	f = G.custom[k] or D.custom[k]
	stdlib[k] = function(arg)
		checkarg(k, arg, opts)
		local t = {}
		f(t, arg)
		return newtype(k, t)
	end
end end

-- Generator standard type-functions are methods, where `self` is the table to
-- fill that goes to newtype. For convience, gcall will create the table.
local function gcall(n, ...)
	local t = {}
	local f = assert(G[n] or D[n], 'Generator does not support '..n..'!')
	return t, f(t, ...)
end

-- Arrays are tables in Lua. The generator can add more functionality.
if G.array or G.array_arg then function stdlib.array(arg)
	checkarg('array', arg, {
		[1] = true,		-- Type of the array elements
		fixedsize = false,	-- Maximum size of the array
	}, G.array_arg)
	return newtype('array', gcall('array', arg),
		arg.fixedsize and {
			v=function(v) assert(#v < arg.fixedsize, "Array is too large!") end
		})
end end

-- Options are strings, treated similarly to how luaL_checkoption operates.
if G.options or G.options_arg then function stdlib.options(arg)
	checkarg('options', arg, {
		_integer = true,	-- Names of valid options
		default = false,	-- Default option if none is given
		doc = false,		-- Documentation for the meaning of this option
	}, G.options_arg)
	local opts = {}
	for _,o in ipairs(arg) do opts[o] = o end
	local oerr = table.concat(arg, ', ')
	return newtype('options', gcall('options', arg),
		{v=function(v)
			if v == nil then v = arg.default end
			return assert(opts[v], 'Invalid option '..tostring(v)
				..' is not one of {'..oerr..'}')
		end}
	)
end end

-- Flags are strings or tables, with the strings using the shorthand names for
-- the flag values, and the table can use either. The generator will always be
-- given a table with the proper names for flag values.
-- If a value's proper name is one character long, it will accepted as
-- shorthand, while shorthands must be one character long.
if G.flags or G.flags_arg then function stdlib.flags(arg)
	checkarg('flags', arg, {
		_integer = function(v)
			if type(v) == 'string' then return #v > 0 end
			if type(v) == 'table' then
				for k in pairs(v) do assert(k == 1 or k == 2) end
				assert(type(v[1]) == 'string' and type(v[2]) == 'string')
				return #v[1] > 0 and #v[2] == 1
			end
		end,	-- proper name OR {<proper name>, <shorthand>}
		doc = false,	-- Documentation
	}, G.flags_arg)
	local shorts,ga = {},setmetatable({}, {__index=arg})
	for i,e in ipairs(arg) do
		local p,s
		if type(e) == 'string' then p, s = e, #e == 1 and e or nil
		else p, s = e[1], e[2] end
		if s then shorts[s] = p end
		ga[i] = p
	end
	return newtype('flags', gcall('flags', ga),
		{v = function(v)
			v = v or {}
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
		end}
	)
end end

-- Callables are functions (since 'function' is a keyword in Lua). These have
-- an expected set of arguments and return values, and implicitly hold context.
if G.callable or G.callable_arg then function stdlib.callable(arg)
	checkarg('callable', arg, {
		returns = function(v)
			for k in pairs(v) do assert(math.type(k) == 'integer') end
		end,	-- Sequence of Types for returned values
		_integer = function(a)
			assert(type(a[1]) == 'string' and a[2])
		end,	-- Arguments, as {<name>, <Type>}
		doc = false,	-- Documentation
	}, G.callable_arg)
	return newtype('callable', gcall('callable', arg))
end end

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
if G.compound or G.compound_arg then function stdlib.compound(arg)
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
	checkarg('compound', arg, {
		_integer = static and function(v)
			assert(type(v[1]) == 'string' and v[2])
		end or nil,		-- Elements, as {<name>, <Type>, [<def>]}
		['~v%d+_%d+_%d+'] = (not static) and function(v)
			for k,e in pairs(v) do
				assert(math.type(k) == 'integer')
				assert(type(e[1]) == 'string' and e[2])
			end
		end or nil,		-- Elements, as {<name>, <Type>, [<def>]}
		doc = false,	-- Documentation
	}, G.compound_arg)

	-- Now if its mutable, order the elements for the generator
	local garg
	if static then garg = arg else
		garg = setmetatable({mutable=true}, {__index=arg})
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

	local g = gcall('compound', garg)
	return newtype('compound', g, {v=function(v)
			local o = {}
			for k,a in pairs(v or {}) do o[k] = a end
			for k,d in pairs(def) do if o[k] == nil then o[k] = d end end
			return o
		end,
	})
end end

-- Now we get into the structural Types, the first being the Reference. This is
-- the "outlet" from the tree-based structure into the more normal nameless
-- Types.
local function ref(n, t, cp, ex)
	local g,be = gcall('reference', n, t, cp, ex)
	assert(be, 'Generator references should return Behavior name too!')
	return newtype('reference', g), be
end
local function bref(n, b, cp, ex)
	local r,be = ref(n, nil, nil, ex)
	local inside = false
	return newtype('reference-b', {
		def = function(_, c, e)
			r'def'(c, e)
			if b and not inside then
				inside = true
				b'def'(cp, n, be)
				inside = false
			end
		end,
		conv = error,
	}, {canrecurse=true})
end
local function defer(refs)
	local deferred = {}
	return function(k, v, rs)
		deferred[k] = newtype('deferred', {
			def = function(_, ...)
				assert(refs[k], 'Attempt to call deferred for '..k..' too early!')
				refs[k]'def'(...) end,
			conv = function(_, ...)
				assert(refs[k], 'Attempt to call deferred for '..k..' too early!')
				refs[k]'conv'(...) end,
		}, {canrecurse=true})
		local m = getmetatable(deferred[k])
		m.__index, m.__newindex = v, v
		setmetatable(m, {__index=getmetatable(v)})
		if rs then rs[k] = v end
	end, deferred
end

--[[
	Behaviors form the most important part of Vv, they are opaque objects with
	methods that allow applications to access the unknown internals, and allows
	for multiple separate implementations of the same Behaviors. In Lua, these
	are represented Userdata. Similar to compounds, they contain a Context for
	their elements to reside in; unlike compounds, there is more than one:

	1. Methods are callable elements, accessable in the usual manner for
	   Lua-style methods. Added to Behavior `B` in version `M.m.p` by a
	   statement like `B.vM_m_p.<name> = {...callback arg...}`.
	2. Read-only Data are elements accessable by the key of the same name.
	   Added by `B.vM_m_p.ro.<name> = <Type>`.
	3. Read-write Data are elements that be assigned to as well.
	   Added by `B.vM_m_p.rw.<name> = <Type>`.
	4. Types can be given names attached to a Behavior, although this is only
	   for generation and not extensively used in applications.
	   Added by `B.type.<name> = <Type>`, refer to `B.<name>`.
	5. Sub-Behaviors are Behaviors that are tethered to their super-Behavior,
	   and so a super-Behavior cannot be destroyed before its super-Behavior.
	   Added by `B.<name> = <Type>`, refer to `B.<name>`.

	Behaviors themselves are created by assigning the argument table to a name
	in the _ENV table (i.e. global) of a properly loaded function. At runtime,
	these are created by global functions which have optional arguments for the
	parent Behaviors, which are later accessable by ro Data.

	It should be noted that the sub-Types and sub-Behaviors are def'd into the
	top-level Context as needed, when the referenced Type is def'd. It should
	also be noted that the _ENV table is also a Type similar to a Behavior.
]]
local function behavior(arg)
	checkarg('behavior', arg, {
		_integer = function(b) assert(b'behaves') end, -- parent Behaviors
		issub = false,	-- Semi-internal, for sub-behaviors
		doc = true,		-- Documentation, required for such complex types.
	}, G.behavior_arg)
	local g,rex = gcall('behavior', arg)

	local refs,ts,bs,vers = {},{},{},{}
	local myself = newtype('behavior', {
		def = function(_, c, e, ge)
			table.sort(vers, function(a,b)
				if a.M ~= b.M then return a.M < b.M
				elseif a.m ~= b.m then return a.m < b.m
				else return a.p < b.p end
			end)
			local es = {}
			for _,v in ipairs(vers) do table.move(v.e, 1, #v.e, #es+1, es) end

			for k,t in pairs(ts) do refs[k] = ref(e..'.'..k, t, c, rex) end
			for k,b in pairs(bs) do refs[k] = bref(e..'.'..k, b, c, rex) end
			refs._self = ref(e, nil, nil, rex)
			g'def'(c, ge, es)
			for k,r in pairs(refs) do r'def'(k) end
		end,
		conv = error,
	})

	local d,df = defer(refs)
	d('_self', myself)

	g = newtype('generator-behavior', g, {self = df._self})

	local meta = getmetatable(myself)
	meta.behaves = true
	function meta.__index(_, k)
		local M,m,p = string.match(tostring(k), '^v(%d+)_(%d+)_(%d+)$')
		M,m,p = tonumber(M), tonumber(m), tonumber(p)
		if k == 'type' then
			return setmetatable({}, {__newindex=function(_,j,v) d(j,v,ts) end})
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
					table.insert(ca, 1, {'self', df._self})
					table.insert(vr, {'m', n, stdlib.callable(ca)})
				end
			})
		else return df[k] end
	end
	function meta.__newindex(_, k, ba)
		assert(#ba == 0, "Sub-Behaviors can't have extra parents")
		ba.issub, ba[1] = true, df._self
		d(k, behavior(ba), bs)
	end
	return myself, rex
end

-- The last "Type" are Environments, which are not quite the same as the others.
-- Instead of putting pieces into the given Context, they instead write out the
-- contents of the Context into the files passed in as extra.
local function environment(arg)
	checkarg('environment', arg, {
		sandbox = true,		-- Sandbox this will defer to on __index
		name = true,		-- Name of this environment, for dependecies
	})
	local g = newtype('environment-generator', gcall('environment'))

	local bs,es,ens = {},{},{}
	local refs,rex,subs = {},{},{}
	local o = newtype('environment', {
		def = function(_, _, e, ...)
			local c = newcontext()
			for _,k in ipairs(es) do es[k]'def'() end
			for k,b in pairs(subs) do refs[k] = bref(k, b, c, rex[k]) end
			for _,k in ipairs(bs) do refs[k]'def'(k) end
			if e then g'def'(c, e, ens, ...) end
		end,
		conv = error,
	})

	local d,df = defer(refs)

	local m = getmetatable(o)
	m.envname = arg.name
	function m.__index(_, k)
		return df[k] or es[k] or arg.sandbox[k]
	end
	function m.__newindex(_, k, v)
		if getmetatable(v) and getmetatable(v).envname then
			es[k],es[#es+1],ens[#ens+1] = v,k,getmetatable(v).envname
		else
			local b,x = behavior(v)
			d(k, b, subs)
			rex[k] = x
			bs[#bs+1] = k
		end
	end

	return o
end

return stdlib, environment
