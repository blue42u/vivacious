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

local function out(s) io.write(s..'\n') end
local function fout(s, ...)
	local repl = {}
	for _,t in ipairs(table.pack(...)) do
		for k,v in pairs(t) do
			repl[k] = v
		end
	end
	s = string.gsub(s, '`(%w*)`', repl)
	out(s)
end

out([[
// WARNING: Generated file. Do not edit manually.

#define VK_NO_PROTOTYPES
#include <vulkan/vulkan.h>

#ifndef H_vivacious_vulkan
#define H_vivacious_vulkan 1	// Acts as the "major" version of this header

typedef void* VvVulkan;

typedef struct VvVulkanAPI {
	// Create the opaque structure responsible for obtaining the pieces of
	// Vulkan. PFNs will be available after the first call to Refresh with
	// a non-NULL <inst>.
	VvVulkan (*Create)();

	// Destroy the structure. Do not use the PFNs obtained from <vk> after
	// calling this.
	void (*Destroy)(VvVulkan vk);

	// Load the PFNs which directly require an instance before use. If
	// <all> is true, this will also load those which indirectly require
	// an instance. After this, all PFNs are limited to <inst>.
	void (*LoadInstance)(VvVulkan vk, VkInstance inst, VkBool32 all);

	// Load the PFNs which directly require a device before use. If
	// <all> is true, this will also load those which indirectly require
	// a device. After this, all PFNs are limited to <dev>.
	void (*LoadDevice)(VvVulkan vk, VkDevice dev, VkBool32 all);
} VvVulkanAPI;

const VvVulkanAPI* _vVloadVulkan(int version);
#define vVloadVulkan() _vVloadVulkan(H_vivacious_vulkan)
]])

for _,t in cpairs(dom.root, {name='feature',attr={api='vulkan'}}) do
	local const = t.attr.name
	local maj,min = string.match(t.attr.number, '(%d+)%.(%d+)')
	local ver = maj..'_'..min

	fout([[
#ifdef `const`
typedef struct VvVulkan_`ver` {]], {const=const, ver=ver})

	for _,r in cpairs(t, {name='require'}) do
		for _,c in cpairs(r, {name='command'}) do
			local cmd = string.match(c.attr.name, 'vk(%w+)')
			if not cmd then
				herror('No command name: '..c.attr.name) end
			fout('\tPFN_vk`cmd` `cmd`;', {cmd=cmd})
		end
	end

	fout([[
} VvVulkan_`ver`;
const VvVulkan_`ver`* vVgetVulkan_`ver`(const VvVulkan);
#endif // `const`
]], {const=const, ver=ver})
end

for _,t in cpairs(first(dom.root, {name='extensions'}), {name='extension',
	attr={supported='vulkan'}}) do
	local const = t.attr.name
	local name = string.match(const, 'VK_(.*)')

	fout([[
#ifdef `const`
typedef struct VvVulkan_`name` {]], {const=const, name=name})

	for _,r in cpairs(t, {name='require'}) do
		for _,c in cpairs(r, {name='command'}) do
			local cmd = string.match(c.attr.name, 'vk(%w+)')
			if not cmd then
				herror('No command name: '..c.attr.name) end
			fout('\tPFN_vk`cmd` `cmd`;', {cmd=cmd})
		end
	end

	fout([[
} VvVulkan_`name`;
const VvVulkan_`name`* vVgetVulkan_`name`(const VvVulkan);
#endif // `const`
]], {const=const, name=name})
end

out([[
#endif // H_vivacious_vulkan
]])
