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

local std = {}

-- Basic standard functions, more for ease of use than actual processing
function std.api(t) return {_=t} end
function std.precompound(t)
	return setmetatable(t, {__index=function(t,k)
		if k:match('v%d+_%d+_%d+') then
			t[k] = {}
			return t[k]
		end
	end})
end
function std.presmallcomp(t)
	return setmetatable(t, {__index=function(t,k)
		if k:match('v%d+') then
			t[k] = {}
			return t[k]
		end
	end})
end

-- Wrapper metatable, which sets up the three pieces of each type
local tag = {}
setmetatable(std, {__newindex=function(_,k,s)
	if getmetatable(s) == tag or type(s) == 'function' then
		rawset(std, k, s)
	else
		rawset(std, k, function(t)
			if s.pre then s.pre(t) end
			t._def = s.def or function() end
			t._ref = s.ref or function() error('No ref for '..k) end
			t._sref = s.sref or function(_,w,dn,n)
				w(dn..(n and ' '..n or ''))
			end
			t._macro = s.macro
			t._conv = s.conv
			t._from = k
			return setmetatable(t, tag)
		end)
	end
end})

local function N(p, n) return n and p..n or '' end
local function Wa(strs) return function(s) table.insert(strs, s) end, strs end

-- Basic types, based on the flexible `external` type
std.external = {
	pre = function(self)
		assert(type(self[1]) == 'string', 'externals need a string type!')
	end,
	ref = function(self, w, n)
		if self.ref then n = n and (n:match'%*(.*)' or n) end
		w(self[1]..(self.ref and '*' or '')..(n and ' '..n or ''))
	end,
	conv = function(self, w, v, n)
		local f = self[3] or function(v) return v end
		v = self[2] and self[2]:format(f(v)) or tostring(f(v))
		w(v, n)
	end
}
std.integer = std.external{'int', '%d'}
std.number = std.external{'float', '%f'}
std.string = std.external{'const char*', '%q'}
std.index = std.external{'int', '%d', function(v) return v-1 end}
std.boolean = std.external{'int', '%d', function(v) return v and 1 or 0 end}
std.udata = std.external{'void*', '%s'}

-- Slightly special, but still basic types
std.handle = {
	ref = function(self, w, n, tdef)
		assert(tdef, 'handle needs to be tdefed!')
		w('struct '..n..' '..n) end,
	sref = function(self, w, dn, n)
		w(dn..'*'..(n and ' '..n or ''))
	end,
	conv = function(self, w, v, n) w(tostring(v), n) end
}

std.array = {
	pre = function(self)
		assert(getmetatable(self[1]) == tag, 'arrays need a type type!')
	end,
	def = function(self, s) s(self[1],'(*',')') end,
	ref = function(self, w, n)
		local nsize = math.tointeger(self.size)
		if nsize then nsize = ('[%d]'):format(nsize) end
		if n then
			if not self.size then
				local ncnt = n:match'[^*]' and n..'Cnt' or n
				w('size_t '..ncnt)
			end
			n = n:match'%*(.*)' or n
			self[1]:_ref(w, nsize and n..nsize or ' *'..n)
		else
			if not self.size then w('size_t') end
			self[1]:_ref(w, nsize or ' *')
		end
	end,
	conv = function(self, w, v, n)
		local sw,strs = Wa{'('}
		self[1]:_ref(sw, '[]')
		sw('){')
		for _,e in ipairs(v) do self[1]:_conv(sw, e) end
		sw('}')
		if not self.size then
			std.integer:_conv(w, #v, n and n..'Cnt')
		end
		w(#v > 0 and table.concat(strs) or 'NULL', n)
	end,
}

local function mempairs(self, vpatt)
	local vers = {}
	for k,vt in pairs(self) do
		local v = table.pack(k:match(vpatt))
		for i,x in ipairs(v) do v[i] = math.tointeger(x) end
		if #v > 0 then
			v.k,v.t = k,{}
			for n in pairs(vt) do v.t[#v.t+1] = n end
			table.sort(v.t)
			vers[#vers+1] = v
		end
	end
	table.sort(vers, function(a,b)
		if #a ~= #b then error('mempairs pattern must have a constant number of returns!') end
		for i=1,#a do if a[i] ~= b[i] then return a[i] < b[i] end end
	end)
	local ind = {i=1, v=1}
	return function()
		while vers[ind.v] do
			local v = vers[ind.v]
			while v.t[ind.i] do
				local n = v.t[ind.i]
				ind.i = ind.i + 1
				local t = self[v.k][n]
				if type(t) == 'table' then
					return v, n, table.unpack(t)
				else return v, n, t end
			end
			ind.v = ind.v + 1
			ind.i = 1
		end
	end
end

-- Larger, but still fundementally basic types
std.enum = {
	ref = function(self, w, n, tdef)
		if not tdef then error('enums must be tdef\'d!') end
		local mems = {'enum {\n'}
		local val = 0
		for _,_,e in mempairs(self, 'v(%d+)_(%d+)_(%d+)') do
			mems[#mems+1] = '\t'..n..'_'..e..' = '..val..',\n'
			val = val+1
		end
		mems[#mems+1] = '} '
		mems[#mems+1] = n
		w(table.concat(mems))
		self._prefix = n..'_'
	end,
	conv = function(self, w, v, n)
		w(self._prefix..v, n)
	end,
}
std.bitmask = {
	ref = function(self, w, n, tdef)
		if not tdef then error('bitmasks must be tdef\'d!') end
		local mems = {'enum {\n\t'..n..'_NONE = 0,\n'}
		local val = 0
		for _,_,e in mempairs(self, 'v(%d+)_(%d+)_(%d+)') do
			mems[#mems+1] = '\t'..n..'_'..e..' = 1<<'..val..',\n'
			val = val + 1
		end
		mems[#mems+1] = '} '
		mems[#mems+1] = n
		w(table.concat(mems))
		self._prefix = n..'_'
	end,
	conv = function(self, w, v, n)
		w(self._prefix..v, n)
	end,
}

-- Complex compound types
std.func = {
	pre = function(self)
		if self.returns then
			if getmetatable(self.returns) ~= tag then
				for i=1,#self.returns do
					local t = self.returns[i]
					assert(getmetatable(t) == tag, 'function returns must be types (#'..i..', got '..type(t)..')')
				end
			else self.returns = {self.returns} end
		else self.returns = {} end
		for _,r in ipairs(self.returns) do
			if r._from=='array' or r._from=='ref' then r = r[1] end
			assert(r._from ~= 'compound',
				'functions cannot return large compounds!')
		end
		for i,t in ipairs(self) do
			if getmetatable(t) == tag then
				self[i] = {t}
			else
				assert(getmetatable(t[1]) == tag, 'function arguments must be types (#'..i..')')
			end
		end
	end,
	def = function(self, s)
		for _,t in ipairs(self.returns) do s(t) end
		for _,m in ipairs(self) do s(m[1]) end
	end,
	ref = function(self, w, n)
		local ret = table.remove(self.returns, self.returns.main or 1)
		local erets = {}
		if ret then
			if ret._from == 'array' and ret.size
				or ret._from == 'external' and ret.ref then
				table.insert(self.returns, self.returns.main or 1, ret)
				ret = 'void'
			else
				local nret
				ret:_ref(function(s)
					if not nret then nret = s
					else erets[#erets+1] = s end
				end)
				ret = nret
			end
		else ret = 'void' end
		local aw,args = Wa{}
		if self._callback then std.udata:_ref(aw, 'ud') end
		for _,m in ipairs(self) do m[1]:_ref(aw, m[2]) end
		for _,e in ipairs(erets) do aw(e) end
		for _,r in ipairs(self.returns) do r:_ref(aw, '*') end
		w(table.concat{
			ret,' (*',n or '',')(',table.concat(args, ', '),')'
		})
		if self._callback then std.udata:_ref(w, n and n..'_ud') end
	end,
	conv = function(self, w, v, n)
		w('NULL', n)
	end,
}
std.method = std.func	-- C doesn't have "methods", they're just functions
std.callback = function(t) t._callback = true; return std.func(t) end

-- The normal compound, which can expand between versions
std.compound = {
	pre = function(self)
		for k,vt in pairs(self) do if k:match'v%d+_%d+_%d+' then
			for n,m in pairs(vt) do
				if getmetatable(m) == tag then
					vt[n] = {m}
				elseif type(m) == 'table' then m = m[1] end
				assert(getmetatable(m) == tag, 'compound members must be types (member '..n..' is '..type(m)..')!')
			end
		end end
	end,
	def = function(self, s)
		for k,vt in pairs(self) do if k:match'v%d+_%d+_%d+' then
			for n,m in pairs(vt) do
				s(m[1], '', '->'..n, n)
			end
		end end
	end,
	ref = function(self, w, n, tdef)
		local mems = {'struct ', tdef and n..' ' or '', '{\n'}
		local cdef
		for _,n,t in mempairs(self, 'v(%d+)_(%d+)_(%d+)') do
			if t.const ~= cdef then
				if cdef then mems[#mems+1] = '#endif\n' end
				mems[#mems+1] = '#ifdef '..t.const..'\n'
				cdef = t.const
			end
			t:_ref(function(s)
				mems[#mems+1] = '\t'
					..s:gsub('\n', '\n\t')..';\n'
			end, n)
		end
		if cdef then mems[#mems+1] = '#endif\n' end
		mems[#mems+1] = '} '
		if not tdef then mems[#mems+1] = '*' end
		mems[#mems+1] = n
		w(table.concat(mems))
	end,
	sref = function(self, w, dn, n)
		w(dn..'*'..(n and ' '..n or ''))
	end,
	macro = function(self, w, n)
		local defs = {}
		for v,n,t,d in mempairs(self, 'v(%d+)_(%d+)_(%d+)') do
			if d then defs[n] = d end
		end
		local sw,strs = Wa{'#define ',n,'(...) ((',n,')'}
		self:_conv(sw, defs)
		strs[#strs] = strs[#strs]:sub(1, -2)	-- Remove last }
		sw('__VA_ARGS__})')
		w(table.concat(strs))
	end,
	conv = function(self, w, v, n)
		local sw,strs = Wa{'{'}
		for _,n,t in mempairs(self, 'v(%d+)_(%d+)_(%d+)') do
			if v[n] then
				t:_conv(function(s, n)
					sw('.'..n..'='..s..',')
				end, v[n], n)
			end
		end
		sw('}')
		w(table.concat(strs), n)
	end,
}

-- The "smaller" compound, which can only change on major versions
std.smallcomp = {
	pre = function(self)
		for k,vt in pairs(self) do if k:match'v%d+' then
			for n,m in pairs(vt) do
				if getmetatable(m) == tag then
					vt[n] = {m}
				else assert(getmetatable(m[1]) == tag) end
			end
		end end
	end,
	def = function(self, s)
		for k,vt in pairs(self) do if k:match'v%d+' then
			for n,m in pairs(vt) do
				s(m[1], '', '.'..n, n)
			end
		end end
	end,
	ref = function(self, w, n)
		local mems = {'struct {\n'}
		for _,n,t in mempairs(self, 'v(%d+)') do
			t:_ref(function(s)
				mems[#mems+1] = '\t'
					..s:gsub('\n', '\n\t')..';\n'
			end, n)
		end
		mems[#mems+1] = '} '
		mems[#mems+1] = n
		w(table.concat(mems))
	end,
	macro = function(self, w, n)
		local defs = {}
		for _,n,_,d in mempairs(self, 'v(%d+)') do
			if d then defs[n] = d end
		end
		local sw,strs = Wa{'#define ',n,'(...) ((',n,')'}
		self:_conv(sw, defs)
		strs[#strs] = strs[#strs]:sub(1, -2)	-- Remove last }
		sw('__VA_ARGS__})')
		w(table.concat(strs))
	end,
	conv = function(self, w, v, n)
		local sw,strs = Wa{'{'}
		for _,n,t in mempairs(self, 'v(%d+)') do
			if v[n] then
				t:_conv(function(s, n)
					sw('.'..n..'='..s..',')
				end, v[n], n)
			end
		end
		sw('}')
		w(table.concat(strs), n)
	end,
}

return std
