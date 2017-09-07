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

local vulk = dofile'../external/vulkan.lua'

io.output(arg[1])
local function out(s, ...) io.write(s:format(...)..'\n') end
local function rout(s) io.write(s..'\n') end

local function setcmds(lvl, patt)
	local test
	if lvl >= 0 then function test(t) return t == lvl end
	else function test(t) return -lvl < t end end
	for n,v in pairs(vulk.cmdsets) do
		local id = n:match'%d+%.%d+' and 'core' or n:match'VK_(.+)'
		local con = n:match'%d+%.%d+'
			and ('VK_VERSION_%d_%d'):format(n:match'(%d+)%.(%d+)')
			or n
		local anyhere = false
		for _,c in ipairs(v) do if test(vulk.cmdlevels[c]) then
			if not anyhere then
				anyhere = true
				out('#ifdef %s', con)
			end
			out('\t\tf = '..patt:gsub('`', c)..';')
			out('\t\tcmdsets.%s->%s = f ? (PFN_vk%s)f : cmdsets.%s->%s;',
				id, c, c, id, c)
		end end
		if anyhere then out('#endif') end
	end
end

out[[
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

struct Internal {
	void* libvk;
	VvVk_Core core;]]
for n in pairs(vulk.cmdsets) do if not n:match'%d+%.%d+' then
	n = n:match'VK_(.+)'
	out([[
#ifdef VK_%s
	VvVk_%s %s;
#endif]], n,n,n)
end end
out[[
};

static VvVk_CmdSets cmdsets;

static void load(const Vv* V) {
	struct Internal* I = malloc(sizeof(struct Internal));
	I->libvk = _vVopendl("libvulkan.so","libvulkan.dynlib","vulkan-1.dll");
	if(!I->libvk) {
		free(I);
		return;
	}

	I->core.GetInstanceProcAddr = _vVsymdl(I->libvk,
		"vkGetInstanceProcAddr");
	if(!I->core.GetInstanceProcAddr) {
		_vVclosedl(I->libvk);
		free(I);
		return;
	}

	cmdsets = VvVk_CmdSets(
		.core = &I->core, .internal = I,]]
for n in pairs(vulk.cmdsets) do if not n:match'%d+%.%d+' then
	n = n:match'VK_(.+)'
	out([[
#ifdef VK_%s
	.%s = &I->%s,
#else
	.%s = NULL,
#endif]], n, n, n, n)
end end
rout[[
	);

	PFN_vkVoidFunction f;
]]
setcmds(0, 'I->core.GetInstanceProcAddr(NULL, "vk`")')
out[[
}

static void loadInst(const Vv* V, VkInstance inst, int all) {
	PFN_vkVoidFunction f;
]]
setcmds(1, 'cmdsets.core->GetInstanceProcAddr(inst, "vk`")')
out'\n\tif(!all) return;\n'
setcmds(-1, 'cmdsets.core->GetInstanceProcAddr(inst, "vk`")')
out[[
}

static void loadDev(const Vv* V, VkDevice dev, int all) {
	PFN_vkVoidFunction f;
]]
setcmds(2, 'cmdsets.core->GetDeviceProcAddr(dev, "vk`")')
out'\n\tif(!all) return;\n'
setcmds(-2, 'cmdsets.core->GetDeviceProcAddr(dev, "vk`")')
rout[[
}

static void unload(const Vv* V) {
	struct Internal* I = cmdsets.internal;
	_vVclosedl(I->libvk);
	free(I);
	cmdsets = VvVk_CmdSets();
}

const VvVk libVv_vk_libdl = {
	.cmds = &cmdsets,
	.load = load, .loadDev = loadDev, .loadInst = loadInst,
	.unload = unload,
};

#endif // Vv_ENABLE_VULKAN]]
