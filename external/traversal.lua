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

local trav = {}

local function tagcmp(t, w)
	for k,v in pairs(w) do
		if k ~= 'attr' and t[k] ~= v then return false end
	end
	if w.attr then
		for k,v in pairs(w.attr) do
			if t.attr[k] ~= v then return false end
		end
	end
	return true
end

function trav.cpairs(tag, where)
	return function(_,i)
		repeat
			i = i + 1
			local t = tag.kids[i]
			if t and tagcmp(t, where) then return i, t end
		until not t
	end, nil, 0
end

function trav.first(tag, ...)
	for _,where in ipairs(table.pack(...)) do
		local newtag
		for _,t in ipairs(tag.kids) do
			if tagcmp(t, where) then
				newtag = t
				break
			end
		end
		if not newtag then return nil end
		tag = newtag
	end
	return tag
end

return trav
