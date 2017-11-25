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

ShaderBank = {[[
	A manager and stitcher for merging multiple shaders into one.
]], VkDevice}

ShaderBank.Component = {[[
	A reference to one of the shaders in a ShaderBank, which can then be
	used to `construct` VkShaderModules for application use.
]]}

ShaderBank.v0_1_2.load = {[[
	Load the shader described by <smci> into the ShaderBank and return the
	Component for the loaded shader. This *should* be a SPIR-V shader, any other
	format is not required to be supported by implementations.
]],
	{'smci', VkShaderModuleCreateInfo},
	{ShaderBank.Component},
}

ShaderBank.v0_1_2.construct = {[[
	Stich together the loaded shaders <comps> into one larger ShaderModule,
	which will (effectively) execute each shader in turn before returning. A
	number of EntryPoints (EPs) are present in the result, one for each possible
	shader stage, with the name "main". If the implementation cannot determine
	how to merge the Components into a valid shader, it may error with
	VK_ERROR_FORMAT_NOT_SUPPORTED.

	There may be multiple EPs in the given Components, and it may be possible to
	differing ExecutionModes between Components for the same stage. To deal with
	this, the implementation is allowed to pick which EP it uses from each
	Component (only one may be used from each Component), with higher precidence
	to EPs defined earlier. In addition, if two OpEntryPoint commands use the
	same OpFunction id, and one is named "compat", it defines the compatible
	ExecutionModes for the other EP.

	In short, an EP is allowed to be executed under the ExecutionMode set M iff
	one of the following is true, where the EP's original ExeutionMode set is O
	and the ExecutionMode set of the corrosponding "compat" EP is C:
	- M == O,
	- M ^ O <= C,
	- The implementation can determine that (M^O)-C will not affect in any
	  possible way the execution of the EP, or
	- The implementation will emulate the effects of (M^O)-C.
]],
	{'comps', array{ShaderBank.Component}},
	{VkDevice.ShaderModule},
	{VkResult, c_main=true},
}
