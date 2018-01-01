local f = io.open('core.h', 'w')
f:write[[
// Generated from apis/core.h.lua, do not edit
#ifndef H_vivacious_core
#define H_vivacious_core

#include <stdlib.h>
#include <stdbool.h>

#ifndef __GNUC__
#define __typeof__ typeof
#endif

#define Vv_LEN(...) sizeof(__VA_ARGS__)/sizeof((__VA_ARGS__)[0])
#define Vv_ARRAY(N, ...) .N##Cnt = Vv_LEN((__VA_ARGS__)), .N=(__VA_ARGS__)

#define VvMAGIC_FA_1(what, x, ...) what(x);
]]
local maxmagic = 100
for i=2,maxmagic do
	f:write('#define VvMAGIC_FA_'..i..'(what, x, ...) what(x); '
		..'VvMAGIC_FA_'..(i-1)..'(__VA_ARGS__)\n')
end
f:write'#define VvMAGIC_NA(...) VvMAGIC_AN(__VA_ARGS__'
for i=maxmagic,0,-1 do f:write(','..i) end
f:write')\n#define VvMAGIC_AN('
for i=1,maxmagic do f:write('_'..i..',') end
f:write[[N, ...) N

#define VvMAGIC_C(A, B) VvMAGIC_C2(A, B)
#define VvMAGIC_C2(A, B) A##B
#define VvMAGIC_FA(what, ...) VvMAGIC_C(VvMAGIC_FA_, \
VvMAGIC_NA(__VA_ARGS__))(what, __VA_ARGS__)

#define VvMAGIC_x(A) _x A
#define VvMAGIC(...) VvMAGIC_FA(VvMAGIC_x, __VA_ARGS__)

#endif
]]
f:close()
