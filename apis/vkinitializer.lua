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

VkInstanceCreator = {doc = [[
	Collects requirements nessesary for the VkInstance, and will attempt to
	create the Instance or fail.
]], vk.Vk}
local vic = VkInstanceCreator

vic.type.Info = compound{
	doc = [[
		A bunch of restrictions on the Instance for the Creator. In particular:
		- <extensions> and <layers> are absolutely required.
		- <name> and <version> will overwrite any previously assigned values
		  if not NULL or 0.
		- <vkversion> is a lower bound on the Vulkan version.
	]],
	v0_1_1 = {
		{'name', string, ''},
		{'version', vk.Vk.version, 0},
		{'vkversion', vk.Vk.version, 0},
		{'extensions', array{string}, {}},
		{'layers', array{string}, {}},
	},
}

vic.v0_2_0.append = {
	doc = [[
		Append some more Info to the Creator. Returns an error code if one or
		more of the requirements requested is impossible.

		i.e. Check the extensions and layers here.
	]],
	returns = {vk.Vk.Result}, {'info', vic.Info},
}

vic.v0_2_0.create = {
	doc = [[
		Create an Instance with the all the collected Info the Creator has
		encountered so far. May still fail.
	]],
	returns = {vk.Instance, vk.Result},
}

vic.v0_2_0.reset = {
	doc = [[
		Resets all the internal data the Creator has gathered. Saves a
		destroy/create pair.
	]],
}

VkDeviceCreator = {doc = [[
	Collects requirements nessesary for the VkDevice and VkPhysicalDevice, to
	allow for smaller initializing codebases.
]], vk.Vk.Instance}
local vdc = VkDeviceCreator

vdc.type.Task = compound{
	doc = [[
		Specification of a Task, which will be assigned a Queue.
		- <family> indicates Tasks that need to be part of the same family;
		  if non-zero (-1 for C), identical settings will share a family
		  within the same call to `append`.
		  After `create`, gives the Queue family index.
		- <index>, after `create`, contains the assigned Queue index.
		- <flags> are the Queue flags that must be active on the Queue.
		- <priority> is the priority of the Queue.
		- <presentable> indicates that this Queue must be able to present on
		  the Surface given in the Info this Task is part of.
	]],
	{'family', index, 0},
	{'index', index, 0},
	{'flags', vk.Vk.QueueFlags, {}},
	{'priority', number, 0.5},
	{'presentable', boolean, false},
}

local pd = vk.PhysicalDevice
vdc.type.Info = compound{
	doc = [[
		Restrictions on the Device and PhysicalDevice. In particular:
		- <tasks> will be assigned a Queue to work on, the index of which is
		  written into the structures themselves.
		- <comparison> is used to choose between PhysicalDevices. Overwrites.
		- <validator> is used to check if a PhysicalDevice is applicable. Ditto.
		- <extensions> are required to be supported.
		- <vkversion> is a lower bound on the Vulkan version.
		- <surface> must be accessable by some Queue family, in particular by
		  elements of <tasks> which have presentable set to true.
		- <features> are required features of the PhysicalDevice.
	]],
	v0_1_1 = {
		{'tasks', array{vdc.Task}, {}},
		{'comparison', callable{returns={boolean}, {'a', pd}, {'b', pd}}},
		{'validator', callable{returns={boolean}, {'pd', pd}}},
		{'extensions', array{string}, {}},
		{'vkversion', vk.Vk.version},
	},
	v0_1_2 = {
		{'surface', vk.Instance.SurfaceKHR},
		{'features', vk.Vk.PhysicalDeviceFeatures, {}},
	},
}

vdc.v0_2_0.append = {
	doc = [[
		Append some more Info to the Creator. Returns an error code if one or
		more of the requirements requested is impossible.
	]],
	returns = {vk.Vk.Result}, {'info', vdc.Info},
}

vdc.v0_2_0.create = {
	doc = [[
		Create a Device with the all the collected Info the Creator has
		encountered so far. May still fail.
	]],
	returns = {vk.Device, vk.PhysicalDevice, vk.Result},
}

vdc.v0_2_0.reset = {
	doc = [[
		Resets all the internal data the Creator has gathered. Saves a
		destroy/create pair.
	]],
}

--[=[ To be converted at a later date, once its purpose is fully determined:
vkb.api.v0_1_2.createSwapchain = std.func{
	doc = [[
		Create a Swapchain from a Surface.
		<sci> will be modified before being used to create the
		Swapchain, in the following ways:
		- surface will be set to the new Surface.
		- imageFormat is completly ignored, and instead a format is
		  chosen which has a the properties given in <fprops>, and
		  which uses the color space in imageColorSpace.
		- If <windowExtent> is true, and the Surface has a
		  currentExtent, then imageExtent is replaced with that value.
		- preTransform is replaced with the composition of its original
		  value with the Surface's currentTransform.
		- compositeAlpha may be replaced if the given value is not
		  available (or 0). Applications should check afterwards to
		  change how they handle the alpha.
		- presentMode will be replaced with an available value which
		  cannot affect the application's execution, but may reduce
		  tearing or increase performance (implementation decides).

		The integer returned is the number of images in the created
		Swapchain.
	]],
	returns = {vk.SwapchainKHR, vk.uint32, vk.Result, main=3},
	vk.PhysicalDevice, vk.Device, vk.SurfaceKHR,
	{vk.SwapchainCreateInfoKHR, 'sci'},
	{std.boolean, 'windowExtent'},
	{vk.FormatProperties, 'fprops'},
}
--]=]
