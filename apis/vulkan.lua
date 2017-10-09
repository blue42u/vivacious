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

local std = require 'standard'
std.define 'VK_NO_PROTOTYPES'
std.include'vulkan/vulkan.h'

local vk = {api=std.precompound{
	shortname = 'Vk',
	longname = 'Vulkan',
	doc = "The binding to the Vulkan API",
}}

-- Load up the Vulkan registry data
local vulk = dofile '../external/vulkan.lua'

local categories = {
	basetype=false,
	include=false, define=false,
	stdtype=true, handle=true, enum=true, bitmask=true,
	funcpointer=false,
	struct=true, union=true,
	struct_sType='ref', union_sType='ref',
}
for n,c in pairs(vulk.types) do if categories[c] then
	vk[n:match'Vk(.*)'] = std.external{n, notdef=true,
		ref = categories[c] == 'ref'}
end end

vk.CmdSets = std.precompound{v0_0_0={internal=std.udata}}
vk.Core = std.precompound{}
local corefuncs = {}
for n,cs in pairs(vulk.cmdsets) do
	if n:match'%d+%.%d+' then
		local sub = vk.Core[('v0_%d_%d'):format(n:match'(%d+)%.(%d+)')]
		for _,c in ipairs(cs) do
			if not corefuncs[c] then
				corefuncs[c] = true
				sub[c] = std.external{'PFN_vk'..c, func=true,
					const=cs.name}
			end
		end
	else
		local e = n:match'VK_(.+)'
		vk[e] = std.precompound{}
		for _,c in ipairs(cs) do
			vk[e].v0_0_0[c] = std.external{'PFN_vk'..c, func=true,
				const=cs.name}
		end
		vk[e] = std.compound(vk[e])
		vk.CmdSets['v0_1_'..cs.num][e] = vk[e]
	end
end
vk.Core = std.compound(vk.Core)
vk.CmdSets.v0_0_0.core = vk.Core
vk.CmdSets = std.compound(vk.CmdSets)
vk.api.v0_1_1.cmds = vk.CmdSets

vk.version = std.external{'uint32_t', 'VK_MAKE_VERSION(%d,%d,%d)',
	function(v) return v:match'(%d+).(%d+).(%d+)' end}
vk.uint32 = std.external{'uint32_t', '%u'}

vk.api.v0_1_1.load = std.func{
	doc = [[
		Load the connection to the Vulkan loader, and set the first few
		loading command. Must be paired with `unload` for a clean run.
	]],
}

vk.api.v0_1_1.unload = std.func{
	doc = [[
		Unload all commands, breaking the connection with the Vukan
		loader. Must come after a call to `load`.
	]],
}

vk.api.v0_1_1.loadInst = std.func{
	doc = [[
		Load all commands which require a Vulkan Instance before use.
		If <all> is true, loads commands that indirectly require an
		Instance. After this call, <inst> is the only usable Instance.
	]],
	{vk.Instance, 'inst'},
	{std.boolean, 'all'},
}

vk.api.v0_1_1.loadDev = std.func{
	doc = [[
		Load all commands which require a Vulkan Device before use.
		If <all> is true, loads commands that indirectly require a Device.
		After this call, <dev> is the only usable Device.
	]],
	{vk.Device, 'dev'},
	{std.boolean, 'all'},
}

vk.api = std.compound(vk.api)
return vk
