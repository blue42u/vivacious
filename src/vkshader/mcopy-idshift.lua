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

local handlers = {}
for _,ok in ipairs(spv.operand_kinds) do
	if ok.category == 'BitEnum' or ok.category == 'ValueEnum' then
		handlers[ok.kind] = function(c)
			out'\t\tWRITE(READ);'	-- Copy over the enum itself
			for _,e in ipairs(ok.enumerants) do
				if e.parameters then
					if ok.category == 'BitEnum' then
						out('\tif(last & Spv%s%sMask){',
							ok.kind, e.enumerant)
					else
						out('\tif(last == Spv%s%s) {',
							ok.kind, e.enumerant)
					end
					local from = c.from
					for i,p in ipairs(e.parameters) do
						c.from = ok.kind
							..'_'..e.enumerant
							..'_'..i
						handlers[p.kind](c)
					end
					c.from = from
					out('\t}')
				end
			end
		end
	elseif ok.category == 'Id' then
		handlers[ok.kind] = function(c) handlers.Id(c) end
	elseif ok.category == 'Literal' then
		handlers[ok.kind] = function(c)
			error('Unhandled literal '..ok.kind..' from '..c.from)
		end
	elseif ok.category == 'Composite' then
		handlers[ok.kind] = function(c)
			local from = c.from
			for i,b in ipairs(ok.bases) do
				c.from = from..'_'..i
				handlers[b](c)
			end
			c.from = from
		end
	else error('Unhandled operand_kind category '..ok.category) end
end

function handlers.Id(c)
	if c.mightbe then
		out('\t\tif(READ >= idsz || !ids[last+shift].defined) BACK;')
		out('\t\telse WRITE(ids[last+shift].map);')
	else	out('\t\tWRITE(ids[READ+shift].map);') end
end

function handlers.IdResult(c)
	handlers.Id(c)
	out('\t\tids[last+shift].defined = true;')
end

function handlers.LiteralString()
	out('\t\twhile(READ >> 24 && (last >> 16)&0xFF')
	out('\t\t\t&& (last >> 8)&0xFF && last&0xFF) WRITE(last);')
	out('\t\tWRITE(last);')
end

local limited = {
	OpSource = {nil,true},
	OpMemberName = {nil,true},
	OpLine = {nil,true,true},
	OpExtInst = {nil,nil,nil,true},
	ExecutionMode = {
		Invocations = {false},
		LocalSize = {true,true,true},
		LocalSizeHint = {true,true,true},
		OutputVertices = {false},
		VecTypeHint = {true},
		SubgroupSize = {false},
		SubgroupsPerWorkgroup = {false},
	},
	OpTypeInt = {nil,true,true},
	OpTypeFloat = {nil,false},
	OpTypeVector = {nil,nil,true},
	OpTypeMatrix = {nil,nil,false},
	OpTypeImage = {nil,nil,nil,true,true,true,true},
	OpConstant = {nil,nil,false},
	OpConstantSampler = {nil,nil,nil,true},
	OpSpecConstant = {nil,nil,false},
	OpSpecConstantOp = {nil,nil,true},
	MemoryAccess = {
		Aligned = {false},
	},
	OpArrayLength = {nil,nil,nil,true},
	Decoration = {
		SpecId = {false},
		ArrayStride = {false},
		MatrixStride = {false},
		Stream = {false},
		Location = {false},
		Component = {false},
		Index = {false},
		Binding = {false},
		DescriptorSet = {false},
		Offset = {false},
		XfbBuffer = {false},
		XfbStride = {false},
		InputAttachmentIndex = {false},
		Alignment = {false},
		MaxByteOffset = {false},
		SecondaryViewportRelativeNV = {false},
	},
	OpMemberDecorate = {nil,true},
	OpGroupMemberDecorate = {nil,{nil,true}},
	OpVectorShuffle = {[5]=true},
	OpCompositeExtract = {[4]=true},
	OpCompositeInsert = {[5]=true},
	LoopControl = {
		DependencyLength = {false},
	},
	OpBranchConditional = {[4]=true},
	OpSwitch = {[3]={'typewidth'}},
	OpLifetimeStart = {nil,false},
	OpLifetimeStop = {nil,false},
	OpConstantPipeStorage = {nil,nil,true,true,true,false},
}
function handlers.LiteralInteger(c)
	local l = limited
	for s in c.from:gmatch'[^_]+' do l = l and l[tonumber(s) or s] end
	if l == nil then
		error('Unhandled LiteralInteger from '..c.from)
	elseif l == true then	-- One-word
		out('\t\tWRITE(READ);')
	elseif l == false then	-- Unlimited, reaches EOI
		out('\t\twhile(!EOI) WRITE(READ);')
	elseif l == 'typewidth' then	-- Wordcount from ids
		out('\t\tfor(int i=0; i<ids[first+shift].numwords; i++) WRITE(READ);')
	else error() end
end
handlers.LiteralExtInstInteger = handlers.LiteralInteger
handlers.LiteralContextDependentNumber = handlers.LiteralInteger
handlers.LiteralSpecConstantOpInteger = handlers.LiteralInteger

rout[[
// WARNING: Generated file. Do not edit manually.

#include "vkshader/mcopy.h"
#include <string.h>
#include <stdio.h>

uint32_t _vVvks_mcopy_idshift(uint32_t* src, uint32_t* dst,
	uint32_t idsz, iddata ids[], uint32_t shift) {

	uint32_t opwc = *src;
	SpvOp op = opwc & SpvOpCodeMask;
	uint32_t wc = opwc >> SpvWordCountShift;
	uint32_t rwc = 0;

	uint32_t* ssrc = src;
	uint32_t* sdst = dst;

	uint32_t last;
	uint32_t first;
#define READ ( last = *src, src++, rwc++, last )
#define WRITE(W) ( *dst = W, dst++ )
#define BACK ( src--, rwc-- )
#define EOI ( rwc >= wc )

	WRITE(READ);	// Copy over the opcode + wordcnt
	switch(op) {]]

for _,ins in ipairs(spv.instructions) do
	out('\tcase Spv%s: ', ins.opname)
	if ins.operands then
		out'\t\tfirst = READ; BACK;'
	end
	if ins.opname == 'OpTypeInt' or ins.opname == 'OpTypeFloat' then
		-- Write down how many words this type uses
		out'\tREAD; ids[first].numwords = 1+((READ-1)/32); BACK; BACK;'
	end
	for i,arg in ipairs(ins.operands or {}) do
		if arg.quantifier == '*' then out('\twhile(!EOI) {')
		elseif arg.quantifier == '?' then out('\tif(!EOI) {')
		elseif arg.quantifier then
			error('Unhandled quantifier '..arg.quantifier) end
		handlers[arg.kind]{
			mightbe = arg.qualifier == '?',
			from = ins.opname..'_'..i
		}
		if arg.quantifier then out('\t}') end
	end
	if ins.opname:match'^OpType' and ins.opname ~= 'OpTypeForwardPointer' then
		-- Look for a dup, and set the mapping to the older one
		rout[[
	for(size_t i=0; i<idsz; i++) {
		if(ids[i].defined && ids[i].op && *ids[i].op == opwc
			&& memcmp(&ids[i].op[2], &sdst[2],
				(wc-2)*sizeof(uint32_t)) == 0) {
			ids[first+shift].map = i;
			ids[first+shift].defined = true;
			return 0;
		}
	}
	ids[first+shift].op = sdst;]]
	end
	out('\t\tbreak;')
end

out[[
	case SpvOpMax: break;
	};

	return wc;
}
]]
