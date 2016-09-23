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

package.path = package.path..';'..arg[2]..'/?.lua'
local trav = require('traversal')
local cpairs, first = trav.cpairs, trav.first

local xml = io.open(arg[2]..'/vk.xml', 'r'):read('a')
local dom = require('slaxdom'):dom(xml, {stripWhitespace=true})

local outtab = {}
local waserr = 0
local function out(s) table.insert(outtab, s) end
local function derror(err) print(err) ; waserr = waserr + 1 end

local function fout(s, t)
	for k,v in pairs(t) do
		s = string.gsub(s, '`'..k..'`', v)
	end
	out(s)
end

out([[
// WARNING: Generated file. Do not edit manually.
// This file is include'd into lvulkan.c. Files were split for readability.

#ifdef IN_LVULKAN
]])

for _,ss in cpairs(first(dom.root, {name="types"}), {name="type"}) do
	if ss.attr.category == 'struct' then
		local nm = ss.attr.name
		if string.sub(nm, -3) ~= 'KHR' and nm ~= 'VkRect3D' then	-- Edit out WSI
		fout([[
// Compile test for `nm`
static void test_`nm`(lua_State* L) {
	`nm` val;]], {nm=nm})
		if not ss.attr.returnedonly then
			fout([[
	size_t extrasize;
	size_`nm`(L, extrasize);
	void* extra = malloc(extrasize);
	to_`nm`(L, val, extra);
	free(extra);
]], {nm=nm})
		end
		out('\tpush_'..nm..'(L, val);')
		out('}')
		end
	end
end

out('#endif // IN_LVULKAN')

if waserr > 0 then
	error('Errors happened: '..waserr..' to be exact!')
end

local f = io.open(arg[1], 'w')
f:write(table.concat(outtab, '\n'))
f:close()
