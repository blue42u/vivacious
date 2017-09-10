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
		version = vk.version,
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

vkb.api = std.compound(vkb.api)
return vkb
