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

-- luacheck: new globals gen
gen = {}

-- Allow us to skip the initial 'apis.' for generation requires.
package.path = package.path .. ';' .. package.path:gsub('%?%.lua', 'apis/?.lua')

local lintw = require 'apis.core.lintwrapper'

-- Processing expressions is a difficult task to repeat often, so we let the
-- generator provide hooks to transform the pieces of the expression.
-- `exs` are the expression(s) to try to obtain a meaningful result,
-- `rep` is the table of modifications to apply, and
-- `env` is the 'e' table (name -> field) table to use for context,
-- `selfty` is the (optional) type of 'self'.
-- The modifications supported are listed below. When used, the `...` always
-- refers to the pieces of a 'a.b.c.d' reference. All functions return strings.
-- - `rep.ref(...)` rewrites 'a.b.c.d' style expressions.
-- - `rep.strlen(exp, [...])` rewrites `#x`, when `x` is a string.
-- - `rep.udlen(exp, [...])` rewrites `#x` when `x` is a userdata.
-- - `rep.len(exp, [...])` rewrites `#x` when `x` isn't a basic type.
-- - `rep.add/sub/mul/div(a, b)` rewrites `a +-*/ b`.
function gen.express(exs, rep, env, selfty)
	-- We provide reasonable (i.e. basically no-op) defaults for replacements.
	rep = rep or {}
	rep.ref = rep.ref or function(...) return table.concat({...}, '.') end
	rep.strlen = rep.strlen or function(x) return '#'..x end
	rep.udlen = rep.udlen or function() error("Userdata must be handled specially!") end
	rep.len = rep.len or function(x) return '#'..x end
	rep.add = rep.add or function(a, b) return '('..a..'+'..b..')' end
	rep.sub = rep.sub or function(a, b) return '('..a..'-'..b..')' end
	rep.mul = rep.mul or function(a, b) return '('..a..'*'..b..')' end
	rep.div = rep.div or function(a, b) return '('..a..'/'..b..')' end

	-- Inside the sub-environment, we keep track of types and such using a complex
	-- "expression" object type. This is its metatable.
	local exmeta = {}
	local function exp(x, ty, ...)
		local trail = {...}
		if #trail > 0 then	-- x is ignored, we rebuild it
			x = rep.ref(table.unpack(trail))
			return setmetatable({ty=ty, exp=x, trail=trail, t=trail}, exmeta)
		else
			assert(x)
			return setmetatable({ty=ty, exp=x, t={}}, exmeta)
		end
	end
	function exmeta:__tostring() return self.exp end
	function exmeta:__len()
		if self.ty.basic then	-- Basic type
			if self.ty.basic == 'string' then
				return exp(rep.strlen(self.exp, table.unpack(self.t)), 'integer')
			elseif self.ty.basic == 'userdata' then
				return exp(rep.udlen(self.exp, table.unpack(self.t)), 'integer')
			else error("attempt to get length of a "..self.ty.." value") end
		else	-- A more normal Type, we assume all Types are nice and wrapped
			assert(self.ty.__index and self.ty.__index.e.__sequence
				or self.ty.__newindex and self.ty.__newindex.e.__sequence,
				"Attempt to get length of a non-sequence type!")
			return exp(rep.len(self.exp, table.unpack(self.t)), 'integer')
		end
	end
	function exmeta:__index(k)
		if self.ty.basic then error("attempt to index a "..self.ty.basic.." value") end
		if math.type(k) == 'integer' then
			local sty = self.ty.__index and self.ty.__index.e.__sequence
				or self.ty.__newindex and self.ty.__newindex.e.__sequence
			assert(sty, "invalid access to sequence element "..k)
			sty = sty.type
			if self.trail then
				table.insert(self.trail, k)
				local e = exp(nil, sty, table.unpack(self.trail))
				table.remove(self.trail)
				return e
			else return exp(self.exp..'['..k..']', sty) end
		else
			assert(type(k) == 'string', "Attempt to index type on non-number and non-string")
			local ne = self.ty.__index and self.ty.__index.e[k]
				or self.ty.__newindex and self.ty.__newindex.e[k]
			assert(ne, "invalid access to field '"..k.."'")
			if self.trail then
				table.insert(self.trail, k)
				local e = exp(nil, ne.type, table.unpack(self.trail))
				table.remove(self.trail)
				return e
			else return exp(self.exp..'.'..k, ne.type) end
		end
	end
	for _,m in ipairs{'add', 'sub', 'mul', 'div'} do
		exmeta['__'..m] = function(a, b)
			local ty
			if getmetatable(a) == getmetatable(b) then
				assert(a.ty == b.ty, "Attempt to add incompatible types!")
				ty = a.ty
			elseif getmetatable(a) == exmeta then ty = a.ty
			elseif getmetatable(b) == exmeta then ty = b.ty end
			assert(ty, "Unable to determine type!")
			return exp(rep[m](tostring(a), tostring(b)), ty)
		end
	end

	-- We may be given multiple possible expressions, for which we try each one
	-- and attempt to find one that works. Thus we gather all the errors.
	local errs = {}
	for i,ex in ipairs(type(exs) == 'string' and {exs} or exs) do
		local f = assert(load('return ('..ex..')', nil, 't', setmetatable({}, {
			__index = function(_,k)
				if k == 'self' then return exp(nil, selfty, 'self')
				elseif env[k] then return exp(nil, env[k].type, k)
				else error("invalid access to context "..tostring(k)) end
			end
		})))
		local ok, val = pcall(f)
		if ok then
			if type(val) == 'string' then return val else return tostring(val) end
		else errs[i] = '[from '..ex..']: '..val end
	end
	error('No usable expression found!\n'..table.concat(errs, '\n'))
end

-- Multi-line string constructor. Used in the stuff below.
-- Calling it adds another line to the string, and the arguments are concatinated
-- with false-likes skipped. Using tostring results in the result.
local collectormeta
collectormeta = {
	__call = function(self, ...)
		local p = self.pre or ''
		local a,b = {...},{}
		if #a == 0 then return
		elseif #a == 1 and getmetatable(a[1]) == collectormeta then
			table.move(a[1].coll, 1, #a[1].coll, #self.coll+1, self.coll)
		else
			for k,v in pairs(a) do if v then b[#b+1] = k end end
			table.sort(b)
			for i,k in ipairs(b) do b[i] = a[k] end
			self.coll[#self.coll+1] = p..table.concat(b)..'\n'
		end
	end,
	__tostring = function(self) return table.concat(self.coll) end,
}
collectormeta.__index = collectormeta
function gen.collector(p) return setmetatable({coll={}, pre=p}, collectormeta) end

-- This is the Lua-esque object construction for the Rules structures, which
-- provide a cached/getter interface to the generator-defined derived properties
-- of a Type. The result is a Lua object factory, for which the only argument is
-- the access-limiting wrapper for the "pure" Type, provided by lintwrapper.lua.

-- The idea behind Rules is that there are a number of methods which can output
-- to multiple cached "outputs," which are accessed by __index on a Rules
-- instance. A method may output to multiple outputs, and if multiple methods
-- output to the same output all of the methods are executed, and the value that
-- isn't nil is used (if there is a single unique value, otherwise it errors).
-- Other than self, these methods are not called with any extra arguments.

-- This table holds all the common components needed.
local rules = {}

-- Class method to add needed fields to the class table.
function rules:classinit(super)
	-- This holds the rule functions themselves, in a manner that makes it easier
	-- to resolve outputs. Output keys are mapped to tables such that:
	-- { [<rule method>]=true, master=<master rule method> }
	self.rules = {}
	-- If there's a superclass, we save it for later, to cascade the resolve op.
	-- For compat with Moonscript, we just use the standard name for it.
	self.__parent = super
end

-- Class method to add rules.
function rules:rule(...)
	local outputs = {...}
	local func = table.remove(outputs)
	local masters = {}
	do
		local l = 1
		for i,o in ipairs(outputs) do
			if o:sub(1,1) == '-' then outputs[i] = o:sub(2)
			else masters[l],l = o,l+1 end
		end
	end
	local function f(...)
		local vs = {func(...)}
		for i,o in ipairs(outputs) do vs[i],vs[o] = nil,vs[i] end
		return vs
	end
	for _,o in ipairs(outputs) do
		if not self.rules[o] then self.rules[o] = {} end
		self.rules[o][f] = true
	end
	for _,m in ipairs(masters) do
		assert(not self.rules[m].master, "Attempt to assign multiple master methods for "..m)
		self.rules[m].master = f
	end
end

-- Instance method to add needed fields to the instance.
function rules:instinit(pure)
	self._cache, self._nilresolved, self._recurse = {},{},{}
	self._pure = pure
	if not getmetatable(self) then setmetatable(self, {}) end
	getmetatable(self).__newindex = function() error("Read-only table!") end
	getmetatable(self).__pairs = function(s) return pairs(s._pure) end
end

-- Instance method for resolving outputs. Needs access to the class.
function rules.resolve(inst, cls, k)
	local function rcall(f)
		if not inst._cache[f] then
			assert(not inst._recurse[f], "Recursion detected!")
			inst._recurse[f] = true
			local vs = f(inst)
			inst._recurse[f] = nil
			inst._cache[f] = vs
			return vs[k]
		else return inst._cache[f][k] end
	end

	local rs = cls.rules
	if inst._nilresolved[k] then return
	elseif rs[k] then
		local v
		if rs[k].master then v = rcall(rs[k].master) end
		if v == nil then
			local vals = {}
			for f in pairs(rs[k]) do if f ~= 'master' then vals[#vals+1] = rcall(f) end end
			if #vals > 1 then
				local va = vals[1]
				if getmetatable(va) == collectormeta then va = tostring(va) end
				for i=2,#vals do
					local vb = vals[i]
					if getmetatable(vb) == collectormeta then vb = tostring(vb) end
					if va ~= vb then
						local err = {"Multiple non-master outputs for key "..k..':'}
						for ei,vv in ipairs(vals) do
							table.insert(err, ('%d: %q'):format(ei, tostring(vv)))
						end
						error(table.concat(err, '\n'))
					end
				end
			end
			v = vals[1]
		end
		if v == nil then inst._nilresolved[k] = true else rawset(inst, k, v) end
		return v
	elseif cls.__parent then return rules.resolve(inst, cls.__parent, k)
	else return inst._pure[k] end
end

-- The nature of the Rules makes the construction look a little different from
-- most Lua object structures, since there are multiple "method names" per method.
-- To simplify generators, two mechanisms are exposed.

-- The former mechanism is designed primarily for Lua-written generators. A new
-- Rules factory is returned by `gen.rules()`, and new rules are added by
-- calling `:addrule` with the outputs (primary first) and method function.
-- As an added bonus, __newindex is short for `:addrule(key, value)`.
do
	local meta = {}
	function meta:__newindex(k, v) self:addrule(k, v) end
	function meta:__call(...)
		local i = {}
		rules.instinit(i, ...)
		getmetatable(i).__index = function(s,k) return rules.resolve(s,self,k) end
		return i
	end
	function gen.rules(super)
		local r = {addrule = rules.rule}
		rules.classinit(r, super)
		return setmetatable(r, meta)
	end
end

-- The latter structure is designed primarily for Moonscript-written generators.
-- New Rules factories are created by subclassing the gen.Rules class, and rules
-- are added with `@rule` in the class body with the outputs and method.
-- In addition, any methods added in the normal way are added as rules.
do
	local cmeta = {}
	gen.Rules = setmetatable({}, cmeta)

	function cmeta:__call() error("Not actually a Rules, subclass this!") end
	gen.Rules.rule = rules.rule
	function gen.Rules:__inherited(cls)
		cls.__base.__index = nil	-- We'll rewrite it later
		for k,v in pairs(cls.__base) do
			cls.__base[k] = nil
			rules.rule(cls, k, v)
		end
		function cls.__base:__index(k) return rules.resolve(self,cls,k) end
	end
	function gen.Rules:__init(...) rules.instinit(self, ...) end
end

-- Nab the arguments. Usage: lua5.3 generation.lua <gen> <out> <spec>
local genname,outname,specname = arg[1],arg[2],arg[3]
assert(genname and outname and specname, "Not enough arguments to generator!")

-- Handy wrapper-cacher to lower our memory footprint a little, maybe.
local generator = io.open(genname) and assert(dofile(genname)) or require(genname)
lintw.wrappers = setmetatable({}, {
	__index = function(self, ty)
		local w = generator(lintw.tywrap(ty))
		rawset(self, ty, w)
		return w
	end
})

-- Get the master list of Types to process
local spec = require(specname)
lintw.spec, lintw.specname, lintw.spectys = spec, specname, {}
do
	local spectys = lintw.spectys
	local function hand(ty)
		if not spectys[ty] then
			spectys[#spectys+1], spectys[ty] = ty, true
			local next = {}
			for k in pairs(ty) do
				assert(type(k) == 'string', "Types shouldn't have non-string keys!")
				if not k:match '^__' then next[#next+1] = k end
			end
			table.sort(next)
			for _,k in ipairs(next) do hand(ty[k]) end
		end
	end
	hand(spec)
end

-- And now, we write it all out
local outfile = assert(io.open(outname, 'w'))
local function write(val)
	if getmetatable(val) == collectormeta then
		for _,l in ipairs(val.coll) do outfile:write(l) end
	elseif val ~= nil then
		if val ~= '' then val = string.gsub(val, '\n*$', '\n') end
		outfile:write(val)
	end
end
for _,k in ipairs{
	'preheader', 'header', 'postheader',
	'premain', 'main', 'postmain',
	'prefooter', 'footer', 'postfooter'} do
	if generator.rules[k] then
		for _,ty in ipairs(lintw.spectys) do write(lintw.wrappers[ty][k]) end
	end
end
outfile:close()
