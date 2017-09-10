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

local relpath = '../external/'

local oldpath = package.path
package.path = package.path .. ';' .. relpath .. '?.lua'

local trav = require 'traversal'
local cpairs, first = trav.cpairs, trav.first

local xml = io.open(relpath .. 'vulkan-docs/src/spec/vk.xml', 'r'):read('a')
local dom = require('slaxdom'):dom(xml, {stripWhitespace=true})

package.path = oldpath

local vulkan = {dom=dom}

vulkan.types = {}
for _,t in cpairs(dom.root, {name='types'}) do
	for _,t in cpairs(t, {name='type'}) do
		local c = t.attr.category
		if (c == 'struct' or c == 'union')
			and first(t,{name='member'},{name='name'})
				.kids[1].value == 'sType' then
			c = c..'_sType'
		end

		vulkan.types[t.attr.name
			or first(t,{name='name'}).kids[1].value] = c
	end
end

vulkan.cmdsets = {}
for _,t in cpairs(dom.root, {name='feature',attr={api='vulkan'}}) do
	local v = {}
	for _,r in cpairs(t, {name='require'}) do
		for _,c in cpairs(r, {name='command'}) do
			v[#v+1] = c.attr.name:match'vk(.+)'
		end
	end
	v.name,v.num = t.attr.name, t.attr.number
	vulkan.cmdsets[t.attr.number] = v
end
for _,t in cpairs(dom.root, {name='extensions'}) do
	for _,t in cpairs(t, {name='extension'}) do
		local v = {}
		for _,r in cpairs(t, {name='require'}) do
			for _,c in cpairs(r, {name='command'}) do
				v[#v+1] = c.attr.name:match'vk(.+)'
			end
		end
		v.name,v.num = t.attr.name, t.attr.number
		vulkan.cmdsets[t.attr.name] = v
	end
end

local types = {}
for _,t in cpairs(dom.root, {name='types'}) do
	for _,t in cpairs(t, {name='type'}) do
		types[t.attr.name or first(t,{name='name'}).kids[1].value] = t
	end
end

vulkan.cmdlevels = {VkInstance=1, VkDevice=2}
for _,cs in cpairs(dom.root, {name='commands'}) do
	for _,c in cpairs(cs, {name='command'}) do
		local n = first(c,{name='proto'},{name='name'}).kids[1].value
		local t = first(c,{name='param'},{name='type'}).kids[1].value
		while not vulkan.cmdlevels[t] and types[t]
			and types[t].attr.parent do
			t = types[t].attr.parent
		end
		vulkan.cmdlevels[n:match'vk(.+)'] = vulkan.cmdlevels[t] or 0
	end
end
for c in pairs(vulkan.cmdlevels) do
	if c:match'^Vk' then vulkan.cmdlevels[c] = nil end
end
vulkan.cmdlevels.GetInstanceProcAddr = 0	-- Can work without an Instance
vulkan.cmdlevels.GetDeviceProcAddr = 1		-- Can be obtained w/out Device

return vulkan
