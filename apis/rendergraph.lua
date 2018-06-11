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

RenderGraph = {doc = [[
	A rendering pipeline, which contains many different Steps to exeucte and
	States in which to execute them.
]]}
local rg = RenderGraph

rg.Step = {doc = "A single (possibly atomic) sequence of rendering operations"}
local sp = rg.Step

rg.State = {doc = "A certain State in which Steps may execute."}
local st = rg.State

rg.type.Dependency = compound{
	v0_1_1 = {
		{'step', sp},
		{'srcStage', vk.Vk.PipelineStageFlags},
		{'dstStage', vk.Vk.PipelineStageFlags},
		{'flags', vk.Vk.DependencyFlags, {}},
		{'srcAccess', vk.Vk.AccessFlags, {}},
		{'dstAccess', vk.Vk.AccessFlags, {}},

		{'attachment', compound{
			{'enable', boolean},
			{'attachment', index},
			{'range', vk.Vk.ImageSubresourceRange},
		}, {enable=false, attachment=1}}
	}
}

rg.v0_1_1.addState = {
	doc = [[
		Add a new State into the Graph. <udata> is passed to the State
		handler and returned by `getStates`. If <spassBound> is true,
		then all Steps that use this State will share a subpass.
	]],
	returns = {st},
	{'udata', generic}, {'spassBound', boolean},
}
st.v0_1_1.rw.udata = generic

rg.v0_1_1.addStep = {
	doc = [[
		Add a new Step to the Graph, with dependencies. <udata> is
		passed to the Step handler and returned by `getSteps`. If
		<secondary> is true, this Step will be part of a subpass
		begun with VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS.
		May return NULL if the Step is not able to be added.
	]],
	returns = {sp},
	{'udata', generic}, {'secondary', boolean},
	{'states', array{st}}, {'dependencies', array{rg.Dependency}},
}
sp.v0_1_1.rw.udata = generic

sp.v0_1_1.addDependencies = {
	doc = "Add more dependencies to a Step. Good for inserting Steps.",
	{'dependencies', array{rg.Dependency}},
}

rg.v0_1_1.compile = {
	doc = [[
		Get the VkRenderPass from the Graph. <spass> is called with
		the Steps and subpass-bound States for a single subpass, and
		should return the resulting SubpassDescription.
	]],
	returns = {vk.Device.RenderPass, vk.Vk.Result},
	{'dev', vk.Device}, {'attachments', array{vk.Vk.AttachmentDescription}},
	{'spass', callable{
		returns = {vk.Vk.SubpassDescription},
		{'steps', array{generic}}, {'states', array{generic}},
	}},
}
st.v0_1_1.ro.subpassIndex = index

rg.v0_1_1.getStates = {
	doc = [[
		Get a list of all the <udata>'s for all (used) States in the
		Graph, as well as the corrosponding subpass indicies.
	]],
	returns = {array{st}},
}

rg.v0_1_1.getSteps = {
	doc = [[
		Get a list of all the <udata>'s for all the Steps in the Graph.
	]],
	returns = {array{sp}},
}

rg.v0_1_1.record = {
	doc = [[
		Record an invocation of the RenderPass for the Graph.
		<set> and <uset> are used to record State transitions, and
		<cmd> for recording Steps.
		<attachments> is the array of attachments used when creating the
		Framebuffer, for attachment-based dependencies.
	]],
	{'cb', vk.CommandBuffer}, {'rpbi', vk.Vk.RenderPassBeginInfo},
	{'attachments', array{vk.Device.Image}},
	{'set', callable{{'state', st}}},
	{'uset', callable{{'state', st}}},
	{'cmd', callable{{'step', sp}}},
}
