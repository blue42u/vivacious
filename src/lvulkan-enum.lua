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

local function enumfixes(name, protect)
	-- If this is from an extension, remove that suffix
	local ext = ''
	if protect then
		ext = '_'..string.match(protect, '^VK_(%u+)')
	end

	-- The only special case (so far)
	if name == 'VkResult' then return '^VK_([%w_]-)'..ext..'$' end

	-- First we determine and remove the author/extension suffix
	local suffix = string.match(name, '(%u+)$')
	if suffix then
		name = string.match(name, '(.*)'..suffix)
		suffix = '_'..suffix
	else
		suffix = ''
	end

	-- Now we convert the CamelCase to CAPITAL_UNDERSCORES
	name = string.gsub(name, '(%u)', '_%1')		-- Add underscores
	name = string.sub(name, 2)	-- Remove the extra first _
	name = string.upper(name)	-- Uppercase it all

	return '^'..name..'_([%w_]-)'..suffix..ext..'$'
end

local enumvs, enumcs = {},{}
local function addenum(enum, const, protect)
	if not enumvs[enum] then enumvs[enum] = {} end
	if not enumcs[enum] then enumcs[enum] = {} end
	local n = string.match(const, enumfixes(enum, protect))
	if string.sub(n, -4) == '_KHR' then
		n = string.sub(n, 1, -4)
	end
	n = string.lower(n)
	enumvs[enum][const] = n
	enumcs[enum][const] = protect
end

for _,es in cpairs(dom.root, {name='enums'}) do
	if es.attr.type == 'enum' then	-- We only handle true enums here
		local fix = enumfixes(es.attr.name)
		for _,e in cpairs(es, {name='enum'}) do
			addenum(es.attr.name, e.attr.name)
		end
	end
end

for _,ext in cpairs(first(dom.root, {name='extensions'}), {name='extension'}) do
	if ext.attr.supported == 'vulkan' then
	for _,r in cpairs(ext, {name='require'}) do
		for _,e in cpairs(r, {name='enum'}) do
			if e.attr.extends and enumvs[e.attr.extends] then
				addenum(e.attr.extends, e.attr.name,
					not e.attr.value and ext.attr.name)
			end
		end
	end
	end
end

out([[
// WARNING: Generated file. Do not edit manually.
// This file is include'd into lvulkan.c. Files were split for readability.

#ifdef IN_LVULKAN

static const char* toname(uint32_t target, const uint32_t* values,
	const char** names) {
	int i = 0;
	while(names[i]) {
		if(values[i] == target)
			return names[i];
		i++;
	}
	return NULL;
}

static const char* toname_s(int32_t target, const int32_t* values,
	const char** names) {
	int i = 0;
	while(names[i]) {
		if(values[i] == target)
			return names[i];
		i++;
	}
	return NULL;
}

]])

for e,vs in pairs(enumvs) do
	out('static const char* '..e..'_names[] = {')
	for c,n in pairs(vs) do
		if enumcs[e][c] then out('#ifdef '..enumcs[e][c]) end
		out('\t"'..n..'",')
		if enumcs[e][c] then out('#endif') end
	end
	out('\t"DEFAULT", NULL};')

	out('static const '..e..' '..e..'_values[] = {')
	for c,n in pairs(vs) do
		if enumcs[e][c] then out('#ifdef '..enumcs[e][c]) end
		out('\t'..c..',')
		if enumcs[e][c] then out('#endif') end
	end
	out('\t0};')

	-- Of couse VkResult has to be different. Is this case, its signed.
	local toname = 'toname'
	if e == 'VkResult' then toname = 'toname_s' end

	out('#define setup_'..e..'(R, P) {};')
	out('#define to_'..e..'(L, D, P) ({ (D) = '
		..e..'_values[luaL_checkoption(L, -1, "DEFAULT", '
		..e..'_names)]; })')
	out('#define free_'..e..'(R, P) {};')
	out('#define push_'..e..'(L, D) ({ lua_pushstring(L, '
		..toname..'((D), '..e..'_values, '..e..'_names)); })')

	out('')
end

out('')

for _,es in cpairs(dom.root, {name="enums"}) do
	if es.attr.type == 'enum' then	-- We only handle true enums here
		local nm = es.attr.name
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
