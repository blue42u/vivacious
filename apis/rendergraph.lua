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

RenderGraph = {[[
	A dependency graph of rendering operations (Steps) and contexts (States).
]], VkDevice}

RenderGraph.State = {[[
	A context in which Steps may be executed. When recording, entries into this
	State invoke <enter>, and exiting invokes <exit>. After a call to
	`getRenderPass` has completed on the Graph, <subpass> is set to the index
	of the subpass in which this State is used, if this State is subpass-bound.
]],
	v0_2_0 = {
		{'udata', general{}, constpointer=true},
		{'enter', callback{{'cb', VkCommandBuffer}, {'udata', 'general'}}},
		{'exit', callback{{'cb', VkCommandBuffer}, {'udata', 'general'}}},]
		{'subpass', index{}, readonly=true},
	},
}

RenderGraph.Step = {[[
	A single rendering operation (atomic for ordering purposes). When recording
	this Step, <handler> is called with <udata> as an argument.
]],
	v0_2_0 = {
		{'udata', general{}, constpointer=true},
		{'handler', callback{{'cb', VkCommandBuffer}, {'udata', 'general'}}},
	},
}

RenderGraph.typedef.Dependency = {[[
	A description of a dependency on a particular Step.
]],
	compound{
		v0_1_1 = {
			{'dstStep', RenderGraph.Step},
			{'srcStage', Vk.PipelineStageFlags},
			{'dstStage', Vk.PipelineStageFlags},
			{'srcAccess', Vk.AccessFlags, 0},
			{'dstAccess', Vk.AccessFlags, 0},
			{'flags', Vk.DependencyFlags, 0},
		},
	},
}

RenderGraph.v0_1_1.addState = {[[
	Add a new State into the Graph. <udata>, <enter> and <exit> set the
	corresponding fields in the new State. If <spassBound> is true, this State
	is subpass-bound and will only be used in a single subpass. gee
]],
	{'enter', callback{{'cb', VkCommandBuffer}, {'udata', 'general'}}},
	{'exit', callback{{'cb', VkCommandBuffer}, {'udata', 'general'}}},
	{'udata', general{}},
	{'spassBound', boolean{}, false},
	{RenderGraph.State},
}

RenderGraph.v0_1_1.addStep = {[[
	Add a new Step into the Graph, with the dependencies specified by <deps>.
	<udata> and <handler> set the corrosponding fields in the new Step. If
	<secondary> is true, this Step will be part of a subpass begun with
	VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS. May return NULL if the Step
	is able to be added due to dependency issues.
]],
	{'handler', callback{{'cb', VkCommandBuffer}, {'udata', 'general'}}},
	{'udata', general{}},
	{'deps', array{RenderGraph.Dependency}},
	{'states', array{RenderGraph.State}},
	{'secondary', boolean{}, false},
	{RenderGraph.Step},
}

RenderGraph.Step.v0_1_1.applyDependencies = {[[
	Apply more Dependencies onto this Step. Good for inserting Steps.
]],
	{'deps', array{RenderGraph.Dependency}},
}

RenderGraph.Step.v0_1_1.remove = {[[
	Remove a Step from the Graph. Destroys the Step.
]]}

RenderGraph.v0_1_1.getRenderPass = {[[
	Get the VkRenderPass for the Graph as it is arranged at the time of the call.
	<spass> is called for each subpass with the Steps and subpass-bound States in
	that subpass, and its return value is used as the Description for the subpass.
]],
	{'attachments', array{Vk.AttachmentDescription}},
	{'spass', callback{
		{'steps', array{RenderGraph.Step}},
		{'states', array{RenderGraph.State}},
		{Vk.SubpassDescription}
	}},
}

RenderGraph.v0_1_1.getStates = {[[
	Get a list of all the States in the Graph. May not include unused States.
]],
	{array{RenderGraph.State}},
}

RenderGraph.v0_1_1.getSteps = {[[
	Get a list of all the Steps in the Graph.
]],
	{array{RenderGraph.Step}},
}

RenderGraph.v0_1_1.record = {[[
	Record an invocation of the RenderGraph into <cb>.
]],
	{'cb', VkCommandBuffer}, {'rpbi', Vk.RenderPassBeginInfo},
}
