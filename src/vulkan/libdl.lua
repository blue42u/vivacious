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
-- luacheck: new globals gen

-- Certain wrappers are more special than others. This marks them by name.
local special = {Vk='init', VkInstance='instance', VkDevice='device'}

local g = gen.rules(require 'include.vivacious.headerc')

function g:header()
	if self.specname then
		return [[
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

#define Vv_IMP_vulkan
#include "vivacious/vulkan.h"

#include "internal.h"
#include "cpdl.h"
#include <stdlib.h>

struct VvVk_I {
	VvVk pub;
	void* libvk;
};
#define VKI(_S) ((struct VvVk_I*)(_S))

]]
	end
end

function g:premain()
	if self.iswrapper then
		return 'static struct Vv'..(self.__name or 'ERR')..'_M m_'..(self.__name or 'ERR')..';'
	end
end
function g:main()
	if self.iswrapper then
		local out = gen.collector()
		out(self.methods)
		out(self.theM)
		return out
	end
end
function g:postmain() if self.__name == 'Vk' then
	local out = gen.collector()
	out [[
VvVk* libVv_createVk_libdl(size_t* len, const char** err) {
	void* libvk = _vVopendl("libvulkan.so", "vulkan-1.dll", "libvulkan.dynlib");
	if(!libvk) return NULL;
	struct VvVk_I* self = malloc(sizeof(struct VvVk_I));
	self->libvk = libvk;
	self->pub._M = &m_Vk;]]
	for n,e in pairs(self.__index) do if e.type.__raw then
		out('\tself->pub.',n,' = (',e.type.__raw.C,')_vVsymdl(libvk, "',n,'");')
	end end
	out [[
	return &self->pub;
}
]]
	return out
end end

function g:iswrapper() return self.__index and not self.__raw and not self.specname end
function g:parent() return self.__index.e.parent and self.__index.e.parent.type or false end
function g:level() return special[self.__name] or self.parent.level end

g:addrule('methods', 'theM', function(self)
	local out,mout = gen.collector(), gen.collector()
	mout('static struct Vv',self.__name,'_M m_',self.__name,' = {')

	-- The destroy method is a little different, we handle it specially
	mout('\t.destroy = ',self.__name,'_destroy,')
	out('static void ',self.__name,'_destroy(',self.ref:gsub('`', 'self'),') {')
	local sn = self.__name:gsub('^Vk', '')
	if self.__index.e['vkFree'..sn] then out('\tvVvkFree',sn,'(self, NULL);')
	elseif self.__index.e['vkDestroy'..sn] then out('\tvVvkDestroy',sn,'(self, NULL);')
	end
	if self.__name == 'Vk' then	-- We have to free the lib too
		out '\t_vVclosedl(VKI(self)->libvk);'
	end
	out '\tfree(self);'
	out '};'

	-- Now we get all the other methods ready.
	for mn,me in pairs(self.__index) do
		if me.type and me.type.__call and not me.type.__raw and mn ~= 'destroy' then
			-- All of these are wrap* methods, so we handle things accordingly.
			mout('\t.',mn,' = ',mn,',')
			out('static ',me.type.pmref:gsub('[`#]', {
				['`']=mn, ['#']=self.ref:gsub('`', 'self')
			}),' {')
			local rt = me.type.__call.e.wrapped.type
			out('\t',rt.ref:gsub('`', 'obj'),';')
			out '\tobj = malloc(sizeof *obj);'

			-- Figure out how many parents it takes to get a ProcAddr
			local function gpa(pa, p)
				while not special[p.__name] do p,pa = p.parent,pa..'->parent' end
				if p.level == 'device' then
					return 'vVvkGetDeviceProcAddr('..pa..', %q)'
				elseif p.level == 'instance' then
					return 'vVvkGetInstanceProcAddr('..pa..', %q)'
				elseif p.level == 'init' then
					return '_vVsymdl(VKI('..pa..')->libvk, %q)'
				end
			end

			-- If the wrapped Type has a ProcAddr, we have to get it first
			local pas = {vkGetInstanceProcAddr=true, vkGetDeviceProcAddr=true}
			local gpa_s = gpa('self', self)
			for n in pairs(pas) do if rt.__index.e[n] then
				local r = '('..rt.__index.e[n].type.ref:gsub('`', '')..')'..gpa_s:format(n)
				out('\tobj->',n,' = ',r,';	// Predone')
			end end

			-- Use the closest ProcAddr to fill the object with its Vulkan methods
			local gpa_r = gpa('obj', rt)
			out('\tobj->_M = &m_',rt.__name,';')
			for n,e in pairs(rt.__index) do if e.type and not pas[n] then
				local r
				if n == 'real' then r = 'internal'
				elseif n == 'parent' then r = 'self'
				elseif e.type and e.type.__call and e.type.__raw then
					r = '('..e.type.ref:gsub('`', '')..')'..gpa_r:format(n)
				end
				if r then out('\tobj->',n,' = ',r,';') end
			end end

			out '\treturn obj;'
			out '}'
		end
	end
	mout '};'
	return out, mout
end)

return g
