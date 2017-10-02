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

-- This document contains all the information about how the APIs themselves are
-- arranged and structured, in groups called "layers." Each layer is described by
-- a table with a name, docstring, and a sequence of API names/layer tables.

local layers = {}
local function l(t) layers[#layers+1] = t; return t end

local vkbind = l{
	name = [[ Vulkan-Specific Bindings ]],
	doc = [[ Contains all Vulkan-specific bindings. ]],
	'vulkan',
}

local cgraphbase = l{
	name = [[ Common Graphics Bindings ]],
	doc = [[ Bindings needed for any reasonable graphics application. ]],
	vkbind,
	'window',
}

local vkhelp = l{
	name = [[ Vulkan Helpers ]],
	doc = [[ Helpers to make using Vulkan a little easier/more flexible. ]],
	vkbind,
	'vkbplate',
	'vkmemory',
	'vkpipeline',
	'vkshader',
}

-- Test if `a` is a dependee of `b`
local function parentof(a, b)
	for _,p in ipairs(b) do if p == a then return true end end
	for _,p in ipairs(b) do
		if type(p) == 'table' and parentof(a,p) then
			return true
		end
	end
	return false
end

table.sort(layers, function(a, b)
	if parentof(a, b) then return true end
	if parentof(b, a) then return false end
	return a.name < b.name
end)

local apis = {}
for _,l in ipairs(layers) do
	for _,a in ipairs(l) do
		layers[a] = l
		if type(a) == 'string' then
			apis[#apis+1] = a
		end
	end
end
apis.layers = layers

return apis
