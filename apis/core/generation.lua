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

local function handle(ty, handler, next)
	local co = coroutine.create(handler)
	assert(coroutine.resume(co, ty))
	for k in pairs(ty) do if not k:match '^__' then table.insert(next, k) end end
	return co, next
end

-- Basic depth-first traversal, designed for traversing the type-tree.
function gen.traversal.df(start, handler)
	local done = {}
	local function trav(ty)
		if done[ty] then return else done[ty] = true end
		local co,next = handle(ty, handler, {})
		table.sort(next)
		for _,k in ipairs(next) do trav(ty[k]) end
		if coroutine.status(co) == 'suspended' then assert(coroutine.resume(co)) end
	end
	trav(start)
end

return gen
