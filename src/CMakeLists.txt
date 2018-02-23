set(SRC
	cpdl.c
	window/x.c
	window/xcb.c
	window/default.c
	vulkan/default.c
	vkinitializer/test.c
	vkinitializer/default.c
	vkmemory/test.c
	vkmemory/default.c
	vkpipeline/test.c
	vkpipeline/default.c
	vkshader/test.c
	vkshader/default.c
	vkshader/mcopy-idshift.c
)
set(HEADS
	libvivacious.h
)

gen(GENERATOR vulkan/libdl OUTPUTS ${CMAKE_CURRENT_BINARY_DIR}/?.c SPECS vulkan)

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/vkshader)
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/vkshader/mcopy-idshift.c
	COMMAND ${LUA_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/vkshader/mcopy-idshift.c.lua
		${CMAKE_SOURCE_DIR}/external
	WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/vkshader
	MAIN_DEPENDENCY vkshader/mcopy-idshift.c.lua)
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/vkshader/sections.h
	COMMAND ${LUA_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/vkshader/sections.h.lua
		${CMAKE_SOURCE_DIR}/external
	WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/vkshader
	MAIN_DEPENDENCY vkshader/sections.h.lua)

include_directories(${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_CURRENT_SOURCE_DIR}
	${CMAKE_SOURCE_DIR}/external/spirv/include)

add_library(vivacious SHARED ${SRC} ${GEN_OUTS})
add_library(vivacious-static STATIC EXCLUDE_FROM_ALL ${SRC} ${GEN_OUTS})

#add_custom_target(src-lua DEPENDS ${LUA})
#add_dependencies(vivacious src-lua)
#add_dependencies(vivacious-static src-lua)

if((UNIX AND NOT APPLE) OR CYGWIN)
	target_link_libraries(vivacious dl)
endif()
