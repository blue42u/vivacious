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

require 'vulkan'

MemoryPool = {doc=[[
	Manager for memory on the Device-side.
]], VkDevice}

MemoryPool.Resource = {doc=[[
	A reference to a resource in the Pool, which may or may not have
	allocated memory, be mapped anywhere, or be currently usable.
	Before this Resource has been Bound, <range> may not be filled yet. Check
	that <range.sType> is valid or <range.memory> is non-NULL before using it.
]],
	v0_1_1 = {
		{'range', Vk.MappedMemoryRange, readonly=true, invalidempty=true},
		{'resource', {buffer=VkDevice.Buffer, image=VkDevice.Image}, readonly=true},
	},
}

MemoryPool.v0_1_1.register = {[[
	Register a Vulkan resource with the Pool. The <required> flags will always
	active on the memory chosen for this resource, <ideal> extends that if possible.
]],
	{'obj', {Buffer=VkDevice.Buffer, Image=VkDevice.Image}},
	{'required', VkMemoryPropertyFlags}, {'ideal', VkMemoryPropertyFlags, 0},
	{MemoryPool.Resource},
}

MemoryPool.v0_1_1.bind = {[[
	Allocate and bind memory for all registered resources. After this,
	all <Resource.range> values are valid and
]]}

MemoryPool.Resource.v0_1_1.unbind = {[[
	Unallocate the memory for this Resource.
]]}

MemoryPool.Resource.v0_1_1.unregister = {[[
	Unregister this Resource, destroying the internal Vulkan resource as well.
]]}
