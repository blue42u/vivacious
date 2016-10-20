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
#define H_vivacious_vulkan
]])

for _,t in cpairs(dom.root, {name='feature',attr={api='vulkan'}}) do
	local const = t.attr.name
	local maj,min = string.match(t.attr.number, '(%d+)%.(%d+)')
	local ver = maj..'_'..min

	fout([[
#ifdef `const`
_Vv_STRUCT(VvVk_`ver`) {]], {const=const, ver=ver})

	for _,r in cpairs(t, {name='require'}) do
		for _,c in cpairs(r, {name='command'}) do
			local cmd = string.match(c.attr.name, 'vk(%w+)')
			if not cmd then
				herror('No command name: '..c.attr.name) end
			fout('\tPFN_vk`cmd` `cmd`;', {cmd=cmd})
		end
	end

	fout([[
};
#endif // `const`
]], {const=const, ver=ver})
end

for _,t in cpairs(first(dom.root, {name='extensions'}), {name='extension',
	attr={supported='vulkan'}}) do
	local const = t.attr.name
	local name = string.match(const, 'VK_(.*)')

	fout([[
#ifdef `const`
_Vv_STRUCT(VvVk_`name`) {]], {const=const, name=name})

	for _,r in cpairs(t, {name='require'}) do
		for _,c in cpairs(r, {name='command'}) do
			local cmd = string.match(c.attr.name, 'vk(%w+)')
			if not cmd then
				herror('No command name: '..c.attr.name) end
			fout('\tPFN_vk`cmd` `cmd`;', {cmd=cmd})
		end
	end

	fout([[
};
#endif // `const`
]], {const=const, name=name})
end

out([[
// A VulkanBinding is the opaque container for all the supported Vulkan
// commands. The getters for this return references into its internal
// structure, so updating the binding should update the references.
_Vv_TYPEDEF(VvVk_Binding);

_Vv_STRUCT(VvVk_Core) {]])
local pieces = {}
for _,t in cpairs(dom.root, {name='feature',attr={api='vulkan'}}) do
	local const = t.attr.name
	local maj,min = string.match(t.attr.number, '(%d+)%.(%d+)')
	local ver = maj..'_'..min
	table.insert(pieces, {ver, string.gsub([[
#ifdef `const`
	const VvVk_`ver`* (*vk_`ver`)(const VvVk_Binding*);
#else
	const void* (*vk_`ver`)(const VvVk_Binding*);
#endif
]], '`(%w*)`', {const=const, ver=ver})})
end
table.sort(pieces, function(a,b) return a[1] < b[1] end)
for i,v in ipairs(pieces) do pieces[i] = v[2] end
out(table.concat(pieces)..[[
};
]])

out([[
_Vv_STRUCT(VvVk_Ext) {]])
local pieces = {}
for _,t in cpairs(first(dom.root, {name='extensions'}), {name='extension'}) do
	local const = t.attr.name
	local name = string.match(const, 'VK_(.*)')
	if t.attr.supported == 'disabled' then
		table.insert(pieces, {tonumber(t.attr.number), string.gsub([[
	const void* (*`name`)(const VvVk_Binding*);
]], '`(%w*)`', {const=const, name=name, numb=t.attr.number})})
	else
		table.insert(pieces, {tonumber(t.attr.number), string.gsub([[
#ifdef `const`	// `numb`
	const VvVk_`name`* (*`name`)(const VvVk_Binding*);
#else
	const void* (*`name`)(const VvVk_Binding*);
#endif
]], '`(%w*)`', {const=const, name=name, numb=t.attr.number})})
	end
end
table.sort(pieces, function(a,b) return a[1] < b[1] end)
for i,v in ipairs(pieces) do pieces[i] = v[2] end
out(table.concat(pieces)..[[
};

_Vv_STRUCT(Vv_Vulkan) {
	// Create a new VulkanBinding.
	VvVk_Binding* (*Create)();

	// Destroy a VulkanBinding.
	void (*Destroy)(VvVk_Binding*);

	// Load the commands which directly require an instance before use.
	// If <all> is true, this will also load those which indirectly require
	// an instance. After this, all command use is limited to <inst>.
	void (*LoadInstance)(VvVk_Binding*, VkInstance inst, VkBool32 all);

	// Load the commands which directly require a device before use.
	// If <all> is true, this will also load those which indirectly require
	// a device. After this, all command use is limited to <dev>.
	void (*LoadDevice)(VvVk_Binding*, VkDevice dev, VkBool32 all);

	// This has the versioned getters for the core Vulkan PFNs.
	const VvVk_Core* core;

	// This has the getters for the extension Vulkan PFNs.
	const VvVk_Ext* ext;
};
const Vv_Vulkan* vVvk_lib();

#endif // H_vivacious_vulkan
]])
