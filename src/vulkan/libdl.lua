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

require 'apis.core.generation'

-- Nab the arguments
local specname,outdir = ...
assert(specname == 'vulkan', "This generator only works for Vulkan!")
local f = assert(io.open(outdir..package.config:match'^(.-)\n'..'vulkan.c', 'w'))
local vk = require 'apis.vulkan'
vk.__spec = 'vulkan'

-- Write out the main header
f:write[[
// Generated file, do not edit directly, edit src/vulkan/libdl.lua

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

]]

-- A simple unordered for loop
local function foreach(from, func)
	local todo = {}
	from(todo)
	while next(todo) ~= nil do
		local didit = false
		for k,v in pairs(todo) do
			if func(k,v) then
				didit = true
				todo[k] = nil
			end
		end
		if not didit then
			for k,v in pairs(todo) do print('>', k, v) end
			error "Cannot complete this foreach!"
		end
	end
end

-- Figure out which wrapper goes where using the parent links
local level = {[vk.Vk]='init', [vk.Instance]='instance', [vk.Device]='device'}
local parents = {}
foreach(function(t)
	for _,v in pairs(vk) do
		if v.__index and not v.__raw and not level[v] then t[v] = true end
	end
end, function(t)
	assert(t.__index[2] and t.__index[2].name == 'parent', "No parent for "..tostring(t.__name))
	parents[t] = t.__index[2].type
	if level[parents[t]] then
		level[t] = level[parents[t]]
		return true
	end
end)

-- Write out the PFN structures
for _,ll in ipairs{'init', 'instance', 'device'} do
	f:write('struct '..ll..'_M {\n')
	for t,l in pairs(level) do if l == ll then
		f:write('\tstruct Vv'..t.__name..'_M '..t.__name:lower()..';\n')
	end end
	f:write '};\n'
end
f:write '\n'

-- Map out the commands in terms of owner and aliases
local cmds,allcmds = {},{}
for t in pairs(level) do
	foreach(function(todo)
		for _,e in ipairs(t.__index) do
			if e.aliasof then todo[e] = true elseif e.type.__call then
				cmds[e.name] = {owner=t, ifdef = e.type.__ifdef}
				allcmds[e.name] = cmds[e.name]
				if not e.type.__raw then
					cmds[e.name].here = e.name..(e.name == 'destroy' and t.__name or '')
				end
			end
		end
	end, function(e)
		if allcmds[e.aliasof] then
			table.insert(allcmds[e.aliasof], e.name)
			allcmds[e.name] = allcmds[e.aliasof]
			return true
		end
	end)
end
cmds.destroy = nil

-- Forward declare all the functions we will have here
for t in pairs(level) do
	f:write('static void destroy'..t.__name..'(Vv'..t.__name..'*);\n')
	local p = t.__index[2] and t.__index[2].name == 'parent' and t.__index[2].type.__name
	if p then
		f:write('static Vv'..t.__name..'* wrap'..t.__name..'(Vv'..p..'*, '..t.__name..');\n')
	end
end
f:write '\n'

-- Write out the _I structs and destructors for the three: Vk, Instance and Device
for _,t in ipairs{vk.Vk, vk.Instance, vk.Device} do
	local l,n = level[t], t.__name
	f:write('struct '..l..'_I { Vv'..n..' ext; struct '..l..'_M pfn; ')
	if t == vk.Vk then
		f:write('PFN_vkGetInstanceProcAddr gipa; void* libvk; ')
	end
	f:write('};\n')
	f:write('static void destroy'..n..'(Vv'..n..'* ext) {\n')
	if t == vk.Vk then
		f:write('\t_vVclosedl(((struct init_I*)ext)->libvk);\n')
	end
	f:write('\tfree(ext);\n')
	f:write '}\n\n'
end

-- Write out the destructors and wrappers for the others
for t,l in pairs(level) do if parents[t] then
	local n = t.__name
	local pcnt = 0
	do
		local x = t
		while parents[x] do pcnt, x = pcnt + 1, parents[x] end
	end
	f:write('static void destroy'..n..'(Vv'..n..'* self) {\n')
	f:write '\tfree(self);\n}\n'
	f:write('static Vv'..n..'* wrap'..n..'(Vv'..parents[t].__name..'* par, '..n..' real) {\n')
	f:write('\tVv'..n..'* self = malloc(sizeof(Vv'..n..'));\n')
	f:write('\tself->real = real, self->parent = par;\n')
	f:write('\tstruct '..l..'_I* l = (struct '..l..'_I*)self'..('->parent'):rep(pcnt)..';\n')
	f:write('\tself->_M = &l->pfn.'..n:lower()..';\n')
	f:write '\treturn self;\n}\n\n'
end end

-- Common code...
local function dopfn(thislevel, exp)
	for t,l in pairs(level) do if l == thislevel then
		f:write('self->pfn.'..t.__name:lower()..'.destroy = destroy'..t.__name..';\n')
	end end
	for cn,c in pairs(cmds) do if level[c.owner] == thislevel then
		local ref = 'self->pfn.'..c.owner.__name:lower()..'.'..cn
		if c.here then f:write('\t'..ref..' = '..c.here..';\n') else
			if c.ifdef then
				local parts = {}
				for i,s in ipairs(c.ifdef) do parts[i] = '!defined('..s..')' end
				f:write('#if '..table.concat(parts, ' || ')..'\n')
				f:write('#define PFN_'..cn..' PFN_vkVoidFunction\n')
				for _,n in ipairs(c) do f:write('#define PFN_'..n..' PFN_vkVoidFunction\n') end
				f:write('#endif\n')
			end
			f:write('\t'..ref..' = (PFN_'..cn..')'..exp:gsub('`', cn)..';\n')
			for _,n in ipairs(c) do
				f:write('\tif(!'..ref..')\n')
				f:write('\t\t'..ref..' = (PFN_'..n..')'..exp:gsub('`', n)..';\n')
			end
		end
	end end
end

-- Write out the wrappers and create for the three, starting with Device
f:write [[
static VvVkDevice* wrapVkDevice(VvVkPhysicalDevice* par, VkDevice real) {
	struct device_I* self = malloc(sizeof(struct device_I));
	self->ext.real = real, self->ext.parent = par, self->ext._M = &self->pfn.vkdevice;
	self->pfn.vkdevice.vkGetDeviceProcAddr = (PFN_vkGetDeviceProcAddr)
		vVvkGetInstanceProcAddr(par->parent, "vkGetDeviceProcAddr");
]]
dopfn('device', 'vVvkGetDeviceProcAddr(&self->ext, "`")')
f:write [[
	return &self->ext;
}

static VvVkInstance* wrapVkInstance(VvVk* par, VkInstance real) {
	struct instance_I* self = malloc(sizeof(struct instance_I));
	self->ext.real = real, self->ext.parent = par, self->ext._M = &self->pfn.vkinstance;
	self->pfn.vkinstance.vkGetInstanceProcAddr = ((struct init_I*)par)->gipa;
]]
dopfn('instance', 'vVvkGetInstanceProcAddr(&self->ext, "`")')
f:write [[
	return &self->ext;
}

static const char* ERR_OPEN = "Could not open vulkan loader!";
static const char* ERR_GIPA = "Loader library does not have vkGetInstanceProcAddr!";
VvAPI VvVk* libVv_createVk_libdl(const char** err) {
	struct init_I* self = malloc(sizeof(struct init_I));
	self->libvk = _vVopendl("vulkan.so", "vulkan.dynlib", "vulkan-1.dll");
	if(!self->libvk) { *err = ERR_OPEN; return NULL; }
	self->gipa = _vVsymdl(self->libvk, "vkGetInstanceProcAddr");
	self->ext._M = &self->pfn.vk;
]]
dopfn('init', 'self->gipa(NULL, "`")')
f:write [[
	return &self->ext;
}
]]

