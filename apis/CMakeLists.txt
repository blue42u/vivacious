set(OUT ${CMAKE_BINARY_DIR}/include/vivacious)

# Standard C headers, using the standard C header generator
gen(GENERATOR c VARIANTS bound DIRECTORY ${OUT} OUTPUTS ?.h
	SPECS vulkan devicememorypool rendergraph
)

# core.h, included by all the other headers and has VvMAGIC
add_custom_command(OUTPUT ${OUT}/core.h
	COMMAND ${LUA_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/core.h.lua
	WORKING_DIRECTORY ${OUT}
	MAIN_DEPENDENCY core.h.lua)

# vivacious.h, which includes all the other Vv headers
add_custom_command(OUTPUT ${OUT}/vivacious.h
	COMMAND ${LUA_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/vivacious.h.lua
		${GEN_SPECS}
	WORKING_DIRECTORY ${OUT}
	MAIN_DEPENDENCY vivacious.h.lua)

add_custom_target(include DEPENDS ${GEN_OUTS} ${OUT}/core.h ${OUT}/vivacious.h)
