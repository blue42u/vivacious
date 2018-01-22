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

VkMemoryPool = {doc = [[
	A manager for the card's memory, designed to allow for more difficult,
	under-the-hood actions such as swapping.
]]}

VkMemoryPool.v0_1_1.registerBuffer = {
	doc = "Register a VkBuffer with the Pool, with access restrictions.",
	{'buff', vk.Device.Buffer},
	{'ideal', vk.Vk.MemoryPropertyFlags}, {'required', vk.Vk.MemoryPropertyFlags}
}
