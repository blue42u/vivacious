/**************************************************************************
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
***************************************************************************/

#include <vivacious/vulkan.h>
#include "spirv/1.2/spirv.h"
#include <stdbool.h>

typedef struct {
	bool defined;
	uint32_t map;
	size_t numwords;
	uint32_t* op;
	uint32_t builtin, location, component;
} iddata;
#define DEF_iddata(i) (iddata){false, i, 0, NULL, -1, -1, 0};

// Scans a single instruction. Pre-pass, and *dst is a temp space that may
// be used for iddata.op.
uint32_t _vVvks_scan(uint32_t* src, uint32_t* dst,
	uint32_t idsz, iddata ids[], uint32_t shift);

// Copys a single instruction from *src to *dst, shifting the IDs
// by shift along the way.
uint32_t _vVvks_copy(uint32_t* src, uint32_t* dst,
	uint32_t idsz, iddata ids[], uint32_t shift);
