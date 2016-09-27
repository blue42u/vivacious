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

local xml = io.open('vk.xml', 'r'):read('a')
local dom = require('slaxdom'):dom(xml, {stripWhitespace=true})

io.output(arg[1])

local cmds = {}
for _,t in cpairs(dom.root, {name='feature',attr={api='vulkan'}}) do
	local const = t.attr.name
	for _,t in cpairs(t, {name='require'}) do
		for _,t in cpairs(t, {name='command'}) do
			if not cmds[t.attr.name] then
				cmds[#cmds+1] = t.attr.name
				cmds[t.attr.name] = 'defined('..const..')'
			else
				cmds[t.attr.name] = cmds[t.attr.name]
					..' || defined('..const..')'
			end
		end
	end
end
for _,t in cpairs(first(dom.root, {name='extensions'}), {name='extension',
	attr={supported='vulkan'}}) do
	local const = t.attr.name
	for _,t in cpairs(t, {name='require'}) do
		for _,t in cpairs(t, {name='command'}) do
			if not cmds[t.attr.name] then
				cmds[#cmds+1] = t.attr.name
				cmds[t.attr.name] = 'defined('..const..')'
			else
				cmds[t.attr.name] = cmds[t.attr.name]
					..' || defined('..const..')'
			end
		end
	end
end

local function out(s) io.write(s..'\n') end

out([[
// WARNING: Generated file. Do not edit manually.

#include <vulkan/vulkan.h>

#ifndef H_vivacious_vulkan
#define H_vivacious_vulkan

typedef struct VvVulkan {
	void* internalData;
	int (*unload)(struct VvVulkan*);
]])

for _,c in ipairs(cmds) do
	local name = string.sub(c,3)
	out([[
#if ]]..cmds[c]..[[ //
	PFN_vk]]..name..[[ ]]..name..[[;
#endif]])
end

out([[
} VvVulkan;

int vVloadVulkan(VvVulkan*, VkBool32 all, VkInstance, VkDevice);

#endif // H_vivacious_vulkan
]])
