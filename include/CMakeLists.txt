set(GENS
	)
set(CPS
	)

if(VULKAN_ENABLE)
set(GENS ${GENS}
	vulkan.lua)
endif(VULKAN_ENABLE)

set(OUTPUT ${CMAKE_BINARY_DIR}/include/vivacious)
file(MAKE_DIRECTORY ${OUTPUT})

set(DEPS)

foreach(LG ${GENS})
	string(REPLACE ".lua" ".h" G ${LG})
	add_custom_command(OUTPUT ${OUTPUT}/${G}
		COMMAND lua ${LG} ${OUTPUT}/${G} ${CMAKE_CURRENT_SOURCE_DIR}
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
		MAIN_DEPENDENCY ${LG})
	set(DEPS ${DEPS} ${OUTPUT}/${G})
endforeach()

foreach(C ${CPS})
	add_custom_command(OUTPUT ${OUTPUT}/${C}
		COMMAND ${CMAKE_COMMAND} -E copy ${C} ${OUTPUT}/${C}
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
	set(DEPS ${DEPS} ${OUTPUT}/${C})
endforeach()

add_custom_target(include DEPENDS ${DEPS})
