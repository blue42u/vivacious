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

ShaderBank = {doc = [[
	A storage for shader components, which are shaders that have been loaded and
	are ready to be merged into larger shaders that cumulate the effects of
	the individual parts.
]]}
local sb = ShaderBank

sb.Component = {doc = [[A shader that has been loaded into a Bank.]]}

sb.v0_1_2.load = {
	doc = [[
		Load a shader into the Bank, for later use in constructing new shaders.
		May return NULL if something goes wrong.
	]],
	returns = {sb.Component}, {'smci', vk.Vk.ShaderModuleCreateInfo},
}

sb.v0_1_2.construct = {
	doc = [[
		Construct a new shader that cumulates the effects of the previously
		loaded shaders given in <components>. The following is the old docs;
		they assume a SPIR-V based system and should be rewritten at some point.

		All instructions and operands in the original code will be
		present in the code given to Vulkan, with the following
		allowed exceptions:
		- <id>s may change, to prevent conflicts
		- Unnessesary duplicates may be removed, as long as their
		  removal does not affect the execution in any way.
		- OpEntryPoints may be removed or replaced, see below.

		For each execution model, a matching entry point (EP) should
		be chosen from every Component that contains one, and the
		chosen EPs should be merged into one larger EP named "main"
		in the same order as the source Components are specified.
		The execution modes (EMs) enabled for the "main" EP ensure
		no source EP will execute differently than designed. Let
		M be the set of enabled EMs for the "main" EP, A be the EMs
		for a source EP, and Ac be the EMs enabled on the
		corrosponding "compat_"-prefixed EP. Then M is valid iff:
		- M == A,
		- M ^ A <= Ac,
		- The implementation can determine that (M^A)-Ac will not
		  affect the execution of A, or
		- The implementation can emulate the effect of (M^A)-Ac
		  in an undetectable manner.
		If there does not exist an M for a particular set of EPs,
		another set can be chosen as stated above.
	]],
	returns = {vk.Device.ShaderModule, vk.Vk.Result},
	{'dev', vk.Device}, {'components', array{sb.Component}},
}
