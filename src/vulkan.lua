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
	local id = 'vk'..string.gsub(t.attr.number, '%.', '_')
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
	if not id then
		for const,id in pairs(ids) do
			rep(cat, f, fall, id, const)
		end
		return
	end

	if fall == nil then fall = f end
	out('#ifdef '..const)
	for _,c in ipairs(cmdids[id]) do
		if cmdcats[c] == cat then
			local n = string.sub(c,3)
			out([[
		vk->]]..id..[[.]]..n..[[ = ]]..
			string.gsub(f, '`', n)..[[;]])
		end
	end
	if fall then
		out('\t\tif(all) {')
		for _,c in ipairs(cmdids[id]) do
			if cmdcats[c] > cat then
				local n = string.sub(c,3)
				out([[
				vk->]]..id..[[.]]..n..[[ = ]]..
					string.gsub(fall, '`', n)..[[;]])
			end
		end
		out('\t\t}')
	else
		for _,c in ipairs(cmdids[id]) do
			if cmdcats[c] > cat then
				local n = string.sub(c,3)
				out([[
			vk->]]..id..[[.]]..n..[[ = NULL;]])
			end
		end
	end
	out('#endif')
end

out([[
// WARNING: Generated file. Do not edit manually.

#ifdef Vv_ENABLE_VULKAN

#include "vivacious/vulkan.h"

#include "internal.h"
#include "cpdl.h"
#include <stdlib.h>
#include <string.h>

typedef struct {
	void* libvk;
	PFN_vkGetInstanceProcAddr gipa;]])
for _,t in cpairs(dom.root, {name='feature'}) do
	local ver = string.gsub(t.attr.number, '%.', '_')
	fout([[
#ifdef `const`
	VvVulkan_`ver` vk`ver`;
#endif]], {ver=ver, const=t.attr.name})
end
for _,t in cpairs(first(dom.root, {name='extensions'}), {name='extension',
	attr={supported='vulkan'}}) do
	local name = string.match(t.attr.name, 'VK_(.*)')
	fout([[
#ifdef `const`
	VvVulkan_`name` `name`;
#endif]], {name=name, const=t.attr.name})
end
out([[
} VvVulkanReal;

static VvState create() {
	void* libvk = _vVopendl("libvulkan.so", "libvulkan.dynlib",
		"vulkan-1.dll");
	if(!libvk) return NULL;

	PFN_vkGetInstanceProcAddr gipa = _vVsymdl(libvk,
		"vkGetInstanceProcAddr");
	if(!gipa) {
		_vVclosedl(libvk);
		return NULL;
	}

	VvVulkanReal* vk = malloc(sizeof(VvVulkanReal));
	vk->libvk = libvk;
	vk->gipa = gipa;
]])
rep(0, '(PFN_vk`)gipa(NULL, "vk`")', false)
out([[

	return (VvState) vk;
}

static void cleanup(VvState fig) {
	VvVulkanReal* vk = (VvVulkanReal*)fig;
	_vVclosedl(vk->libvk);
	free(vk);
}

static VvState clone(VvState stat) {
	VvVulkanReal* src = (VvVulkanReal*)stat;
	VvVulkanReal* dest = malloc(sizeof(VvVulkanReal));
	memcpy(dest, src, sizeof(VvVulkanReal));
	dest->libvk = _vVopendl("libvulkan.so", "libvulkan.dynlib",
		"vulkan-1.dll");
	return (VvState)dest;
}

static void LoadInstance(VvState fig, VkInstance inst,
	VkBool32 all) {
	VvVulkanReal* vk = (VvVulkanReal*)fig;
]])
rep(1, '(PFN_vk`)vk->gipa(inst, "vk`")')
out([[
}

static void LoadDevice(VvState fig, VkDevice dev,
	VkBool32 all) {
	VvVulkanReal* vk = (VvVulkanReal*)fig;
]])
rep(2, '(PFN_vk`)vk->vk1_0.GetDeviceProcAddr(dev, "vk`")')
out([[
}

static const void* getNull(const VvState dummy) {
	return NULL;
}
]])

for const,id in pairs(ids) do
	local n = id
	if string.sub(n,1,2) == 'vk' then
		n = string.sub(n, 3)
	end
	fout([[
#ifdef `const`
static const VvVulkan_`n`* getVulkan_`n`(const VvState vkh) {
	return &((VvVulkanReal*)vkh)->`id`;
}
#else
#define getVulkan_`n` getNull
#endif
]], {n=n, id=id, const=const})
end

out([[
static const VvVulkanCore vkcore = {]])
for _,const in ipairs(coreord) do
	local n = ids[const]
	if string.sub(n,1,2) == 'vk' then
		n = string.sub(n, 3)
		out('\tgetVulkan_'..n..',')
	end
end
out([[
};
]])

out([[
static const VvVulkanExt vkext = {]])
for _,const in ipairs(extord) do
	local n = ids[const]
	if string.sub(n,1,2) ~= 'vk' then
		out('\tgetVulkan_'..n..',')
	end
end
out([[
};
]])

out([[
static const VvVulkanAPI api = {
	cleanup,
	LoadInstance, LoadDevice,
	&vkcore, &vkext,
	clone,
};

VvAPI const VvVulkanAPI* _vVloadVulkan_dl(int ver, VvState* fig) {
	*fig = create();
	if(!*fig) return NULL;
	return ver == H_vivacious_vulkan ? &api : NULL;
}
]])

out('#endif // vV_ENABLE_VULKAN')
