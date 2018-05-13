set(OUT ${CMAKE_BINARY_DIR}/include/vivacious)

# Standard C headers, using the standard C header generator
#gen(GENERATOR generator/c DIRECTORY ${OUT} OUTPUTS ?.h
#	SPECS vulkan window devicememorypool rendergraph shaderbank vkinitializer
#)

# core.h, included by all the other headers and has VvMAGIC
#add_custom_command(OUTPUT ${OUT}/core.h
#	COMMAND ${LUA_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/core.h.lua
#	WORKING_DIRECTORY ${OUT}
#	MAIN_DEPENDENCY core.h.lua)

# vivacious.h, which includes all the other Vv headers
#add_custom_command(OUTPUT ${OUT}/vivacious.h
#	COMMAND ${LUA_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/vivacious.h.lua
#		${GEN_SPECS}
#	WORKING_DIRECTORY ${OUT}
#	MAIN_DEPENDENCY vivacious.h.lua)

#add_custom_target(include DEPENDS ${GEN_OUTS} ${OUT}/core.h ${OUT}/vivacious.h)

add_custom_command(OUTPUT ${OUT}/vkinitializer.md
	COMMAND ${LUA_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/core/btest.lua vkinitializer ${OUT}
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
	DEPENDS core/btest.lua vkinitializer.lua)

add_custom_command(OUTPUT ${OUT}/vulkan.md
	COMMAND ${LUA_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/core/btest.lua vulkan ${OUT}
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
	DEPENDS core/btest.lua vulkan.lua)

add_custom_target(include DEPENDS ${OUT}/vkinitializer.md ${OUT}/vulkan.md)
