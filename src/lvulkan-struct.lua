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

local function findptr(m)
	local typei
	for i,k in ipairs(m.kids) do
		if k.name == 'type' then
			typei = i
			break
		end
	end
	for i=typei+1,#m.kids do
		if m.kids[i].type == 'text' then
			return m.kids[i].value
		elseif m.kids[i].name == 'name' then
			break
		end
	end
	return ''
end

out([[
// WARNING: Generated file. Do not edit manually.
// This file is include'd into lvulkan.c. Files were split for readability.

#ifdef IN_LVULKAN

]])

for _,ss in cpairs(first(dom.root, {name="types"}), {name="type"}) do
	if ss.attr.category == 'struct' then	-- We only handle structs here
		local name = ss.attr.name or
			first(ss, {name="name"}, {type="text"}).value
		out('// STRUCT '..name)

		local mems = {}
		for _,m in cpairs(ss, {name="member"}) do
			local tp = first(m, {name="type"}, {type="text"}).value
			local mn = first(m, {name="name"}, {type="text"}).value
			local pr = findptr(m)
			if pr == '* const*' then pr = '**' end
			if tp == 'char' then tp = 'string'
				pr = string.sub(pr,2) end
			if pr ~= '' and pr ~= '*' then error(pr) end
			table.insert(mems, {t=tp, n=mn, p=pr, m=m})
		end

		out('#define setup_'..name..'(R, P) {};')
		out('#define to_'..name..'(L, D, P) {};')
		out('#define free_'..name..'(D, P) {};')
		out('#define push_'..name..'(L, D) {};')

		for _,m in ipairs(mems) do
			out('\t// '..m.t..m.p..' '..m.n)
		end

		out('')
	end
end

out('')

for _,ss in cpairs(first(dom.root, {name="types"}), {name="type"}) do
	if ss.attr.category == 'struct' then	-- We only handle structs here
		local nm = ss.attr.name
		out([[
// Compile test for ]]..nm..[[:
static void test_]]..nm..[[(lua_State* L) {
	]]..nm..[[ val;
	setup_]]..nm..[[(val, val);
	to_]]..nm..[[(L, val, val);
	free_]]..nm..[[(val, val);
	push_]]..nm..[[(L, val);
}
]])
	end
end

out('#endif // IN_LVULKAN')

if waserr > 0 then
	error('Errors happened: '..waserr..' to be exact!')
end

local f = io.open(arg[1], 'w')
f:write(table.concat(outtab, '\n'))
f:close()
