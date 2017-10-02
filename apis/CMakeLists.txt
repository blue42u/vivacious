set(APIS
	vkbplate
	vkmemory
	vkpipeline
	vulkan
	window
	vkshader
)

set(OUT ${CMAKE_BINARY_DIR}/include/vivacious)
file(MAKE_DIRECTORY ${OUT})

set(OUTS ${OUT}/core.h ${OUT}/vivacious.h)
set(DEPS generator/stdc.lua apis.lua ../external/vulkan.lua)
foreach(A ${APIS})
	set(OUTS ${OUTS} ${OUT}/${A}.h)
	set(DEPS ${DEPS} ${A}.lua)
endforeach()

add_custom_command(OUTPUT ${OUTS}
	COMMAND ${LUA_EXECUTABLE} generator/c.lua ${OUT}
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
	MAIN_DEPENDENCY generator/c.lua
	DEPENDS ${DEPS})

add_custom_target(include DEPENDS ${OUTS})
