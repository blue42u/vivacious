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

local relpath = 'external/'

local oldpath = package.path
package.path = package.path .. ';' .. relpath .. '?.lua'

local trav = require 'traversal'
local cpairs, first = trav.cpairs, trav.first

local xml = io.open(relpath .. 'vulkan-docs/src/spec/vk.xml', 'r'):read('a')
local dom = require('slaxdom'):dom(xml, {stripWhitespace=true})

package.path = oldpath

local vk = {}
local bitmasked = {}

vk.vids = {}
for _,t in cpairs(dom.root, {name='tags'}) do
	for _,t in cpairs(t, {name='tag'}) do
		vk.vids[t.attr.name] = true
	end
end

vk.types = {}
for _,t in cpairs(dom.root, {name='types'}) do
	for _,t in cpairs(t, {name='type'}) do
		local o = {}
		for k,v in pairs(t.attr) do o[k] = v end
		if not o.type then
			local t = first(t, {name='type'}, {type='text'})
			if t then o.type = t.value end
		end
		if not o.name then
			local t = first(t, {name='name'}, {type='text'})
			if t then o.name = t.value end
		end

		if o.category == 'enum' or o.category == 'bitmask' then
			local nam = o.category == 'enum' and o.name or o.requires

			if o.category == 'bitmask' then bitmasked[nam or 1] = true
			elseif bitmasked[nam] then goto cont end

			o.values, o.exts = {},{}
			local hard = {
				['~0U'] = 2^32-1, ['~0ULL'] = 2^64-1, ['~0U-1'] = 2^32-2,
			}

			if nam then
				local t = first(dom.root, {name='enums', attr={name=nam, type=o.category}})
				if t then
					for _,e in cpairs(t, {name='enum'}) do
						local v = e.attr.value and e.attr.value:gsub('[f()]', '')
						if hard[v] then v = hard[v] end
						v = tonumber(v) or 1<<e.attr.bitpos

						o.values[e.attr.name] = v
					end
				end
				for _,ex in cpairs(dom.root, {name='extensions'}) do
					for _,ex in cpairs(ex, {name='extension'}) do
						for _,r in cpairs(ex, {name='require'}) do
							for _,e in cpairs(r, {name='enum', attr={extends=nam}}) do
								local v
								if e.attr.value then
									v = e.attr.value and e.attr.value:gsub('[f()]', '')
									if hard[v] then v = hard[v] end
								elseif e.attr.offset then
									v = math.tointeger((10^9 + (ex.attr.number-1)*1000 + e.attr.offset)
										* (e.attr.dir == '-' and -1 or 1))
								elseif e.attr.bitpos then
									v = 1<<e.attr.bitpos
								end
								if v then
									o.values[e.attr.name] = v
									o.exts[e.attr.name] = ex.attr.author
								end
							end
						end
					end
				end
			end
		elseif o.category == 'struct' or o.category == 'union' then
			o.members = {}
			for _,mt in cpairs(t, {name='member'}) do
				local m = {}
				for k,v in pairs(mt.attr) do m[k] = v end
				m.type = first(mt, {name='type'}, {type='text'}).value
				m.name = first(mt, {name='name'}, {type='text'}).value

				local tx = {}
				for _,t in cpairs(mt, {type='text'}) do table.insert(tx, t.value) end
				m.arr = #(table.concat(tx):gsub('[^*[]', ''))

				table.insert(o.members, m)
			end
		end

		vk.types[t.attr.name or first(t, {name='name'}, {type='text'}).value] = o
		::cont::
	end
end

return vk
