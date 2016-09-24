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

local cmds = {}
for _,t in cpairs(dom.root, {name='feature'}) do
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

local cmdcats = {
	vkGetInstanceProcAddr=-1,	-- Pre-Instance
	vkGetDeviceProcAddr=1,
}
for c,t in pairs(cmdtypes) do
	while t ~= 'VkInstance' and t ~= 'VkDevice' and t do
		t = typepars[t]
	end
	cmdcats[c] = cmdcats[c] or
		(t == 'VkInstance' and 1 or
		(t == 'VkDevice' and 2 or 0))
end

local function out(s) io.write(s..'\n') end

local function rep(cat, f, fall)
	fall = fall or f
	for _,c in ipairs(cmds) do
		if cmdcats[c] == cat then
			local n = string.sub(c,3)
			out([[
		#if ]]..cmds[c]..[[ //
		vk->]]..n..[[ = ]]..f(n)..[[;
		#endif]])
		end
	end
	out('\t\tif(all) {')
	for _,c in ipairs(cmds) do
		if cmdcats[c] > cat then
			local n = string.sub(c,3)
			out([[
			#if ]]..cmds[c]..[[ //
			vk->]]..n..[[ = ]]..fall(n)..[[;
			#endif]])
		end
	end
	out('\t\t}')
end

out([[
// WARNING: Generated file. Do not edit manually.

#ifdef Vv_ENABLE_VULKAN

#define VK_NO_PROTOTYPES
#include "vivacious/vulkan.h"

#include "cpdl.h"

VvVulkanError vVloadVulkan(VvVulkan* vk, VkBool32 all, VkInstance inst,
	VkDevice dev) {

	if(!(inst || dev)) {
		vk->internalData = NULL;
		void* libvk = cpdlopen("libvulkan.so", "libvulkan.dynlib",
			"vulkan-1.dll");
		if(!libvk) return VvVK_ERROR_DL;
		vk->GetInstanceProcAddr = cpdlsym(libvk,
			"vkGetInstanceProcAddr");
		if(!vk->GetInstanceProcAddr) return VvVK_ERROR_DL;
		vk->internalData = libvk;
]])
rep(0, function(n)
	return '(PFN_vk'..n..')vk->GetInstanceProcAddr(NULL, "vk'..n..'")' end,
	function(n) return 'cpdlsym(libvk, "vk'..n..'")' end)
out([[
	} else if(inst && !dev) {]])
rep(1, function(n)
	return '(PFN_vk'..n..')vk->GetInstanceProcAddr(inst, "vk'..n..'")' end)
out([[
	} else if(inst && dev) {]])
rep(2, function(n)
	return '(PFN_vk'..n..')vk->GetDeviceProcAddr(dev, "vk'..n..'")' end)
out([[
	} else return VvVK_ERROR_INVALID;
	return VvVK_ERROR_NONE;
}

VvVulkanError vVunloadVulkan(VvVulkan* vk) {
	if(vk->internalData) cpdlclose(vk->internalData);
	return VvVK_ERROR_NONE;
}

#endif // vV_ENABLE_VULKAN
]])
