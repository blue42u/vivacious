--[========================================================================[
   Copyright 2016-2017 Jonathon Anderson

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
_Vv_TYPEDEF(VvVk_`ver`);
#ifdef `const`
struct VvVk_`ver` {]], {const=const, ver=ver})

	for _,r in cpairs(t, {name='require'}) do
		for _,c in cpairs(r, {name='command'}) do
			local cmd = string.match(c.attr.name, 'vk(%w+)')
			if not cmd then
				herror('No command name: '..c.attr.name) end
			fout([[
	PFN_vk`cmd` `cmd`;
#ifdef Vv_vk_ENABLED
#define vVvk`mm`_`cmd`(...) \
(Vv_CHOICE).vk_binding->core->vk_`ver`->`cmd`(__VA_ARGS__)
#endif
]], {cmd=cmd, ver=ver, mm=maj..min})
		end
	end

	fout([[
};
#endif // `const`
]], {const=const, ver=ver})
end

for _,t in cpairs(first(dom.root, {name='extensions'}), {name='extension'}) do
	local const = t.attr.name
	local name = string.match(const, 'VK_(.*)')

	fout([[
_Vv_TYPEDEF(VvVk_`name`);
#ifdef `const`
struct VvVk_`name` {]], {const=const, name=name})

	for _,r in cpairs(t, {name='require'}) do
		for _,c in cpairs(r, {name='command'}) do
			local cmd = string.match(c.attr.name, 'vk(%w+)')
			if not cmd then
				herror('No command name: '..c.attr.name) end
			fout([[
	PFN_vk`cmd` `cmd`;
#ifdef Vv_vk_ENABLED
#define vVvk_`cmd`(...) \
(Vv_CHOICE).vk_binding->ext->`name`->`cmd`(__VA_ARGS__)
#endif
]], {cmd=cmd,name=name})
		end
	end

	fout([[
};
#endif // `const`
]], {const=const, name=name})
end

out([[
_Vv_STRUCT(VvVk_Core) {]])
local pieces = {}
for _,t in cpairs(dom.root, {name='feature',attr={api='vulkan'}}) do
	local const = t.attr.name
	local maj,min = string.match(t.attr.number, '(%d+)%.(%d+)')
	local ver = maj..'_'..min
	table.insert(pieces, {ver, string.gsub([[
	VvVk_`ver`* vk_`ver`;
#ifdef Vv_vk_ENABLED
#define vVvk`mm` *(Vv_CHOICE).vk_binding->core->vk_`ver`
#endif
]], '`(%w*)`', {const=const, ver=ver, mm=maj..min})})
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
	table.insert(pieces, {tonumber(t.attr.number), string.gsub([[
	VvVk_`name`* `name`;
#ifdef Vv_vk_ENABLED
#define vVvk_`name` *(Vv_CHOICE).vk_binding->ext->`name`
#endif
]], '`(%w*)`', {const=const, name=name, numb=t.attr.number})})
end
table.sort(pieces, function(a,b) return a[1] < b[1] end)
for i,v in ipairs(pieces) do pieces[i] = v[2] end
out(table.concat(pieces)..[[
};

// Just to make things easier, one struct to rule them all.
_Vv_STRUCT(VvVk_Binding) {
	VvVk_Core* core;
	VvVk_Ext* ext;
	void* internal;		// To give the imp somewhere for its stuff
};

_Vv_STRUCT(Vv_Vulkan) {
	// Allocate space for the PFNs in a Binding.
	void (*allocate)(Vv*);
#ifdef Vv_vk_ENABLED
#define vVvk_allocate() vVcore_FUNCNARGS(vk, allocate)
#endif

	// Free the space for the PFNs in a Binding.
	void (*free)(Vv*);
#ifdef Vv_vk_ENABLED
#define vVvk_free() vVcore_FUNCNARGS(vk, free)
#endif

	// Load the commands which directly require an instance before use.
	// If <all> is true, this will also load those which indirectly require
	// an instance. After this, all command use is limited to <inst>.
	void (*loadInst)(const Vv*, VkInstance inst, VkBool32 all);
#ifdef Vv_vk_ENABLED
#define vVvk_loadInst(...) vVcore_FUNC(vk, loadInst, __VA_ARGS__)
#endif

	// Load the commands which directly require a device before use.
	// If <all> is true, this will also load those which indirectly require
	// a device. After this, all command use is limited to <dev>.
	void (*loadDev)(const Vv*, VkDevice dev, VkBool32 all);
#ifdef Vv_vk_ENABLED
#define vVvk_loadDev(...) vVcore_FUNC(vk, loadDev, __VA_ARGS__)
#endif
};
extern const Vv_Vulkan vVvk_Default;

#endif // H_vivacious_vulkan
]])
