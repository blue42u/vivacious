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

local function coresume(co, ...)
	local res = {coroutine.resume(co, ...)}
	if not res[1] then error(res[2]) end
	return table.unpack(res, 2)
end

local function hres(co, cansub, ...)
	if coroutine.status(co) == 'suspended' then
		local when = coresume(co, ...)
		assert(not when == (coroutine.status(co) == 'dead'),
			"Handler should yeild strings and return nil!")
		if not cansub then assert(when ~= 'sub', "Handler cannot sub now!") end
		if when then
			assert(({sub=true, post=true})[when], "Handler should only indicate sub or post!")
		end
		return when
	end
end

local afterwards = {}
local function finishup()
	repeat
		for co in pairs(afterwards) do
			if not hres(co) then afterwards[co] = nil end
		end
	until not next(afterwards)
end

local function onety(ty, handler, pump)
	local co = cocreate(handler)
	local when = hres(co, true, ty)
	for k,v in pairs(ty) do if not k:match '^__' then pump(k, v) end end
	if when == 'sub' then when = hres(co) end
	if when == 'post' then afterwards[co] = true end
end

-- Basic depth-first traversal, designed for traversing the type-tree.
function gen.traversal.df(start, handler)
	local done = {}
	local function trav(ty)
		if done[ty] then return else done[ty] = true end
		onety(ty, handler, function(_,v) trav(v) end)
	end
	trav(start)
	finishup()
end

-- The other thing this `require` does is add a new entry into package.path,
-- that allows the beginning 'apis.' to be left off.
package.path = package.path .. ';./apis/?.lua'

return gen
