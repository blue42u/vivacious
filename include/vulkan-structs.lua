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
local fir,sel = trav.find, trav.select

local xml = io.open('vk.xml', 'r'):read('a')
local dom = require('slaxdom'):dom(xml, {stripWhitespace=true})

local function dump(t)
	if type(t) == 'table' then
		for k,v in pairs(t) do print(k,v) end
	else print(t) end
end

local f = io.open(arg[1], 'w')
f:write([[
#include <vulkan/vulkan.h>

]])

sel(dom.root.kids, {name='feature'}, function(tag)
	if tag.attr.api ~= 'vulkan' then return end

	f:write([[
#ifdef ]]..tag.attr.name..[[ // Vulkan core

typedef struct {
]])

	sel(tag.kids, {name='require'}, function(tag)
		sel(tag.kids, {name='command'}, function(tag)
			local n = tag.attr.name
			f:write('\tPFN_'..n..' '..n..';\n')
		end)
	end)

	f:write([[
} * VvVulkan_]]..string.gsub(tag.attr.number, '%.', '_')..[[;

#endif // ]]..tag.attr.name..'\n\n')
end)
