--[========================================================================[
   Copyright 2016-2018 Jonathon Anderson

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

local trav = require 'external.traversal'
local cpairs, first = trav.cpairs, trav.first

local xml,err = io.open('external/vulkan-docs/src/spec/vk.xml', 'r')
if err then error(err) end
xml = xml:read('a')
package.loaded.slaxml = require 'external.slaxml'
local dom = require('external.slaxdom'):dom(xml, {stripWhitespace=true})

local vk = {}

vk.vids = {}
for _,ts in cpairs(dom.root, {name='tags'}) do
	for _,t in cpairs(ts, {name='tag'}) do
		vk.vids[t.attr.name] = true
	end
end

vk.types = {}
for _,ts in cpairs(dom.root, {name='types'}) do
	for _,t in cpairs(ts, {name='type'}) do
		local o = {}
		for k,v in pairs(t.attr) do o[k] = v end
		if not o.type then
			local tt = first(t, {name='type'}, {type='text'})
			if tt then o.type = tt.value end
		end
		if not o.name then
			local tt = first(t, {name='name'}, {type='text'})
			if tt then o.name = tt.value end
		end

		if o.category == 'enum' or o.category == 'bitmask' then
			local nam = o.category == 'enum' and o.name or o.requires

			o.values, o.exts = {},{}
			local hard = {
				['~0U'] = 0xffffffff,	-- Assuming int is 32 bits wide
				['~0U-1'] = 0xffffffff-1,
				['~0U-2'] = 0xffffffff-2,
				['~0ULL'] = 0xffffffffffffffff,	-- Since long long is 64 bits wide
			}

			if nam then
				local tes = first(dom.root, {name='enums', attr={name=nam}})
				if tes then
					for _,e in cpairs(tes, {name='enum'}) do
						local v = e.attr.value and e.attr.value:gsub('[f()]', '')
						if hard[v] then v = hard[v] end
						v = tonumber(v) or 1<<e.attr.bitpos

						o.values[e.attr.name] = v
					end
				end
				for _,exs in cpairs(dom.root, {name='extensions'}) do
					for _,ex in cpairs(exs, {name='extension'}) do
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
				for _,tt in cpairs(mt, {type='text'}) do table.insert(tx, tt.value) end
				m.arr = #(table.concat(tx):gsub('[^*[]', ''))

				table.insert(o.members, m)
			end
		end

		vk.types[t.attr.name or first(t, {name='name'}, {type='text'}).value] = o
	end
end

local allcmds = {}
for _,ts in cpairs(dom.root, {name='commands'}) do
	for _,t in cpairs(ts, {name='command'}) do
		local c = {}
		for k,v in pairs(t.attr) do if type(k) == 'string' then c[k] = v end end
		c.name = first(t, {name='proto'}, {name='name'}, {type='text'}).value
		c.ret = first(t, {name='proto'}, {name='type'}, {type='text'}).value
		for _,tp in cpairs(t, {name='param'}) do
			local a = {}
			for k,v in pairs(tp.attr) do if type(k) == 'string' then a[k] = v end end
			a.name = first(tp, {name='name'}, {type='text'}).value
			a.type = first(tp, {name='type'}, {type='text'}).value

			local tx = {}
			for _,tt in cpairs(tp, {type='text'}) do table.insert(tx, tt.value) end
			a.arr = #(table.concat(tx):gsub('[^*[]', ''))

			table.insert(c, a)
		end
		allcmds[c.name] = c
	end
end

vk.cmds = {}
for _,t in cpairs(dom.root, {name='feature', attr={api='vulkan'}}) do
	local cs = {}
	for _,r in cpairs(t, {name='require'}) do
		for _,c in cpairs(r, {name='command'}) do
			assert(allcmds[c.attr.name])
			table.insert(cs, allcmds[c.attr.name])
		end
	end
	vk.cmds[t.attr.number] = cs
end
for _,ts in cpairs(dom.root, {name='extensions'}) do
	for _,t in cpairs(ts, {name='extension', attr={supported='vulkan'}}) do
		local cs = {extname=t.attr.name}
		for _,r in cpairs(t, {name='require'}) do
			for _,c in cpairs(r, {name='command'}) do
				assert(allcmds[c.attr.name])
				table.insert(cs, allcmds[c.attr.name])
			end
		end
		vk.cmds[t.attr.number] = cs
	end
end

return vk
