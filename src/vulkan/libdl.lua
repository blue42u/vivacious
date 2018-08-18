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

local g = gen.rules(require 'apis.core.headerc')

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

#include "vivacious/vulkan.h"

#include "internal.h"
#include "cpdl.h"
#include <stdlib.h>
]]
	end
end

function g:main()
	if self.specname then return end
	if self.iswrapper then
		local out = gen.collector()
		out(self.I)
		out(self.preM)
		return out
	end
end

function g:footer()
	if self.specname then return end
	if self.iswrapper then
		local out = gen.collector()
		out(self.methods)
		out(self.theM)
		return out
	end
end

function g:iswrapper() return self.__index and not self.__raw end
function g:parent() return self.__index.e.parent and self.__index.e.parent.type or false end
function g:level() return special[self.__name] or self.parent.level end

function g:I()
	local out = gen.collector()
	out('struct Vv',self.__name,'_I {')
	out('\tVv',self.__name,' pub;')
	out('\tstruct ',self.level,'_M* M;')
	out '};'
	return out
end

function g:preM()
	return 'static struct '..self.__name..'_M m_'..self.__name..';'
end

g:addrule('methods', 'theM', function(self)
	local out,mout = gen.collector(), gen.collector()
	mout('static struct ',self.__name,'_M m_',self.__name,' = {')

	-- The destroy method is a little different, we handle it specially
	mout('\t.destroy = ',self.__name,'_destroy,')
	out('static void ',self.__name,'_destroy(',self.ref:gsub('`', 'self'),') {')
	local sn = self.__name:gsub('^Vk', '')
	if self.__index.e['vkFree'..sn] then out('\tvVvkFree',sn,'(self, NULL);')
	elseif self.__index.e['vkDestroy'..sn] then out('\tvVvkDestroy',sn,'(self, NULL);')
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
			local pa = 'self'
			do
				local p = self
				while not special[p.__name] do p,pa = p.parent,pa..'->parent' end
				if p.level == 'device' then
					pa = 'vVvkGetDeviceProcAddr('..pa..', %q)'
				elseif p.level == 'instance' then
					pa = 'vVvkGetInstanceProcAddr('..pa..', %q)'
				elseif p.level == 'init' then
					pa = '_vVsymdl('..pa..', %q)'
				end
			end

			-- Use the ProcAddr to fill the object with its Vulkan methods
			out('\tobj->_M = &m_',rt.__name,';')
			for n,e in pairs(rt.__index) do
				local r
				if n == 'real' then r = 'internal'
				elseif n == 'parent' then r = 'self'
				elseif e.type and e.type.__call and e.type.__raw then
					r = '('..e.type.ref:gsub('`', '')..')'..pa:format(n)
				end
				if r then out('\tobj->',n,' = ',r,';') end
			end

			out '\treturn obj;'
			out '}'
		end
	end
	mout '};'
	return out, mout
end)

return g

--[=[
				-- Fill in the parts of the object
				out('\tobj->_M = ',rt.o.methout,';')
				for nn,ee in pairs(rt.__index) do
					local r
					if nn == 'real' then r = 'internal'
					elseif nn == 'parent' then r = 'self'
					elseif ee.type and ee.type.__call and ee.type.__raw then
						r = '('..ee.type.o.ref:gsub('`','')..')'..pa:format(nn)
					end
					out('\tobj->',nn,' = ',r,';')
				end

				-- Return it, we're done here.
				out '\treturn obj;'
				out:write '}\n'
			end
		end

		-- Write out the full *_M structure we will use.
		out('static const struct ',self.__name,'_M m_',self.__name,' = {')
		out:pop(mout)
		out '};'
		self.o.methout = 'm_'..self.__name

		-- If we're special, we have to write out the master _M structure.
		-- if special[self.__name] then
		--	 out('struct ',special[self.__name],'_M {')
		--	 out('\tstruct ',self.__name,'_M our_M;')
		--	 for n,t in pairs(self) do if not special[t.__name] then
		--		 out('\tstruct ',t.__name,'_M ',n,'_M;')
		--	 end end
		--	 out:write '};\n'
		-- end

		-- We need to write out our _I structure.
		-- out('struct ',self.__name,'_I {')
		-- out('\tVv',self.__name,' public;')
		-- if special[self.__name] then
		--	 out('\tstruct ',special[self.__name],'_M pfn;')
		--	 if special[self.__name] == 'init' then
		--		 out '\tPFN_vkGetInstanceProcAddr gipa;'
		--		 out '\tvoid* libvk;'
		--	 end
		-- end
		-- out '};\n'
		-- self.o.the_I = 'struct '..self.__name..'_I `'

		-- -- As a wrapper, we're in charge of making sure our functions are provided.
		-- for n,e in pairs(self.__index) do
		--	 if e.type and e.type.__call and not e.type.__raw then
		--		 out('static ',e.type.o.pmref:gsub('`', self.__name..'_'..n)
		--			 :gsub('#', self.o.ref:gsub('`', 'self')),';')
		--	 end
		-- end
		-- out:write ''

		-- -- In addition, write out the *_I structure and destructor function.
		-- if not special[self.__name] then
		--	 out('static void ',self.__name,'_destroy(Vv',self.__name,'* self) {')
		--	 out '\tfree(self);'
		--	 out '}'
		-- else
		--	 out('// Here would go the special _I and destructor for '..special[self.__name])
		-- end
		-- out:write ''
	end
end

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
	self->libvk = _vVopendl("libvulkan.so", "libvulkan.dynlib", "vulkan-1.dll");
	if(!self->libvk) {
		free(self);
		*err = "Could not open Vulkan loader!";
		return NULL;
	}
	self->gipa = _vVsymdl(self->libvk, "vkGetInstanceProcAddr");
	if(!self->gipa) {
		_vVclosedl(self->libvk);
		*err = "Loader library does not have vkGetInstanceProcAddr!";
		free(self);
		return NULL;
	}
	self->ext._M = &self->pfn.vk;
]]
dopfn('init', 'self->gipa(NULL, "`")')
f:write [[
	return &self->ext;
}
]]
]=]
