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

local function handle(ty, handler, next, post)
	local h,ord = {},{}
	setmetatable(h, {__newindex=function(t,k,v)
		rawset(t, k, v)
		ord[#ord+1],ord[k] = k,#ord+1
	end})
	local hp,hpp = handler(ty, h)

	local keys = {}
	for k in pairs(ty) do keys[#keys+1] = k end
	table.sort(keys, function(a,b) return (ord[a] or math.huge) < (ord[b] or math.huge) end)
	for _,k in ipairs(keys) do
		local v = ty[k]
		if h[k] then
			if type(h[k]) == 'function' then
				local p = h[k](v)
				if type(p) == 'function' then table.insert(post, p) end
			end
		else
			assert(not k:match '^__', "Unhandled special "..k)
			table.insert(next, v)
		end
	end
	if hp then hp() end
	if hpp then table.insert(post, hpp) end
end

-- Basic depth-first traversal, designed for traversing the type-tree.
function gen.traversal.df(start, handler)
	local done = {}
	local function trav(ty)
		if done[ty] then return else done[ty] = true end
		local next, post = {},{}
		handle(ty, handler, next, post)
		for _,n in ipairs(next) do trav(n) end
		for _,p in ipairs(post) do p() end
	end
	trav(start)
end

return gen
