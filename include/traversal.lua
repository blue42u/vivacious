--[========================================================================[
   Copyright 2016 Jonathon Anderson

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

local trav = {}

function trav.select(ts, where, func)
	for _,t in ipairs(ts) do
		local doit
		if type(where) == 'function' then
			doit = where(t)
		else
			for k,v in pairs(where) do
				doit = t[k] == v
			end
		end
		if doit then
			if func(t) then return end
		end
	end
	return all
end

function trav.find(t, where, all)
	if all then all = {} else all = nil end
	local out
	trav.select(t, where, function(t)
		if all then table.insert(all,t) else out = t end
		return not all
	end)
	return out or all
end

return trav
