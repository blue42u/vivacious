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

-- Handy string-application with formatting
local function strapply(s, t)
	return string.gsub(s, '`(%a+):?(.-)`', function(k, f)
		assert(t[k], 'Invalid strapply for key '..k..':'..string.format('%q',s))
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
local function newcontext()
	local m = {}

	local ord,res = {},{}
	function m.__pairs()
		local i = 0
		return function()
			i = i + 1
			return ord[i], res[i]
		end
	end
	function m.__len() return #ord end
	function m:__index(k) return rawget(self, ord[k]) end
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

	return setmetatable({}, m)
end

-- Construct a Type from the functions or strings that make it up.
-- Types are called with one of the "hook" names ('def' or 'conv'),
-- and the resulting function is called with a Context and element name.
local function newtype(name, t, extra)
	if not t then return nil end
	local m = {name=name}
	function m.__call(_,k) return m[k] end
	extra = extra or {}

	local ah = {}
	function ah.e(v) return v end
	function ah.v(v)
		if v == nil then v = t.default end
		if extra.v then v = extra.v(v) or v end
		return v
	end

	local trueself = extra.self or nil

	local recursed = false

	local function handle(key, as)
		local inside
		local tk,tr = t[key],t[key..'_recursive']
		if tk == error then
			inside = function(_, e, a, _)
				error('Attempt to call unsupported '..name..'\'s '..key
					..' hook (for element '..e..') with arguments ('
					..table.concat(a, ', ')..')')
			end
		elseif type(tk) == 'function' then
			inside = function(c, e, a, _, r)
				if not r then tk(trueself, c, e, table.unpack(a)) end
				if tr then tr(trueself, c, e, table.unpack(a)) end
			end
		elseif type(tk) == 'string' then
			inside = function(c, e, _, b) c[e] = strapply(tk, b) end
		elseif type(tk) == 'table' then
			inside = function(c, _, _, b)
				for k,v in pairs(tk) do c[strapply(k,b)] = strapply(v,b) end
			end
		else error('Making a type with an odd '..key..' value!') end
		m[key] = function(c, e, ...)
			local a = table.pack(...)
			if type(c) == 'string' then
				table.insert(a, 1, e)
				c, e = newcontext(), c
			elseif not c then c = newcontext() end
			local b = {e=e}
			for i,an in ipairs(as) do a[i] = ah[an](a[i]); b[an] = a[i] end
			local oldrecursed = recursed
			recursed = true
			inside(c, e, a, b, oldrecursed)
			recursed = oldrecursed
			return c
		end
	end

	handle('def', {})
	handle('conv', {'v'})
	local myself = setmetatable({}, m)
	if not trueself then trueself = myself end
	return myself
end

-- Usage: lua main.lua <path/to/generators> <generator> <path/to/apis> <api> <output files...>
local genpath = table.remove(arg, 1)
local generator = table.remove(arg, 1)
local root = table.remove(arg, 1)
local api = table.remove(arg, 1)

-- Last setup and checks before the main event
local gw
do
	local err
	gw,err = loadfile(root..'/core/gwrapper.lua', 't',
		setmetatable({newtype=newtype, newcontext=newcontext}, {__index=_ENV}))
	if err then error(err) end
end
assert(package.searchers, 'You must use Lua 5.2 or above!')

-- Setup a searcher for the generators, to get them wrapped with the gwrapper.
table.insert(package.searchers, 1, function(s)
	local f,err = package.searchpath(s, genpath..'/?.lua')
	if err then return err end
	local genenv = setmetatable({newtype=newtype, newcontext=newcontext},
		{__index=_ENV})
	f,err = loadfile(f, 't', genenv)
	if err then return err end
	local g = f()

	local r,sls = {},{}

	assert(g.default, 'Generator does not have a default varient!')
	local sld,efd = gw(g.default, g.default)
	r.default,sls.default = {sl=sld, envf=efd}, sld
	setmetatable(sld, {__index=_ENV})
	for v,vg in pairs(g) do if v ~= 'default' then
		local sl,ef = gw(vg, g.default)
		r[v],sls[v] = {sl=sl, envf=ef}, sl
		setmetatable(sl, {__index=sls.default})
	end end

	genenv.std = sls
	return function() return setmetatable(r,
		{__index=function() return {sl=sld, envf=efd} end}) end
end)

-- Setup a searcher to handle the extra pieces behind how specs are loaded.
table.insert(package.searchers, 1, function(s)
	local f,err = package.searchpath(s, root..'/?.lua')
	if err then return err end

	local g = require(generator).default
	for l in io.lines(f) do
		local c = l:match '%-%-!(.+)'
		if c then g = require(generator)[c:match'%S+']; break end
	end

	local env = g.envf{sandbox = g.sl, name=s}
	f,err = loadfile(f, 't', env)
	return err or function()
		f()
		return env
	end
end)

-- Generate the file
local fs = {}
for i,fn in ipairs(arg) do fs[i] = io.open(fn, 'w') end
require(api)'def'(api, table.unpack(fs))
for _,f in ipairs(fs) do f:close() end
