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
-- luacheck: std lua53, new globals gen

-- Handy docstring whitespace replacement thingy
local function rewhite(base, pre)
	local whitepre = base:match '^%s*'
	local lines = {}
	for l in base:gmatch '[^\n]+' do if l:match '%g' then
		table.insert(lines, pre..(l:gsub(whitepre, '')))
	end end
	return table.concat(lines, '\n')
end

local g = gen.rules()

g:addrule('main', function(self)
	local out = gen.collector()
	if self.specname then out('# ',self.specname,' Specification')
	elseif self.__name then
		out('## ',self.__name,self.__raw and self.__raw.C and ' (`'..self.__raw.C..'`)')
	end

	if self.__doc then out(rewhite(self.__doc, '')) end
	if self.basic then out('\t',self.basic) else
		out(self.enum)
		out(self.newindex)
		out(self.index)
		out(self.call)
	end
	out ''

	return self.ismain and out or nil
end)

g:addrule('definition', function(self)
	if self.__name then return self.__name
	elseif self.basic then return self.basic
	elseif self.__raw then return '`'..self.__raw.C..'`' end
end)

g:addrule('enum', '-definition', function(self)
	if not self.__enum then return end

	local defbits = {}
	local out = gen.collector()
	out('### Possible Values', self.__mask and ' (also a mask!)')
	for _,e in ipairs(self.__enum) do
		out('-\t',e.name, self.__raw and self.__raw.enum[e.name]
			and ' (`'..self.__raw.enum[e.name].C..'`)', e.flag and "'"..e.flag.."'")
		table.insert(defbits, "'"..e.name.."'")
	end
	return out, '('..table.concat(defbits, '|')..')'
end)

g:addrule('newindex', '-definition', function(self)
	if not self.__newindex then return end

	local defbits = {}
	local out = gen.collector()
	out '### Writable Contents'
	for _,e in ipairs(self.__newindex) do
		local v = e.version and '*v'..e.version..'* ' or ''
		if e.name == '__sequence' then
			out('-\t',v,'Sequence elements: ',e.type.definition)
			defbits.fin = '('..e.type.definition..'), ...'
		elseif e.aliasof then
			out('-\t',v,'`',e.name,'` = alias for `',e.aliasof,'`')
		else
			out('-\t',v,'`',e.name,'` = ',e.type.definition)
			table.insert(defbits, e.name..' = ('..e.type.definition..')')
		end
		if e.doc then out(rewhite(e.doc, '\t')) end
	end

	if defbits.fin then table.insert(defbits, defbits.fin) end
	return out, '{'..table.concat(defbits, ', ')..'}'
end)

g:addrule('index', '-definition', function(self)
	if not self.__index then return end

	local defbits = {}
	local out = gen.collector()
	out '### Contents'
	for _,e in ipairs(self.__index) do
		local v = e.version and '*v'..e.version..'* ' or ''
		if e.name == '__sequence' then
			out('-\t',v,'Sequence elements: ',e.type.definition)
			defbits.fin = '('..e.type.definition..'), ...'
		elseif e.aliasof then
			out('-\t',v,'`',e.name,'` = alias for `',e.aliasof,'`')
		else
			out('-\t',v,'`',e.name,'` = ',e.type.definition)
			table.insert(defbits, e.name..' = ('..e.type.definition..')')
		end
		if e.doc then out(rewhite(e.doc, '\t')) end
	end

	if defbits.fin then table.insert(defbits, defbits.fin) end
	return out, '{'..table.concat(defbits, ', ')..'}'
end)

g:addrule('call', '-definition', function(self)
	if not self.__call then return end

	local args,rets = {},{}
	local out = gen.collector()
	out '### Call Semantics'
	for _,e in ipairs(self.__call) do
		table.insert(e.ret and rets or args,
			(e.name and e.name..' ' or '')..'('..e.type.definition..')'
			..(e.default ~= nil and ' \\['..tostring(e.default)..']' or ''))
	end
	args,rets = table.concat(args, ', '), table.concat(rets, ', ')
	local full = ('(%s) %s %s'):format(args, self.__call.method and '=>' or '->', rets)
	out('   ',full)

	return out, full
end)

return g
