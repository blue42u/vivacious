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

local lw = {}

-- Get the debugging name for a type. Many types are unnamed, so providing
-- enough information can be difficult.
local function tyname(ty)
	if ty == lw.spec then return '(mainspec)'
	elseif type(ty) == 'string' then return '('..ty..')'
	elseif ty.__name then return ty.__name
	elseif ty.__raw and ty.__raw.C then return '`'..ty.__raw.C..'`'
	else	-- If all else fails, give some info about the type
		local bits = {}
		for k in pairs(ty) do bits[#bits+1] = k:match '^__(.*)' end
		return '(unnamed:'..table.concat(bits, ',')..')'
	end
end

-- The nature of a Type is a rather tree-like structure, which makes writing the
-- wrapper code bothersome. This function wraps a single layer, allowing access
-- to the fields while still checking with field-specific functions.
-- `f` is the function to call first, which checks the table itself.
-- Called with the wrapper itself (to allow for checking) and parent table.
-- `subs` is a table which provides sub-checking functions for each field.
-- Called with the pure value, wrapper for the parent table, and a debugging
-- string path to the current field.
-- `opts` provides extra options to keep `subs` clean. In particular:
-- - `opts.sequence` is the checking function used for sequence elements.
-- - `opts.pairs` enables sequence elements to be iterated with pairs, and this
--   is the function that provides the return values per iteration. Called with
--   the entry to decompose as expected.
-- - `opts.extra` is a table that adds extra fields to the wrapped types. If
--   any of these entries are functions, they are called with the parent pure
--   value, parent wrapper, and a debugging string path.
-- Note that checking functions should return the value to respond with to
-- allow for wrapping (or nil to default to the actual value), and if there is
-- an error they should... error. Obviously.
local function checkwrap(f, subs, opts)
	f,subs,opts = f or function() end, subs or {}, opts or {}
	return function(pure, path, ...)
		if pure == nil then return end	-- Nothing to wrap!
		if type(pure) ~= 'string' then
			assert(type(pure) == 'table', "Types should be tables or strings!")
			assert(getmetatable(pure) == nil, "Metatables aren't allowed in Types!")
			for k in pairs(pure) do
				local function w(err)
					io.stderr:write("WARNING: "..err:gsub('%%(%a)',
						{k=tostring(k), t=type(k)}).." (in "..path..")\n")
				end
				if type(k) == 'string' then
					if not opts.allowunprefixed or k:match '^__' then
						if not subs[k] then w "Unusable string key %k!" end
					end
				elseif math.type(k) == 'integer' then
					if not opts.sequence then w "Unusable integer key %k!" end
				else w "Odd key of type %t (%k)!" end
			end
		end
		local inside = nil
		local trail = {...}

		local wrap = setmetatable({}, {
			__index = function(self, k)
				local wfunc, pa
				if inside and inside[k] ~= nil then	-- Overlay case
					return inside[k]
				elseif math.type(k) == 'integer' then	-- Part of sequence
					wfunc, pa = opts.sequence, (path or '')..'['..k..']'
				elseif type(k) == 'string' then	-- Just an ordinary field
					wfunc, pa = subs[k], path and path..'.'..k or k
				end
				assert(wfunc, "invalid access to field "..(pa or tostring(k)))
				if pure[k] == nil then return nil end	-- Nothing to wrap

				local w
				if wfunc == 'Type' then w = lw.wrappers[pure[k]] else
					local ok
					ok, w = xpcall(wfunc, debug.traceback, pure[k], pa, self, table.unpack(trail))
					if not ok then
						error(w:gsub('\nstack traceback:', ' (at '..pa..')\nstack traceback:'), 0)
					end
					if w == nil then w = pure[k] end
				end
				rawset(self, k, w)
				return w
			end,
			__newindex = function(_, k)
				error("Attempt to modify field "..tostring(k).." of wrapped type!")
			end,
			__pairs = function(self)
				if opts.pairs then
					local i = 0
					return function()
						i = i + 1
						if self[i] then
							return (function(x,...) return x or false,... end)(opts.pairs(self[i], i))
						end
					end
				elseif opts.unprefixedpairs then
					return function(t, old)
						local k = old
						local v
						repeat k,v = next(t, k)
						until type(k) ~= 'string' or not k:find '^__'
						if type(k) == 'string' then v = lw.wrappers[v] end
						return k,v
					end, pure, nil
				else error("Attempt to iterate a wrapped type with pairs!") end
			end,
			__metatable = false,
		})

		if opts.extra then
			inside = {}
			for k,v in pairs(opts.extra) do
				assert(type(k) == 'string', "Extra fields need to have string keys!")
				assert(not subs[k], "Extra field has the same key as a normal key "..k.."!")
				if type(v) == 'function' then inside[k] = v(pure, path, wrap, ...)
				else inside[k] = v end
			end
		end

		f(wrap, ...)
		return wrap
	end
end

-- As part of the system, we do verification of both the generator's access and
-- of the Type itself. These functions provide the wrappers for access.
local realtywrap = checkwrap(nil, {
	__name = function(n) assert(type(n) == 'string', "Names must be strings!") end,
	__doc = function(n) assert(type(n) == 'string', "Docs must be strings!") end,
	__directives = checkwrap(nil, nil, {sequence = function(v)
		if type(v) ~= 'string' then error("Entries must be strings!") end
	end}),
	__enum = checkwrap(nil, nil, {
		pairs = function(e) return e.name, e end,
		sequence = function(v, self)
			assert(type(v) == 'table', "Entries must be tables!")
			assert(type(v.name) == 'string', "Entries must have string names!")
			if self.__raw then
				assert(self.__raw.enum, "")
			end
		end,
		extra={e = function(_, _, self)
				local o = {}
				for k,v in pairs(self) do
					assert(not o[k], "Duplicate entries!")
					o[k] = v
				end
				return o
			end,
		},
	}),
	__mask = function(v, _, p) assert(p.__enum); return not not v end,
	__call = checkwrap(nil, {
		method = function(v) return not not v end,
		nomainret = function(v) return not not v end,
	}, {
		pairs = function(e,i) return e.name or 'val'..i, e end,
		sequence = checkwrap(nil, {
			name = function(n) assert(type(n) == 'string', "Entries must have string names!") end,
			type = 'Type',
			ret = function(v) return not not v end,
			mainret = function(v) return not not v end,
			default = function(v) return v end,
		}),
		extra={e = function(_, _, self)
				local o = {}
				for k,v in pairs(self) do
					assert(not o[k], "Duplicate entries!")
					o[k] = v
				end
				return o
			end,
		},
	}),
	__newindex = checkwrap(function(self)
		local found = {}
		for n in pairs(self) do
			assert(not found[n], "Entry names must be unique, found duplicate of "..n)
			found[n] = true
		end
	end, nil, {
		pairs = function(e) return e.name, e end,
		sequence = checkwrap(function(e) assert(e.name) end, {
			name = function(n) assert(type(n) == 'string', "Entries must have string names!") end,
			type = 'Type',
			aliasof = function(n,_,_,p2) assert(p2.e[n], "Entry must be a valid other field!") end,
			version = function(n) assert(n:match '^%d+%.%d+%.%d+$', "Versions must be in M.m.p form!") end,
			doc = function(n) assert(type(n) == 'string', "Docs must be strings!") end,
			default = function(v) return v end,
		}),
		extra={e = function(_, _, self)
				local o = {}
				for k,v in pairs(self) do
					assert(not o[k], "Duplicate entries!")
					o[k] = v
				end
				return o
			end,
		},
	}),
	__index = checkwrap(nil, nil, {
		pairs = function(e) return e.name, e end,
		sequence = checkwrap(function(e) assert(e.name) end, {
			name = function(n) assert(type(n) == 'string', "Entries must have string names!") end,
			type = 'Type',
			aliasof = function(n,_,_,p2) assert(p2.e[n], "Entry must be a valid other field!") end,
			version = function(n) assert(n:match '^%d+%.%d+%.%d+$', "Versions must be in M.m.p form!") end,
			doc = function(n) assert(type(n) == 'string', "Docs must be strings!") end,
		}),
		extra={e = function(_, _, self)
				local o = {}
				for k,v in pairs(self) do
					assert(not o[k], "Duplicate entries!")
					o[k] = v
				end
				return o
			end,
		},
	}),
	__raw = checkwrap(nil, {
		C = function(s) assert(type(s) == 'string', "Must contain a C version!") end,
		call = function(v) assert(type(v) == 'string', "Must be a string!") end,
	})
}, {
	extra = {
		basic = function(pure) return type(pure) == 'string' and pure end,
		ismain = function(pure) return not not lw.spectys[pure] end,
		specname = function(pure) return pure == lw.spec and lw.specname end,
		name = function(pure) return tyname(pure) end,
	},
	allowunprefixed=true,
	unprefixedpairs=true,
})
function lw.tywrap(pure) return realtywrap(pure, tyname(pure)) end

return lw
