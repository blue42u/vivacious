--[[
Copyright (c) 2013 Gavin Kistner

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]
-- Optional parser that creates a flat DOM from parsing
local SLAXML = require 'slaxml'
function SLAXML:dom(xml,opts)
	if not opts then opts={} end
	local rich = not opts.simple
	local push, pop = table.insert, table.remove
	local stack = {}
	local doc = { type="document", name="#doc", kids={} }
	local current = doc
	local builder = SLAXML:parser{
		startElement = function(name,nsURI)
			local el = { type="element", name=name, kids={}, el=rich and {} or nil, attr={}, nsURI=nsURI, parent=rich and current or nil }
			if current==doc then
				if doc.root then error(("Encountered element '%s' when the document already has a root '%s' element"):format(name,doc.root.name)) end
				doc.root = el
			end
			push(current.kids,el)
			if current.el then push(current.el,el) end
			current = el
			push(stack,el)
		end,
		attribute = function(name,value,nsURI)
			if not current or current.type~="element" then error(("Encountered an attribute %s=%s but I wasn't inside an element"):format(name,value)) end
			local attr = {type='attribute',name=name,nsURI=nsURI,value=value,parent=rich and current or nil}
			if rich then current.attr[name] = value end
			push(current.attr,attr)
		end,
		closeElement = function(name)
			if current.name~=name or current.type~="element" then error(("Received a close element notification for '%s' but was inside a '%s' %s"):format(name,current.name,current.type)) end
			pop(stack)
			current = stack[#stack]
		end,
		text = function(value)
			if current.type~='document' then
				if current.type~="element" then error(("Received a text notification '%s' but was inside a %s"):format(value,current.type)) end
				push(current.kids,{type='text',name='#text',value=value,parent=rich and current or nil})
			end
		end,
		comment = function(value)
			push(current.kids,{type='comment',name='#comment',value=value,parent=rich and current or nil})
		end,
		pi = function(name,value)
			push(current.kids,{type='pi',name=name,value=value,parent=rich and current or nil})
		end
	}
	builder:parse(xml,opts)
	return doc
end
return SLAXML
