set(OUT ${CMAKE_BINARY_DIR}/include/vivacious)

# Standard C headers, using the standard C header generator
gen(GENERATOR c DIRECTORY ${OUT} OUTPUTS ?.h
	SPECS test
)

# Vulkan Vv interface generator
#gen(cbound ${CMAKE_BINARY_DIR}/include/vivacious SUFFIXES ".h"
#	EXTRADEPS ${CMAKE_SOURCE_DIR}/external/vulkan.lua
#		${CMAKE_SOURCE_DIR}/external/vulkan-doc/src/spec/vk.xml
#	SPECS vulkan)

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
