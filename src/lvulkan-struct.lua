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
	if ss.attr.category == 'struct' then	-- We only handle structs here
		local name = ss.attr.name or
			first(ss, {name="name"}, {type="text"}).value

		local mems = {}
		for _,m in cpairs(ss, {name="member"}) do
			local tp = first(m, {name="type"}, {type="text"}).value
			local mn = first(m, {name="name"}, {type="text"}).value
			local pr,ar = findptr(m),findarr(m)
			if pr == '* const*' then pr = '**' end
			if tp == 'char' then tp = 'string'
				pr = string.sub(pr,2) end
			if pr ~= '' and pr ~= '*' then error(pr) end
			table.insert(mems, {t=tp, n=mn, p=pr, m=m, a=ar,
				l=m.attr.len})
		end
		-- Figure out whether this type has any subtypes early.
		local comp = false
		for _,m in ipairs(mems) do
			if #m.p > 0 then
				comp = true
				break
			end
		end

-- NOTE: Currently in Vulkan, there are no members which define a static-length
-- array of pointers. This may happen in the future, so we test for it here.
		for _,m in ipairs(mems) do if m.a and #m.p > 0 then
			error('Array of pointers: '..name..'.'..m.n..'!')
		end end

		out('#define push_'..name..'(L, R)')

		if ss.attr.returnedonly then goto returnonly end

		if not comp then
			fout([[
#define size_`name`(L) sizeof(`name`)]], {name=name})
		else
			fout([[
#define size_`name`(L) ({ \
	size_t res = sizeof(`name`); \
\]], {name=name})
			for _,m in ipairs(mems) do
				if #m.p > 0 and m.t ~= 'void' then
					if m.l then fout([[
	lua_getfield(L, -1, "`n`"); \
	if(!lua_isnil(L, -1)) { \
		lua_len(L, -1); \
		int len = lua_tointeger(L, -1); \
		lua_pop(L, 1); \
		for(int i=1; i<=len; i++) { \
			lua_geti(L, -1, i); \
			res += size_`t`(L); \
			lua_pop(L, 1); \
		} \
	} \
	lua_pop(L, 1); \
\]], m)
					else fout([[
	lua_getfield(L, -1, "`n`"); \
	if(!lua_isnil(L, -1)) res += size_`t`(L); \
	lua_pop(L, 1); \
\]], m)
					end
				end
			end
			out([[
	res; })]])
		end

		if not comp then
			out('#define to_'..name..'(L, R) ({ \\')
			for _,m in ipairs(mems) do
				fout([[
	lua_getfield(L, -1, "`n`"); \
	if(!lua_isnil(L, -1)) to_`t`(L, &((]]..name..[[*)R)->`n`); \
	lua_pop(L, 1); \
\]], m)
			end
			out('\t(void*)(R) + sizeof('..name..'); })')
		else
			out('#define to_'..name..'(L, R)')
		end

::returnonly::
		out('')
	end
end

out('#endif // IN_LVULKAN')

if waserr > 0 then
	error('Errors happened: '..waserr..' to be exact!')
end

local f = io.open(arg[1], 'w')
f:write(table.concat(outtab, '\n'))
f:close()
