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

local spv = dofile'../external/spirv.lua'

io.output(arg[1])
local function out(s, ...) io.write(s:format(...)..'\n') end
local function rout(s) io.write(s..'\n') end

local sections = {
	DEBUGA = {'OpString', 'OpSourceExtension',
		'OpSource', 'OpSourceContinued'},
	DEBUGB = {'OpName', 'OpMemberName'},
	ANNOTATE = {'OpDecorate', 'OpMemberDecorate', 'OpGroupDecorate',
		'OpGroupMemberDecorate', 'OpDecorationGroup'},
	TYPES = {'OpLine', 'OpUndef', 'OpVariable'},
}

for _,op in ipairs(spv.instructions) do
	if op.opname:match'^OpType' or op.opname:match'^OpConstant'
		or op.opname:match'^OpSpec' then
		table.insert(sections.TYPES, op.opname)
	end
end

rout[[
// WARNING: Generated file. Do not edit manually.

]]
for n,c in pairs(sections) do
	for i,o in ipairs(c) do c[i] = 'OP == Spv'..o end
	out('#define SEC_%s (%s)', n, table.concat(c, ' || '))
end
