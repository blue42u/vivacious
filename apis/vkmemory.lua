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
local vk = require 'vulkan'
local vkm = {api={
	shortname = 'VkM',
	longname = 'Vulkan Memory Manager',
	doc = "A manager for the card's memory, designed to allow swapping",
	v0_1_1={},
}}

vkm.Pool = std.handle{
	doc="The Pool of allocatable memory. Usually only one is needed."
}

vkm.api.v0_1_1.create = std.func{
	doc = "Create a new Pool, for the specific card.",
	returns = vkm.Pool,
	vk.PhysicalDevice, vk.Device,
}
vkm.api.v0_1_1.destroy = std.method{
	doc = "Destory a Pool and all the device memory used by it.",
	vkm.Pool,
}

vkm.api.v0_1_1.registerBuffer = std.method{
	doc = [[
		Register a Buffer into the Pool, which will be assigned some
		device memory at the next `bind`. The flag arguments specify both
		properties that *must* be present, and properties that are
		*preferred* if they are present.
	]],
	vkm.Pool, vk.Buffer,
	{vk.MemoryPropertyFlags, 'ideal'}, {vk.MemoryPropertyFlags, 'required'},
}
vkm.api.v0_1_1.registerImage = std.method{
	doc = [[
		Register a Buffer into the Pool, see `registerBuffer`.
	]],
	vkm.Pool, vk.Image,
	{vk.MemoryPropertyFlags, 'ideal'}, {vk.MemoryPropertyFlags, 'required'},
}

vkm.api.v0_1_1.bind = std.method{
	doc = "Assign memory to all currently registered resources.",
	returns = vk.Result,
	vkm.Pool,
}

vkm.api.v0_1_1.mapBuffer = std.method{
	doc = "Map the bound memory for a Buffer into host-memory space",
	returns = {vk.Result, std.udata},
	vkm.Pool, vk.Buffer,
}
vkm.api.v0_1_1.mapImage = std.method{
	doc = "Map the bound memory for an Image into host-memory space",
	returns = {vk.Result, std.udata},
	vkm.Pool, vk.Image,
}

vkm.api.v0_1_1.unmapBuffer = std.method{
	doc = "Unmap the memory for a Buffer",
	vkm.Pool, vk.Buffer,
}
vkm.api.v0_1_1.unmapImage = std.method{
	doc = "Unmap the memory for an Image",
	vkm.Pool, vk.Image,
}

vkm.api.v0_1_1.getRangeBuffer = std.method{
	doc = "Get the assigned memory range for a Buffer, for flushing, etc.",
	returns=vk.MappedMemoryRange,
	vkm.Pool, vk.Buffer,
}
vkm.api.v0_1_1.getRangeImage = std.method{
	doc = "Get the assigned memory range for an Image, for flushing, etc.",
	returns=vk.MappedMemoryRange,
	vkm.Pool, vk.Image,
}

vkm.api.v0_1_1.unbindBuffer = std.method{
	doc = "Unassign a Buffer's memory, registering it for a later `bind`.",
	vkm.Pool, vk.Buffer,
}
vkm.api.v0_1_1.unbindImage = std.method{
	doc = "Unassign an Image's memory, registering it for a later `bind`.",
	vkm.Pool, vk.Image,
}

vkm.api.v0_1_1.destroyBuffer = std.method{
	doc = "Destroy a Buffer, unallocating its memory if needed.",
	vkm.Pool, vk.Buffer,
}
vkm.api.v0_1_1.destroyImage = std.method{
	doc = "Destroy an Image, unallocating its memory if needed.",
	vkm.Pool, vk.Image,
}

vkm.api = std.compound(vkm.api)
return vkm
