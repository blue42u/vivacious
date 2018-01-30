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

vk = require 'vulkan'

DeviceMemoryPool = {doc = [[
	A manager for the card's memory, designed to allow for more difficult,
	under-the-hood actions such as swapping.
]]}
local dmp = DeviceMemoryPool

dmp.v0_1_1.registerBuffer = {
	doc = "Register a VkBuffer with the Pool, with access restrictions.",
	{'buff', vk.Device.Buffer},
	{'ideal', vk.Vk.MemoryPropertyFlags}, {'required', vk.Vk.MemoryPropertyFlags}
}
dmp.v0_1_1.registerImage = {
	doc = "Register a VkImage with the Pool, with access restrictions.",
	{'buff', vk.Device.Buffer},
	{'ideal', vk.Vk.MemoryPropertyFlags}, {'required', vk.Vk.MemoryPropertyFlags}
}

dmp.v0_1_1.bind = {
	doc = "Ensure that all regestered currently have memory assigned and bound",
	returns = {vk.Result},
}

dmp.v0_1_1.mapBuffer = {
	doc = "Map the bound memory for a Buffer into host-memory space",
	returns = {vk.Vk.Result, memory},
	{'buff', vk.Device.Buffer},
}
dmp.v0_1_1.mapImage = {
	doc = "Map the bound memory for an Image into host-memory space",
	returns = {vk.Vk.Result, memory},
	{'img', vk.Device.Image},
}

dmp.v0_1_1.unmapBuffer = {
	doc = "Unmap the memory for a Buffer",
	{'buff', vk.Device.Buffer},
}
dmp.v0_1_1.unmapImage = {
	doc = "Unmap the memory for an Image",
	{'img', vk.Device.Image},
}

dmp.v0_1_1.getRangeBuffer = {
	doc = "Get the assigned memory range for a Buffer, for flushing, etc.",
	returns = {vk.Vk.MappedMemoryRange}, {'buff', vk.Device.Buffer},
}
dmp.v0_1_1.getRangeImage = {
	doc = "Get the assigned memory range for an Image, for flushing, etc.",
	returns = {vk.Vk.MappedMemoryRange}, {'img', vk.Device.Image},
}

dmp.v0_1_1.unbindBuffer = {
	doc = "Unassign a Buffer's memory, registering it for a later `bind`.",
	{'buff', vk.Device.Buffer},
}
dmp.v0_1_1.unbindImage = {
	doc = "Unassign an Image's memory, registering it for a later `bind`.",
	{'img', vk.Device.Image},
}

dmp.v0_1_1.destroyBuffer = {
	doc = "Destroy a Buffer, unallocating its memory if needed.",
	{'buff', vk.Device.Buffer},
}
dmp.v0_1_1.destroyImage = {
	doc = "Destroy an Image, unallocating its memory if needed.",
	{'img', vk.Device.Image},
}
