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

local spv = dofile(arg[1]..'/spirv.lua')

io.output('mcopy-idshift.c')
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
		out('\t\tfor(int i=0; i<ids[idres+shift].numwords; i++) WRITE(READ);')
	else error() end
end
handlers.LiteralExtInstInteger = handlers.LiteralInteger
handlers.LiteralContextDependentNumber = handlers.LiteralInteger
handlers.LiteralSpecConstantOpInteger = handlers.LiteralInteger

local defmergeable = {
	OpVariable = true,
	OpExtInstImport = true,
}
local mergeable = {}
for _,op in ipairs(spv.instructions) do
	local n = op.opname
	if defmergeable[n]
		or (n:match'^OpType' and n ~= 'OpTypeForwardPointer')
		or n:match'^OpConstant' then

		for i,o in ipairs(op.operands) do
			if o.kind == 'IdResult' then
				mergeable[i] = mergeable[i] or {}
				table.insert(mergeable[i], n)
				break
			end
		end
	end
end

rout[=[
// WARNING: Generated file. Do not edit manually.

#include "vkshader/mcopy.h"
#include <string.h>
#include <stdio.h>

uint32_t _vVvks_scan(uint32_t* src, uint32_t* dst,
	uint32_t idsz, iddata ids[], uint32_t shift) {

	// Decorations are forward ref, so we save it for later
	if((src[0] & SpvOpCodeMask) == SpvOpDecorate) {
		if(src[2] == SpvDecorationBuiltIn)
			ids[src[1]+shift].builtin = src[3];
		if(src[2] == SpvDecorationLocation)
			ids[src[1]+shift].location = src[3];
		if(src[2] == SpvDecorationComponent)
			ids[src[1]+shift].component = src[3];
	}

	if((src[0] & SpvOpCodeMask) == SpvOpVariable) {
		if(src[3] == SpvStorageClassFunction) return 0;
	}

	uint32_t ind;
	switch(*src & SpvOpCodeMask) {]=]
for i,ns in pairs(mergeable) do
	for _,n in ipairs(ns) do
		rout('\tcase Spv'..n..':')
	end
	rout('\t\tind = '..i..'; break;')
end
rout[=[
	// If its not a mergeable, we don't care about it.
	default: return 0;
	};

	// Copy it over. If its skipped already, don't bother with it.
	uint32_t wc = _vVvks_copy(src, dst, idsz, ids, shift);
	if(wc == 0) return 0;

	// Look to see if this is a dup of some other instruction. If it is,
	// we mark it to be skipped, change its mapping, and don't write it out.
	for(uint32_t i=0; i<idsz && i<dst[ind]; i++) {
		uint32_t* o = ids[i].op;
		if(o) {
			for(size_t j = 0; j < wc; j++) {
				if(j == ind) continue;
				if(o[j] != dst[j]) {
					o = NULL;
					break;
				}
			}
			if(o) {
				iddata a = ids[o[ind]], b = ids[dst[ind]];
				if(a.builtin == b.builtin && a.location == b.location && a.component == b.component) {
					ids[dst[ind]].map = i;
					return 0;
				}
			}
		}
	}

	// Otherwise, we set it up for comparisons later.
	ids[dst[ind]].op = dst;
	return wc;
}

uint32_t _vVvks_copy(uint32_t* src, uint32_t* dst,
	uint32_t idsz, iddata ids[], uint32_t shift) {

	uint32_t opwc = *src;
	SpvOp op = opwc & SpvOpCodeMask;
	uint32_t wc = opwc >> SpvWordCountShift;
	uint32_t rwc = 0;

	uint32_t* ssrc = src;
	uint32_t* sdst = dst;

	uint32_t last;
	uint32_t idres;
#define READ ( last = *src, src++, rwc++, last )
#define WRITE(W) ( *dst = W, dst++ )
#define BACK ( src--, rwc-- )
#define EOI ( rwc >= wc )

	WRITE(READ);	// Copy over the opcode + wordcnt
	switch(op) {]=]

for _,ins in ipairs(spv.instructions) do
	out('\tcase Spv%s: ', ins.opname)
	for i,o in ipairs(ins.operands or {}) do
		if o.kind == 'IdResult' then
			out('\t\tidres = ssrc[%d];', i)
			out('\t\tif(ids[idres+shift].map != idres+shift) return 0;')
			break
		end
	end
	if ins.opname == 'OpTypeInt' or ins.opname == 'OpTypeFloat' then
		-- Write down how many words this type uses, second operand
		out'\t\tids[idres+shift].numwords = 1+((ssrc[2]-1)/32);'
	end
	for i,arg in ipairs(ins.operands or {}) do
		if arg.quantifier == '*' then out('\twhile(!EOI) {')
		elseif arg.quantifier == '?' then out('\tif(!EOI) {')
		elseif arg.quantifier then
			error('Unhandled quantifier '..arg.quantifier) end
		handlers[arg.kind]{
			mightbe = arg.quantifier == '?',
			from = ins.opname..'_'..i
		}
		if arg.quantifier then out('\t}') end
	end
	out('\t\tbreak;')
end

out[[
	case SpvOpMax: break;
	};

	return wc;
}
]]
