set(GENS
	vulkan.lua
)
set(CPS
	core.h
	window.h
	vkbplate.h
	vkmemory.h
	vkpipeline.h
	vivacious.h
)
set(ODEPS
	vk.xml
)

set(OUTPUT ${CMAKE_BINARY_DIR}/include/vivacious)
file(MAKE_DIRECTORY ${OUTPUT})

set(DEPS)

foreach(LG ${GENS})
	string(REPLACE ".lua" ".h" G ${LG})
	add_custom_command(OUTPUT ${OUTPUT}/${G}
		COMMAND ${LUA_EXECUTABLE} ${LG} ${OUTPUT}/${G} ${CMAKE_CURRENT_SOURCE_DIR}
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
		MAIN_DEPENDENCY ${LG}
		DEPENDS ${ODEPS})
	set(DEPS ${DEPS} ${OUTPUT}/${G})
endforeach()

foreach(C ${CPS})
	add_custom_command(OUTPUT ${OUTPUT}/${C}
		COMMAND ${CMAKE_COMMAND} -E copy ${C} ${OUTPUT}/${C}
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
		MAIN_DEPENDENCY ${C})
	set(DEPS ${DEPS} ${OUTPUT}/${C})
endforeach()

add_custom_command(OUTPUT ${CMAKE_BINARY_DIR}/include/libvivacious.h
	COMMAND ${CMAKE_COMMAND} -E copy libvivacious.h
		${CMAKE_BINARY_DIR}/include/libvivacious.h
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
	MAIN_DEPENDENCY ${CMAKE_CURRENT_SOURCE_DIR}/libvivacious.h)
set(DEPS ${DEPS} ${CMAKE_BINARY_DIR}/include/libvivacious.h)

add_custom_target(include DEPENDS ${DEPS})
