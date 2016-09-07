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

local outtab = {}
local waserr = 0
local function out(s) table.insert(outtab, s) end
local function derror(err) print(err) ; waserr = waserr + 1 end

local typequeue = {start=1, final=0}
local function pushq(x)
	typequeue.final = typequeue.final + 1
	typequeue[typequeue.final] = x
end
local function popq()
	if typequeue.start > typequeue.final then return end
	local v = typequeue[typequeue.start]
	typequeue[typequeue.start] = nil
	typequeue.start = typequeue.start + 1
	return v
end

local types = {}
for _,t in cpairs(first(dom.root, {name='types'}), {name='type'}) do
	local name = first(t, {name='name'})
	if name then name = first(name, {type='text'}).value
	else name = t.attr.name end
	types[name] = t
end

local cmds = {}
for _,t in cpairs(first(dom.root, {name='commands'}), {name='command'}) do
	local name = first(t, {name='proto'}, {name='name'})
	name = first(name, {type='text'}).value
	cmds[name] = t
end

local valid = {command=true, enum=true, type=true, struct=true, bitmask=true}
local function sub(t)
	if not valid[t.name] then return
	elseif t.name == 'type'
		and not valid[types[t.attr.name].attr.category] then return end

	out('#define L_'..t.attr.name..'(S) S')
	if t.name == 'command' then
		pushq({'cmd', t.attr.name})
	elseif t.name == 'type' then
		pushq({'type', t.attr.name})
	end
end

out([[
// WARNING: Generated file. Do not edit manually.
// This file is include'd into lvulkan.c. Files were split for readability.

#ifdef IN_LVULKAN
]])

for _,f in cpairs(dom.root, {name='feature'}) do
	out('#if defined('..f.attr.name..')')
	for _,r in cpairs(f, {name='require'}) do
		for _,t in cpairs(r, {}) do
			sub(t)
		end
	end
	out('#endif // '..f.attr.name..'\n')
end

for _,f in cpairs(first(dom.root, {name='extensions'}), {name='extension'}) do
	out('#if defined('..f.attr.name..')')
	for _,r in cpairs(f, {name='require'}) do
		for _,t in cpairs(r, {}) do
			sub(t)
		end
	end
	out('#endif // '..f.attr.name..'\n')
end

local written = {}
repeat
	local v = popq()
	if v and not written[v[2]] then
		written[v[2]] = true
		if v[1] == 'cmd' then
			out('#if defined(L_'..v[2]..')')
			local tag = cmds[v[2]]
			local ret = first(tag, {name='proto'}, {name='type'})
			if ret then
				ret = first(ret, {type='text'}).value
				out('#define L_'..ret..'(S) S')
				pushq({'type', ret})
			end
			for _,p in cpairs(tag, {name='param'}) do
				local typ = first(p, {name='type'})
				if typ then
					typ = first(typ, {type='text'}).value
					out('#define L_'..typ..'(S) S')
					pushq({'type', typ})
				end
			end
			out('#endif\n')
		elseif v[1] == 'type' then
			local tag = types[v[2]]
			if tag.attr.category == 'struct' then
				out('#if defined(L_'..v[2]..')')
				
				out('#endif\n')
			end
		end
		out('// '..v[1]..' '..v[2])
	end
until not v

out('#endif // IN_LVULKAN')

if waserr > 0 then
	error('Errors happened: '..waserr..' to be exact!')
end

local f = io.open(arg[1], 'w')
f:write(table.concat(outtab, '\n'))
f:close()
