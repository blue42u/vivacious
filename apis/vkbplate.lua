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
local vkb = {api=std.precompound{
	shortname = 'VkB',
	longname = 'Vulkan Boilerplate',
	doc = "The basic boilerplate needed to use Vulkan (headless).",
}}

vkb.InstInfo = std.compound{
	doc = "Collects info on the Instance to be created",
	v0_1_1 = {
		extensions = {std.array{std.string}, {}},
		layers = {std.array{std.string}, {}},
		name = std.string,
		version = vk.version,
		vkversion = {vk.version, '0.0.0'},
	},
}

vkb.api.v0_1_1.createInstance = std.func{
	doc = "Attempts to create a new Vulkan Instance",
	returns={vk.Instance, vk.Result, main=2},
	vkb.InstInfo,
}

vkb.TaskInfo = std.smallcomp{
	v0 = {
		family = std.index,
		flags = vk.QueueFlags,
		priority = std.number,
		presentable = std.boolean,
	},
}

local pdev = vk.PhysicalDevice
vkb.DevInfo = std.compound{
	doc = "Collects info on the Device to be created",
	v0_1_1 = {
		comparison = {std.callback{returns=std.boolean, pdev, pdev}, true},
		extensions = {std.array{std.string}, {}},
		tasks = {std.array{vkb.TaskInfo}, {}},
		validator = {std.callback{returns=std.boolean, pdev}, true},
		version = {vk.version, '0.0.0'},
	},
	v0_1_2 = {
		surface = {vk.SurfaceKHR, 'NULL'},
	},
}

vkb.QueueSpec = std.smallcomp{
	v0 = {
		index = std.index,
		family = std.index,
	},
}

vkb.api.v0_1_1.createDevice = std.func{
	doc = "Create a new Vulkan Device",
	returns={vk.Device, vk.PhysicalDevice,
		std.array{vkb.QueueSpec, size='dinfo->tasksCnt'},
		vk.Result, main=4},
	{vkb.DevInfo, 'dinfo'}, vk.Instance,
}

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
	returns = {vk.SwapchainKHR, std.integer, vk.Result, main=3},
	vk.PhysicalDevice, vk.Device, vk.SurfaceKHR,
	{vk.SwapchainCreateInfoKHR, 'sci'},
	{std.boolean, 'windowExtent'},
	{vk.FormatProperties, 'fprops'},
}

vkb.api = std.compound(vkb.api)
return vkb
