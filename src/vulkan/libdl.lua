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

local G = {_internal={}, bound={custom={}, simple={}}}

function G.bound:environment()
	function self:def(c, e, ds, f)
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
		for _,l in ipairs(c) do f:write(l..'\n\n') end
	end
	self.conv = error
end

function G.bound:reference(n, t, cp, ex)
	local d = n:gsub('.*%.', ''):gsub('%u?%u%u$', ''):lower()
	n = n:gsub('.*%.', '')
	if n ~= ex.prefix then n = ex.prefix..n end
	function self:def(c, e) c[e or d] = (t and '' or 'Vv')..n..' '..e end
	function self:conv(c, e, v) t'conv'(c, e or d, v) end
	return 'Vv'..n
end

G.bound.behavior_arg = {directives=false, wrapperfor=false, prefix=true, consts=false}
local baseparents = { VkInstance='inst', VkDevice='dev' }
local wrappers = {}
function G.bound:behavior(arg)
	function self:def(c, e, es)
		local da = {returns={self}}
		if arg.wrapperfor then
			table.insert(da, {'real', std.bound.raw{realname=arg.wrapperfor}})
		end
		for _,b in ipairs(arg) do table.insert(da, {'parent', b}) end
		da = std._internal.callable(da)

		local ms = newcontext()
		for _,m in ipairs(es) do
			if m[1] == 'm' and not m[2]:match'ProcAddr$' then
				m[3]'conv'(ms, m[2])
			end
		end

		wrappers[self'def'('~')[1]] = arg.wrapperfor
		if arg.wrapperfor and not baseparents[arg.wrapperfor] then
			local k = arg[1]'def'('~')[1]
			assert(wrappers[k], arg.wrapperfor)
			baseparents[arg.wrapperfor] = baseparents[wrappers[k]]
		end

		local funcname = da'def'(
			'vV'..(arg.wrapperfor and 'wrap' or 'create')..e:match'Vv(.+)'
		)[1]
		local ismain = arg.wrapperfor == 'VkInstance'
			or arg.wrapperfor == 'VkDevice'
		if baseparents[arg.wrapperfor] == 'inst' then
			c[e] = 'struct '..e..[[_I {
	struct ]]..e..[[_M* M;
	VvVkInstance inst;
};]]
			c[e..'_d'] = 'static void destroy'..e..'('..self'def'('self')[1]..[[) {
	free(self->_I->M);
	free(self->_I);
	free(self);
}]]
			c[e..'_c'] = funcname..[[ {
	]]..e..[[ self = malloc(sizeof(struct ]]..e..[[));
	self->real = real;
	self->_I = malloc(sizeof(struct ]]..e..[[_I));
	self->_I->M = malloc(sizeof(struct ]]..e..[[_M));
	self->_I->inst = ]]..(ismain and 'self' or 'parent->_I->inst')..[[;
	self->_M = self->_I->M;
	self->_I->M->destroy = destroy]]..e..';\n'
			..(ismain and [[
	self->_I->M->vkGetInstanceProcAddr = (PFN_vkGetInstanceProcAddr)
		_vVsymdl(parent->_I->lib, "vkGetInstanceProcAddr");
]] or '')
			..ms('\n', '\tself->_I->M->`e` = (PFN_`e`)vVvkGetInstanceProcAddr(self->_I->inst, `v`);')
			..'\n\treturn self;\n}'
		elseif baseparents[arg.wrapperfor] == 'dev' then
			c[e] = 'struct '..e..[[_I {
	struct ]]..e..[[_M* M;
	VvVkDevice dev;
};]]
			c[e..'_d'] = 'static void destroy'..e..'('..self'def'('self')[1]..[[) {
	free(self->_I->M);
	free(self->_I);
	free(self);
}]]
			c[e..'_c'] = funcname..[[ {
	]]..e..[[ self = malloc(sizeof(struct ]]..e..[[));
	self->real = real;
	self->_I = malloc(sizeof(struct ]]..e..[[_I));
	self->_I->M = malloc(sizeof(struct ]]..e..[[_M));
	self->_M = self->_I->M;
	self->_I->dev = ]]..(ismain and 'self' or 'parent->_I->dev')..[[;
	self->_I->M->destroy = destroy]]..e..';\n'
			..(ismain and [[
	self->_I->M->vkGetDeviceProcAddr = (PFN_vkGetDeviceProcAddr)
		vVvkGetInstanceProcAddr(parent->_I->inst, "vkGetDeviceProcAddr");
]] or '')
			..ms('\n', '\tself->_I->M->`e` = '
				..'(PFN_`e`)vVvkGetDeviceProcAddr(self->_I->dev, `v`);')
			..'\n\treturn self;\n}'
		else
			c[e] = 'struct '..e..[[_I {
	struct VvVk_M* M;
	void* lib;
};]]
			c[e..'_d'] = 'static void destroy'..e..'('..self'def'('self')[1]..[[) {
	_vVclosedl(self->_I->lib);
	free(self->_I->M);
	free(self->_I);
	free(self);
}]]
			c[e..'_c'] = funcname..[[ {
	VvVk vk = malloc(sizeof(struct VvVk));
	vk->_I = malloc(sizeof(struct ]]..e..[[_I));
	vk->_I->lib = _vVopendl("libvulkan.so", "libvulkan.dynlib", "vulkan-1.dll");
	vk->_I->M = malloc(sizeof(struct VvVk_M));
	vk->_M = vk->_I->M;
	vk->_I->M->destroy = destroy]]..e..[[;
	PFN_vkGetInstanceProcAddr gipa =
		(PFN_vkGetInstanceProcAddr)_vVsymdl(vk->_I->lib, "vkGetInstanceProcAddr");
]]..ms('\n', '\tvk->_I->M->`e` = (PFN_`e`)gipa(NULL, `v`);')..'\n\treturn vk;\n}'
		end
	end
	self.conv = error
	return {prefix = arg.prefix}
end

G.bound.custom.raw_arg = {realname=true, conversion=false}
function G.bound.custom:raw(arg)
	self.def = arg.realname..' `e`'
	self.conv = error
end

function G._internal:callable(arg)
	local rs = arg.returns or {}
	local ret = assert(table.remove(rs, 1))
	function self:def(c, e)
		local args = newcontext()
		for _,a in ipairs(arg) do a[2]'def'(args, a[1], {asarg=true}) end
		for i,r in ipairs(rs) do r'def'(args, '*ret'..i) end
		local rets = ret'def'('~')
		for i=2,#rets do
			local ri = i-1+#rs
			args['*ret'..ri] = rets[i]:gsub('~', '*ret'..ri)
		end
		c[e] = rets[1]:gsub('~', e..'('..args', '..')')
	end
	self.conv = error
end
G.bound.callable_arg = {realname=true}
function G.bound:callable(arg)
	self.def = arg.realname..' `e`'
	function self:conv(c, e) c[e] = '"'..e..'"' end
end

-- Stuff for the bound varient
G.bound.simple.unsigned = {def=error, conv=error}
G.bound.flags_arg = {realname=true}
G.bound.options_arg = {realname=true}
G.bound.custom.flexmask_arg = {true, bits=true, lenvar=true}
G.bound.compound_arg = {realname=true}
G.bound.array_arg = {lenvar=false}

return G
