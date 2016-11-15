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

local ids,coreord,extord = {},{},{}
local cmdids = {}
for _,t in cpairs(dom.root, {name='feature'}) do
	local id = 'vk_'..string.gsub(t.attr.number, '%.', '_')
	ids[t.attr.name] = id
	table.insert(coreord, {t.attr.number, t.attr.name})
	cmdids[id] = {}
	for _,t in cpairs(t, {name='require'}) do
		for _,t in cpairs(t, {name='command'}) do
			table.insert(cmdids[id], t.attr.name)
		end
	end
end
for _,t in cpairs(first(dom.root, {name='extensions'}), {name='extension'}) do
	local id = string.match(t.attr.name, 'VK_(.*)')
	ids[t.attr.name] = id
	table.insert(extord, {tonumber(t.attr.number), t.attr.name})
	cmdids[id] = {}
	for _,t in cpairs(t, {name='require'}) do
		for _,t in cpairs(t, {name='command'}) do
			table.insert(cmdids[id], t.attr.name)
		end
	end
end

table.sort(coreord, function(a,b) return a[1] < b[1] end)
for i,v in ipairs(coreord) do coreord[i] = v[2] end
table.sort(extord, function(a,b) return a[1] < b[1] end)
for i,v in ipairs(extord) do extord[i] = v[2] end

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

local function rep(cat, f, fall, id, const)
	local var
	if not id then
		for const,id in pairs(ids) do
			rep(cat, f, fall, id, const)
		end
		return
	elseif string.sub(id, 1,3) == 'vk_' then
		var = 'core->'..id
	else
		var = 'ext->'..id
	end

	if fall == nil then fall = f end
	out('#ifdef '..const)
	for _,c in ipairs(cmdids[id]) do
		if cmdcats[c] == cat then
			local n = string.sub(c,3)
			out([[
		bind->]]..var..[[->]]..n..[[ = ]]..
			string.gsub(f, '`', n)..[[;]])
		end
	end
	if fall then
		out('\t\tif(all) {')
		for _,c in ipairs(cmdids[id]) do
			if cmdcats[c] > cat then
				local n = string.sub(c,3)
				out([[
				bind->]]..var..[[->]]..n..[[ = ]]..
					string.gsub(fall, '`', n)..[[;]])
			end
		end
		out('\t\t}')
	else
		for _,c in ipairs(cmdids[id]) do
			if cmdcats[c] > cat then
				local n = string.sub(c,3)
				out([[
		bind->]]..var..[[->]]..n..[[ = NULL;]])
			end
		end
	end
	out('#endif')
end

out([[
// WARNING: Generated file. Do not edit manually.

#ifdef Vv_ENABLE_VULKAN

#ifdef Vv_ENABLE_X
#define VK_USE_PLATFORM_XLIB_KHR
#define VK_USE_PLATFORM_XCB_KHR
#endif
#ifdef Vv_ENABLE_WAYLAND
#define VK_USE_PLATFORM_WAYLAND_KHR
#endif
#ifdef Vv_ENABLE_MIR
#define VK_USE_PLATFORM_MIR_KHR
#endif
#ifdef Vv_ENABLE_WIN32
#define VK_USE_PLATFORM_WIN32_KHR
#endif

#include "vivacious/vulkan.h"

#include "internal.h"
#include "cpdl.h"
#include <stdlib.h>
#include <string.h>

static void allocate(VvVk_Binding* bind) {
	void* libvk = _vVopendl("libvulkan.so", "libvulkan.dynlib",
		"vulkan-1.dll");
	if(!libvk) return;

	PFN_vkGetInstanceProcAddr gipa = _vVsymdl(libvk,
		"vkGetInstanceProcAddr");
	if(!gipa) {
		_vVclosedl(libvk);
		return;
	}

	bind->internal = libvk;
	bind->core = malloc(sizeof(VvVk_Core));
	bind->ext = malloc(sizeof(VvVk_Ext));
]])
for const,id in pairs(ids) do
	if id:sub(1,3) == 'vk_' then
		fout([[
#ifdef `const`
	bind->core->`id` = malloc(sizeof(`type`));
	bind->core->`id`->GetInstanceProcAddr = gipa;
#else
	bind->core->`id` = NULL;
#endif
]], {const=const, id=id, type='VvVk_'..id:sub(4)})
	else
		fout([[
#ifdef `const`
	bind->ext->`id` = malloc(sizeof(`type`));
#else
	bind->ext->`id` = NULL;
#endif
]], {const=const, id=id, type='VvVk_'..id})
	end
end
rep(0, '(PFN_vk`)gipa(NULL, "vk`")', false)
out([[
}

static void freebind(VvVk_Binding* bind) {]])
for const,id in pairs(ids) do
	fout([[
	free(bind->`section`->`id`);
]], {const=const, id=id, section=(id:sub(1,3) == 'vk_') and 'core' or 'ext'})
end
out([[
	free(bind->core);
	free(bind->ext);
	_vVclosedl(bind->internal);
}

static void loadI(VvVk_Binding* bind, VkInstance inst, VkBool32 all) {
	PFN_vkGetInstanceProcAddr gipa = bind->core->vk_1_0->GetInstanceProcAddr;
]])
rep(1, '(PFN_vk`)gipa(inst, "vk`")')
out([[
}

static void loadD(VvVk_Binding* bind, VkDevice dev, VkBool32 all) {
	PFN_vkGetDeviceProcAddr gdpa = bind->core->vk_1_0->GetDeviceProcAddr;
]])
rep(2, '(PFN_vk`)gdpa(dev, "vk`")')
out([[
}

VvAPI const Vv_Vulkan vVvk_lib = {
	.allocate = allocate,
	.free = freebind,
	.loadInst = loadI,
	.loadDev = loadD,
};
]])

out('#endif // vV_ENABLE_VULKAN')
