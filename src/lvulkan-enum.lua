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

local function enumfixes(name)
	-- The only special case (so far)
	if name == 'VkResult' then return '^VK_([%w_]+)$' end

	-- First we determine and remove the author/extension suffix
	local suffix = string.match(name, '(%u+)$')
	if suffix then
		name = string.match(name, '(.*)'..suffix)
	end

	-- Now we convert the CamelCase to CAPITAL_UNDERSCORES
	name = string.gsub(name, '(%u)', '_%1')		-- Add underscores
	name = string.sub(name, 2)	-- Remove the extra first _
	name = string.upper(name)	-- Uppercase it all

	return '^'..name..'_([%w_]+)'..(suffix and '_'..suffix or '')..'$'
end

out([[
// WARNING: Generated file. Do not edit manually.
// This file is include'd into lvulkan.c. Files were split for readability.

#ifdef IN_LVULKAN
]])

for _,es in cpairs(dom.root, {name="enums"}) do
	if es.attr.type == 'enum' then	-- We only handle true enums here
		local fix = enumfixes(es.attr.name)
		local values = {}
		for _,e in cpairs(es, {name="enum"}) do
			local v = math.tointeger(e.attr.value)
				or math.tointeger(2^e.attr.bitpos)
			local n = string.match(e.attr.name, fix)
			n = string.lower(n)
			values[v] = n
		end

		out('static const char* '..es.attr.name..'_names[] = {')
		for v,n in pairs(values) do
			out('\t"'..n..'",')
		end
		out('\tNULL};')

		out('static '..es.attr.name..' '..es.attr.name..'_values[] = {')
		for v,n in pairs(values) do
			out('\t'..v..',\t// '..n)
		end
		out('\t0};')

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