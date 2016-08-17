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
// WARNING: Generated file. Do not edit manually.

#ifdef Vv_ENABLE_VULKAN

#define VK_NO_PROTOTYPES
#include "vivacious/vulkan.h"

#if defined(_WIN32)
#	include <windows.h>
#else
#	include <dlfcn.h>
#endif
]])

for _,t in cpairs(dom.root, {name='feature',attr={api='vulkan'}}) do
	local const = t.attr.name
	local ver = string.gsub(t.attr.number, '%.', '_')
	local major = string.match(t.attr.number, '(%d+)%.')

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
static void optimizeInstance_]]..ver..[[(VkInstance, VvVulkan_]]..ver..[[*);
static void optimizeDevice_]]..ver..[[(VkDevice, VvVulkan_]]..ver..[[*);

int vVloadVulkan_]]..ver..[[(VvVulkan_]]..ver..[[* vk) {
	vk->vVoptimizeInstance = &optimizeInstance_]]..ver..[[;
	vk->vVoptimizeDevice = &optimizeDevice_]]..ver..[[;

#if defined(_WIN32)
	HMODULE libvk = LoadLibrary("vulkan-]]..major..[[.dll");
#elseif defined(__APPLE__)
	void* libvk = dlopen("libvulkan.dylib.]]..major..[[",
		RTLD_NOW | RTLD_GLOBAL);
#else
	void* libvk = dlopen("libvulkan.so.]]..major..[[",
		RTLD_NOW | RTLD_GLOBAL);
#endif
	if(!libvk) return 0;
	int ret = 1;
]])
	for _,cmd in ipairs(allcmds) do
		out([[
#if defined(_WIN32)
	vk->]]..cmdnames[cmd]..[[ = GetProcAddress(libvk, "]]..cmd..[[");
#else
	vk->]]..cmdnames[cmd]..[[ = dlsym(libvk, "]]..cmd..[[");
#endif
	if(!vk->]]..cmdnames[cmd]..[[) ret = 0;
]])
	end
	out([[
	return ret;
}

static void optimizeInstance_]]..ver..[[(VkInstance i,
	VvVulkan_]]..ver..[[* vk) {
]])
	for _,cmd in ipairs(allcmds) do
		if cmdcats[cmd] == 'instance' then
			out('\tvk->'..cmdnames[cmd]..' = (PFN_'..cmd..
				')vk->GetInstanceProcAddr(i, "'..cmd..'");')
		end
	end
	out([[
}

static void optimizeDevice_]]..ver..[[(VkDevice d,
	VvVulkan_]]..ver..[[* vk) {
]])
	for _,cmd in ipairs(allcmds) do
		if cmdcats[cmd] == 'device' then
			out('\tvk->'..cmdnames[cmd]..' = (PFN_'..cmd..
				')vk->GetDeviceProcAddr(d, "'..cmd..'");')
		end
	end
	out([[
}
#endif
]])
end

for _,t in cpairs(first(dom.root, {name='extensions'}), {name='extension',
	attr={supported='vulkan'}}) do
	local const = t.attr.name
	local n = string.sub(const, string.find(const, '_', 4)+1)

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

	if #allcmds > 0 then
		out([[
#if defined(]]..const..[[)
void vVloadVulkanEXT_]]..n..[[(
	PFN_vkGetInstanceProcAddr gipa, VkInstance i,
	PFN_vkGetDeviceProcAddr gdpa, VkDevice d,
	VvVulkanEXT_]]..n..[[* vk) {
]])
		for _,cmd in ipairs(allcmds) do
			if cmdcats[cmd] == 'instance' then
				out('\tvk->'..cmdnames[cmd]..' = (PFN_'..cmd..
					')gipa(i, "'..cmd..'");')
			end
		end
		for _,cmd in ipairs(allcmds) do
			if cmdcats[cmd] == 'device' then
				out('\tvk->'..cmdnames[cmd]..' = (PFN_'..cmd..
					')gdpa(d, "'..cmd..'");')
			end
		end
		out([[
}
#endif
]])
	end
end

out([[
#endif // vV_ENABLE_VULKAN
]])