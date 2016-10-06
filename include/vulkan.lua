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
#include <vivacious/core.h>

#ifndef H_vivacious_vulkan
#define H_vivacious_vulkan 2	// Acts as the "major" version of this header

typedef struct VvVulkanCore VvVulkanCore;
typedef struct VvVulkanExt VvVulkanExt;
typedef struct VvVulkanAPI {
	// Cleanup the Config
	void (*cleanup)(VvConfig);

	// Load the PFNs which directly require an instance before use. If
	// <all> is true, this will also load those which indirectly require
	// an instance. After this, all PFNs are limited to <inst>.
	void (*LoadInstance)(VvConfig, VkInstance inst, VkBool32 all);

	// Load the PFNs which directly require a device before use. If
	// <all> is true, this will also load those which indirectly require
	// a device. After this, all PFNs are limited to <dev>.
	void (*LoadDevice)(VvConfig, VkDevice dev, VkBool32 all);

	// This has the versioned getters for the core Vulkan PFNs.
	const VvVulkanCore* core;

	// This has the getters for the extension Vulkan PFNs.
	const VvVulkanExt* ext;
} VvVulkanAPI;

const VvVulkanAPI* _vVloadVulkan_dl(int version, VvConfig*);
#define vVloadVulkan_dl(C) _vVloadVulkan_dl(H_vivacious_vulkan, (C))
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
#endif // `const`
]], {const=const, name=name})
end

out([[
struct VvVulkanCore {]])
local pieces = {}
for _,t in cpairs(dom.root, {name='feature',attr={api='vulkan'}}) do
	local const = t.attr.name
	local maj,min = string.match(t.attr.number, '(%d+)%.(%d+)')
	local ver = maj..'_'..min
	table.insert(pieces, {ver, string.gsub([[
#ifdef `const`
	const VvVulkan_`ver`* (*vk_`ver`)(VvConfig);
#else
	const void* (*vk_`ver`)(VvConfig);
#endif
]], '`(%w*)`', {const=const, ver=ver})})
end
table.sort(pieces, function(a,b) return a[1] < b[1] end)
for i,v in ipairs(pieces) do pieces[i] = v[2] end
out(table.concat(pieces)..[[
};
]])

out([[
struct VvVulkanExt {]])
local pieces = {}
for _,t in cpairs(first(dom.root, {name='extensions'}), {name='extension'}) do
	local const = t.attr.name
	local name = string.match(const, 'VK_(.*)')
	if t.attr.supported == 'disabled' then
		table.insert(pieces, {tonumber(t.attr.number), string.gsub([[
	const void* (*`name`)(VvConfig);
]], '`(%w*)`', {const=const, name=name, numb=t.attr.number})})
	else
		table.insert(pieces, {tonumber(t.attr.number), string.gsub([[
#ifdef `const`	// `numb`
	const VvVulkan_`name`* (*`name`)(VvConfig);
#else
	const void* (*`name`)(VvConfig);
#endif
]], '`(%w*)`', {const=const, name=name, numb=t.attr.number})})
	end
end
table.sort(pieces, function(a,b) return a[1] < b[1] end)
for i,v in ipairs(pieces) do pieces[i] = v[2] end
out(table.concat(pieces)..[[
};

#endif // H_vivacious_vulkan
]])
