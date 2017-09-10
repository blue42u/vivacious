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
local vkp = {api={
	shortname = 'VkP',
	longname = 'Vulkan Pipeline Constructor',
	doc = "A constructor and manager for rendering pipelines",
	v0_1_1={},
}}

vkp.Graph = std.handle{doc="The graph of dependencies between Steps."}
vkp.Step = std.handle{doc="A single (possibly atomic) rendering operation(s)."}
vkp.State = std.handle{doc="A certain State in which Steps may execute."}

vkp.Dependency = std.compound{
	doc = "An execution dependency between Steps.",
	v0_1_1 = {
		step = vkp.Step,

		srcStage = vk.PipelineStageFlags,
		dstStage = vk.PipelineStageFlags,

		flags = {vk.DependencyFlags, 0},

		srcAccess = {vk.AccessFlags, 0},
		dstAccess = {vk.AccessFlags, 0},

		attachmentEnable = {std.boolean, false},
		attachment = {std.index, 1},
		attachmentRange = {vk.ImageSubresourceRange, '{}'},
	},
}

vkp.api.v0_1_1.create = std.func{
	doc = "Create a new empty Graph.",
	returns = vkp.Graph,
}

vkp.api.v0_1_1.destroy = std.method{
	doc = "Destory a Graph and all its Steps and States.",
	vkp.Graph,
}

vkp.api.v0_1_1.addState = std.method{
	doc = [[
		Add a new State into the Graph. <udata> is passed to the State
		handler and returned by `getStates`. If <spassBound> is true,
		then all Steps that use this State will share a subpass.
	]],
	returns = vkp.State,
	vkp.Graph,
	{std.udata, 'udata'}, {std.boolean, 'spassBound'},
}

vkp.api.v0_1_1.addStep = std.method{
	doc = [[
		Add a new Step to the Graph, with dependencies. <udata> is
		passed to the Step handler and returned by `getSteps`. If
		<secondary> is true, this Step will be part of a subpass
		begun with VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS.
		May return NULL if the Step is not able to be added.
	]],
	returns = vkp.Step,
	vkp.Graph,
	{std.udata, 'udata'}, {std.boolean, 'secondary'},
	std.array{vkp.State}, std.array{vkp.Dependency},
}

vkp.api.v0_1_1.addDepends = std.method{
	doc = [[
		Add more dependencies to a Step. Good for inserting Steps.
	]],
	vkp.Graph, vkp.Step,
	std.array{vkp.Dependency},
}

vkp.api.v0_1_1.removeStep = std.method{
	doc = [[
		Remove a Step from the Graph.
	]],
	vkp.Graph, vkp.Step,
}

vkp.api.v0_1_1.getRenderPass = std.method{
	doc = [[
		Get the VkRenderPass from the Graph. <spass> is called with
		the Steps and subpass-bound States for a single subpass, and
		should return the resulting SubpassDescription.
	]],
	returns={ vk.RenderPass, vk.Result },
	vkp.Graph, vk.Device,
	std.array{vk.AttachmentDescription},
	{std.callback{
		returns = vk.SubpassDescription,
		{std.array{std.udata}, 'steps'},
		{std.array{std.udata}, 'states'},
	}, 'spass'},
}

vkp.api.v0_1_1.getStates = std.method{
	doc = [[
		Get a list of all the <udata>'s for all (used) States in the
		Graph, as well as the corrosponding subpass indicies.
	]],
	returns = {
		std.array{std.udata}, std.array{std.index,size=true},
	},
	vkp.Graph,
}

vkp.api.v0_1_1.getSteps = std.method{
	doc = [[
		Get a list of all the <udata>'s for all the Steps in the Graph.
	]],
	returns = std.array{std.udata},
	vkp.Graph,
}

vkp.api.v0_1_1.record = std.method{
	doc = [[
		Record an invocation of the RenderPass for the Graph.
		<set> and <uset> are used to record State transitions, and
		<cmd> for recording Steps.
		<attachments> is the array of attachments used when creating the
		Framebuffer, for attachment-based dependencies.
	]],
	vkp.Graph, vk.CommandBuffer, vk.RenderPassBeginInfo,
	{std.array{vk.Image,size=true}, 'attachments'},
	{std.callback{ {std.udata, 'udata'}, vk.CommandBuffer }, 'set'},
	{std.callback{ {std.udata, 'udata'}, vk.CommandBuffer }, 'uset'},
	{std.callback{ {std.udata, 'udata'}, vk.CommandBuffer }, 'cmd'},
}

vkp.api = std.compound(vkp.api)
return vkp
