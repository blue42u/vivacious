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

io.output(arg[1])

local cmdtypes = {}
for _,t in cpairs(first(dom.root, {name='commands'}), {name='command'}) do
	local name = first(t,{name='proto'},{name='name'},{type='text'}).value
	local type = first(t,{name='param'},{name='type'},{type='text'}).value
	cmdtypes[name] = type
end

local typepars = {}
for _,t in cpairs(first(dom.root, {name='types'}), {name='type'}) do
	if t.attr.category == 'handle' then
		local type = first(t,{name='name'},{type='text'}).value
		typepars[type] = t.attr.parent
	end
end

local cmdcats = {}
for c,t in pairs(cmdtypes) do
	while t ~= 'VkInstance' and t ~= 'VkDevice' and t do
		t = typepars[t]
	end
	cmdcats[c] = t == 'VkInstance' and 'instance' or
		(t == 'VkDevice' and 'device' or 'global')
end

local function out(s) io.write(s..'\n') end

out([[
/*****************
This file is generated as part of compiling
Vivacious. If changes need to be made, please
edit the corrosponding generation file,
/path/to/vivacious/src/vulkan.lua
*****************/

#include "vivacious/vulkan.h"
]])

for _,t in cpairs(dom.root, {name='feature',attr={api='vulkan'}}) do
	local const = t.attr.name
	local ver = string.gsub(t.attr.number, '%.', '_')

	local allcmds = {}
	local cmdnames = {}
	for _,t in cpairs(t, {name='require'}) do
		for _,t in cpairs(t, {name='command'}) do
			local name = t.attr.name
			table.insert(allcmds, name)
			if string.sub(name, 1, 2) == 'vk' then
				cmdnames[name] = string.sub(name, 3)
			else
				cmdnames[name] = name
			end
		end
	end

	out([[
#if defined(]]..const..[[)
int vV_loadVulkan_]]..ver..[[(vV_Vulkan_]]..ver..[[* vk) {
]])
	for _,cmd in ipairs(allcmds) do
		out('vk->'..cmdnames[cmd]..' = NULL; //'..cmd..';')
	end
	out([[
	return 0;	// Error, since not implemented
}

static void optimizeInstance_vV_]]..ver..[[(VkInstance i,
	vV_Vulkan_]]..ver..[[* vk) {
]])
	for _,cmd in ipairs(allcmds) do
		if cmdcats[cmd] == 'instance' then
			out('vk->'..cmdnames[cmd]..' = (PFN_'..cmd..
				')vk->GetInstanceProcAddr(i, "'..cmd..'");')
		end
	end
	out([[
}

static void optimizeDevice_vV_]]..ver..[[(VkDevice d,
	vV_Vulkan_]]..ver..[[* vk) {
]])
	for _,cmd in ipairs(allcmds) do
		if cmdcats[cmd] == 'device' then
			out('vk->'..cmdnames[cmd]..' = (PFN_'..cmd..
				')vk->GetDeviceProcAddr(d, "'..cmd..'");')
		end
	end
	out([[
}
#endif
]])
end
