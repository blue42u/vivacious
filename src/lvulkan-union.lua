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

local function findarr(m)
	local namei
	for i,k in ipairs(m.kids) do
		if k.name == 'name' then
			namei = i
			break
		end
	end
	for i=namei+1,#m.kids do
		if m.kids[i].type == 'text' then
			return string.match(m.kids[i].value, '%[(.-)%]')
		end
	end
	return
end

out([[
// WARNING: Generated file. Do not edit manually.
// This file is include'd into lvulkan.c. Files were split for readability.

#ifdef IN_LVULKAN
]])

for _,ss in cpairs(first(dom.root, {name="types"}), {name="type"}) do
	if ss.attr.category == 'union' then	-- We only handle structs here
		local name = ss.attr.name or
			first(ss, {name="name"}, {type="text"}).value

		local mems = {}
		for _,m in cpairs(ss, {name="member"}) do
			local tp = first(m, {name="type"}, {type="text"}).value
			local mn = first(m, {name="name"}, {type="text"}).value
			table.insert(mems, {t=tp, n=mn, m=m, a=findarr(m)})
		end

		out('#define size_'..name..'(L) sizeof('..name..')')

		out('#define to_'..name..'(L, R) ({ \\')
		out('\tint cont = 1; \\')
		for _,m in ipairs(mems) do
			if not m.a then
				fout([[
	if(cont) { \
		lua_getfield(L, -1, "`n`"); \
		if(!lua_isnil(L, -1)) { \
			to_`t`(L, &((]]..name..[[*)R)->`n`); \
			cont = 0; \
		} \
		lua_pop(L, 1); \
	} \
\]], m)
			else
				fout([[
	if(cont) { \
		lua_getfield(L, -1, "`n`"); \
		if(!lua_isnil(L, -1)) { \
			for(int i=0; i<`a`; i++) { \
				lua_geti(L, -1, i+1); \
				to_`t`(L, &((]]..name..[[*)R)->`n`[i]); \
				lua_pop(L, 1); \
			} \
			cont = 0; \
		} \
		lua_pop(L, 1); \
	} \
\]], m)
			end
		end
		out('})\n')
	end
end

out('#endif // IN_LVULKAN')

if waserr > 0 then
	error('Errors happened: '..waserr..' to be exact!')
end

local f = io.open(arg[1], 'w')
f:write(table.concat(outtab, '\n'))
f:close()
