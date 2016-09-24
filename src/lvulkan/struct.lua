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

local function fout(s, ...)
	for _,t in ipairs(table.pack(...)) do
		for k,v in pairs(t) do
			s = string.gsub(s, '`'..k..'`', v)
		end
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
	local arrstr = ''
	local function append(t)
		if t.type == 'text' then
			arrstr = arrstr .. t.value
		else
			for _,k in ipairs(t.kids) do
				append(k)
			end
		end
	end
	for i=namei+1,#m.kids do
		append(m.kids[i])
	end
	return string.match(arrstr, '%[(.-)%]')
end

local latex = {
	VkShaderModuleCreateInfo_pCode = 'codeSize // 4',
	VkPipelineMultisampleStateCreateInfo_pSampleMask =
		'ceil((D).rasterizationSamples / 32)',
}
local void = {	-- TODO: Overanilize the potential in these.
	VkSpecializationInfo_pData = true,
	VkPipelineCacheCreateInfo_pInitialData = true,
	VkDebugReportCallbackCreateInfoEXT_pUserData = true,
	VkDebugMarkerObjectTagInfoEXT_pTag = true,
}

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
			if tp == 'char' and #pr > 0 then
				tp = 'string'
				pr = string.sub(pr,2)
			elseif tp =='char' and ar then
				tp = 'string'
				ar = nil
				pr = ''
			end
			if pr ~= '' and pr ~= '*' then error(pr) end
			local ln = m.attr.len
			if #pr > 0 and tp == 'string' then
				ln = string.match(ln, '(.*),.*$')
			end
			local lx
			if ln and string.sub(ln, 1, 9) == 'latexmath' then
				lx = latex[name..'_'..mn]
				if not lx then
					derror('Unhandled latex: '
						..name..'.'..mn)
				end
			end
			table.insert(mems, {t=tp, n=mn, p=pr, m=m, a=ar,
				l=ln, latex=lx})
		end

-- NOTE: Currently in Vulkan, there are no members which define a static-length
-- array of pointers. This may happen in the future, so we test for it here.
		for _,m in ipairs(mems) do if m.a and #m.p > 0 then
			error('Array of pointers: '..name..'.'..m.n..'!')
		end end


		fout([[
#define push_`name`(L, D) ({ \
	lua_newtable(L); \
\]], {name=name})
		for _,m in ipairs(mems) do
			if #m.p > 0 then
				if m.t == 'void' then
					if m.n == 'pNext' then
						-- pNext is never returned.
					elseif name == 'VkAllocationCallbacks'
						and m.n == 'pUserData' then
						-- Exception. TODO: Write.
					elseif not void[name..'_'..m.n] then
					derror(
						'Hello, Void, my old friend: '
						..name..'.'..m.n)
					end
				elseif m.l then
					if not m.latex then fout([[
	lua_newtable(L); \
	for(int i=0; i<(D).`l`; i++) { \
		push_`t`(L, (D).`n`[i]); \
		lua_seti(L, -2, i+1); \
	} \
	lua_setfield(L, -2, "`n`"); \
\]], m, {name=name})
					end
				else fout([[
	push_`t`(L, *((D).`n`)); \
	lua_setfield(L, -2, "`n`"); \
\]], m, {name=name})
				end
			elseif m.a then fout([[
	lua_createtable(L, `a`, 0); \
	for(int i=0; i<`a`; i++) { \
		push_`t`(L, (D).`n`[i]); \
		lua_seti(L, -2, i+1); \
	} \
	lua_setfield(L, -2, "`n`"); \
\]], m, {name=name})
			else fout([[
	push_`t`(L, (D).`n`); \
	lua_setfield(L, -2, "`n`"); \
\]], m, {name=name})
			end
		end
		out('})')

		if not ss.attr.returnedonly then

		fout([[
#define size_`name`(L, O)]], {name=name})
		fout([[
#define to_`name`(L, D, R)]], {name=name})

		end	-- returnedonly
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
