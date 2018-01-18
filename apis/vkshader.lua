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
local vks = {api=std.precompound{
	shortname = 'VkS',
	longname = 'Vulkan Patchwork Shader Constructor',
	doc = [[A manager and stitcher for merging multiple shaders into one.]],
}}

vks.Bank = std.handle{doc=[[A storage for shaders that will be merged.]]}
vks.Component = std.handle{doc=[[A reference to one of the shaders in a Bank]]}

vks.api.v0_1_2.createBank = std.func{
	doc = [[ Create a new empty Bank. ]],
	returns = vks.Bank,
}

vks.api.v0_1_2.destroyBank = std.func{
	doc = [[ Destroy a Bank and all Components contained within. ]],
	vks.Bank,
}

vks.api.v0_1_2.loadShader = std.func{
	doc = [[
		Load a shader module into a Bank, which is then available
		for use by later calls to `construct`.
	]],
	returns = vks.Component,
	vks.Bank, vk.ShaderModuleCreateInfo,
}

vks.api.v0_1_2.construct = std.func{
	doc = [[
		Stitch together multiple shader modules into one, creating a
		If the shader code given to `loadShader` is valid, then the
		resulting code given to Vulkan will be valid.

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
	returns = {vk.ShaderModule, vk.Result, main=2},
	vks.Bank, vk.Device, std.array{vks.Component},
}

vks.api = std.compound(vks.api)
return vks
