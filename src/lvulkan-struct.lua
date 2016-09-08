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

		local mems = {}
		for _,m in cpairs(ss, {name="member"}) do
			local tp = first(m, {name="type"}, {type="text"}).value
			local mn = first(m, {name="name"}, {type="text"}).value
			local pr = findptr(m)
			if pr == '* const*' then pr = '**' end
			if tp == 'char' then tp = 'string'
				pr = string.sub(pr,2) end
			if pr ~= '' and pr ~= '*' then error(pr) end
			table.insert(mems, {t=tp, n=mn, p=pr, m=m,
				l=m.attr.len})
		end

		if not ss.attr.returnedonly then
		out('#define setup_'..name..'(R, P) \\')
		for _,m in ipairs(mems) do
			if m.t == 'void' then
			elseif #m.p == 1 then
				if m.l then
				out('\t'..m.t..m.p..' P##_'..m.n..'; \\')
				else
				out('\t'..m.t..' P##_'..m.n..'; \\')
				out('\tsetup_'..m.t..'((R).'..m.n
					..', P##_'..m.n..') \\')
				end
			elseif #m.p == 0 then
			else error() end
		end
		out('// END setup_'..name)

		out('#define to_'..name..'(L, R, P) ({ \\')
		for _,m in ipairs(mems) do
			out('\tlua_getfield(L, -1, "'..m.n..'"); \\')
			if m.t == 'void' then
			elseif #m.p == 1 then
				if m.m.attr.len then
				else
				end
			elseif #m.p == 0 then
				out('\tto_'..m.t..'(L, (R).'..m.n..', P##_'
					..m.n..'); \\')
			else error() end
			out('\\')
		end
		out('})')

		out('#define free_'..name..'(R, P)')
		end

		out('#define push_'..name..'(L, R)')

		out('')
	end
end

out('')

for _,ss in cpairs(first(dom.root, {name="types"}), {name="type"}) do
	if ss.attr.category == 'struct' then	-- We only handle structs here
		local nm = ss.attr.name
		if string.sub(nm, -3) ~= 'KHR' then	-- TMP for testing
		out([[
// Compile test for ]]..nm..[[:
static void test_]]..nm..[[(lua_State* L) {
	]]..nm..[[ val;]])
		if not ss.attr.returnedonly then
			out([[
	setup_]]..nm..[[(val, val)
	to_]]..nm..[[(L, val, val);
	free_]]..nm..[[(val, val);]])
		end
		out('\tpush_'..nm..'(L, val);')
		out('}')
		end	-- TMP for testing
	end
end

out('#endif // IN_LVULKAN')

if waserr > 0 then
	error('Errors happened: '..waserr..' to be exact!')
end

local f = io.open(arg[1], 'w')
f:write(table.concat(outtab, '\n'))
f:close()
