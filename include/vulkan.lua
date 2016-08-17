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
// WARNING: Generated file. Do not edit manually.

#include <vulkan/vulkan.h>

#ifndef H_vivacious_vulkan
#define H_vivacious_vulkan
]])

for _,t in cpairs(dom.root, {name='feature',attr={api='vulkan'}}) do
	local const = t.attr.name
	local ver = string.gsub(t.attr.number, '%.', '_')
	out([[
#if defined(]]..const..[[)
typedef struct _VvVulkan_]]..ver..[[ VvVulkan_]]..ver..[[;
struct _VvVulkan_]]..ver..[[ {
	void (*vVoptimizeInstance)(VkInstance, VvVulkan_]]..ver..[[*);
	void (*vVoptimizeDevice)(VkDevice, VvVulkan_]]..ver..[[*);
]])
	for _,t in cpairs(t, {name='require'}) do
		for _,t in cpairs(t, {name='command'}) do
			local name = t.attr.name
			if string.sub(name, 1, 2) == 'vk' then
				name = string.sub(name, 3)
			end
			out('\tPFN_vk'..name..' '..name..';')
		end
	end
	out([[
};
int vVloadVulkan_]]..ver..[[(VvVulkan_]]..ver..[[*);
#endif
]])
end

for _,t in cpairs(first(dom.root, {name='extensions'}), {name='extension',
	attr={supported='vulkan'}}) do
	local const = t.attr.name
	local name = string.sub(const, string.find(const, '_', 4)+1)

	local validext = false
	for _,t in cpairs(t, {name='require'}) do
		if first(t, {name='command'}) then
			validext = true
			break
		end
	end
	if validext then

		out([[
#if defined(]]..const..[[)
typedef struct _VvVulkanEXT_]]..name..[[ VvVulkanEXT_]]..name..[[;
struct _VvVulkanEXT_]]..name..[[ {
]])
		for _,t in cpairs(t, {name='require'}) do
			for _,t in cpairs(t, {name='command'}) do
				local name = t.attr.name
				if string.sub(name, 1, 2) == 'vk' then
					name = string.sub(name, 3)
				end
				out('\tPFN_vk'..name..' '..name..';')
			end
		end
		out([[
};
void vVloadVulkanEXT_]]..name..[[(
	PFN_vkGetInstanceProcAddr, VkInstance,
	PFN_vkGetDeviceProcAddr, VkDevice,
	VvVulkanEXT_]]..name..[[*);
#endif
]])
	end
end

out([[
#endif // H_vivacious_vulkan
]])
