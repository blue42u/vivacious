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

local gen = {}

gen.traversal = {}
-- There are multiple traversal schemes out there, with different patterns.
-- All traversals start at `start` and progess down keys that are not handled
-- by the `handler`, which is called with the type, a key and its corrosponding
-- value. The handler returns a boolean value to indicate whether it can handle
-- the key, which may be a function that is called after the sub-tree is fully
-- completed.

local function cocreate(f)
	if gen.gendebug then
		return coroutine.create(function(...)
			assert(xpcall(f, debug.traceback, ...))
		end)
	else return coroutine.create(f) end
end

local post
do
	local named = {}
	local resume
	post = setmetatable({}, {
		__call=function(self)
			repeat
				for co in pairs(self) do resume(co) end
			until not next(self)
		end,
		__newindex=function(self, k, co)
			if type(co) == 'thread' then
				if coroutine.status(co) == 'suspended' then
					rawset(self, co, true)
					if k ~= nil then named[k] = co end
				end
			elseif k ~= nil then named[k] = nil end
		end,
		__index=function(self, k)
			local co = named[k]
			return function(...) if co and rawget(self, co) then resume(co, ...) end end
		end,
	})
	function resume(co, ...)
		assert(coroutine.status(co) == 'suspended')
		repeat
			local res = {coroutine.resume(co, ...)}
			assert(res[1], res[2])
			for i=2,#res do post[nil] = cocreate(res[i]) end
		until #res == 1
		if coroutine.status(co) ~= 'suspended' then rawset(post, co, nil) end
	end
end

local function handle(ty, handler, next)
	post.handle = cocreate(handler)
	post.handle(ty)
	for k in pairs(ty) do if not k:match '^__' then table.insert(next, k) end end
	return next
end

-- Basic depth-first traversal, designed for traversing the type-tree.
function gen.traversal.df(start, handler)
	local done = {}
	local function trav(ty)
		if done[ty] then return else done[ty] = true end
		local next = handle(ty, handler, {})
		table.sort(next)
		for _,k in ipairs(next) do trav(ty[k]) end
		post.handle()
	end
	trav(start)
	post()
end

-- The other thing this `require` does is add a new entry into package.path,
-- that allows the beginning 'apis.' to be left off.
package.path = package.path .. ';./apis/?.lua'

return gen
