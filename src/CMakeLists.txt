set(SRC
	cpdl.c
	window/x.c
	window/xcb.c
	window/default.c
	vulkan/default.c
	vkbplate/test.c
	vkbplate/default.c
	vkmemory/test.c
	vkmemory/default.c
	vkpipeline/test.c
	vkpipeline/default.c
)
set(HEADS
	libvivacious.h
)
set(LUA
	vulkan/libdl.lua
)
set(LDEPS
	${CMAKE_CURRENT_SOURCE_DIR}/../external/vulkan.lua
	${CMAKE_CURRENT_SOURCE_DIR}/../external/slaxdom.lua
	${CMAKE_CURRENT_SOURCE_DIR}/../external/slaxml.lua
	${CMAKE_CURRENT_SOURCE_DIR}/../external/traversal.lua
	${CMAKE_CURRENT_SOURCE_DIR}/../external/vulkan-docs/src/spec/vk.xml
)

set(FULLSRC ${SRC})
foreach(L ${LUA})
	string(REPLACE ".lua" ".c" O ${L})
	get_filename_component(DIR ${L} DIRECTORY)
	file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${DIR})
	add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${O}
		COMMAND ${LUA_EXECUTABLE} ${L} ${CMAKE_CURRENT_BINARY_DIR}/${O}
			${CMAKE_SOURCE_DIR}/include
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
		MAIN_DEPENDENCY ${L}
		DEPENDS ${LDEPS})
	set(FULLSRC ${FULLSRC} ${CMAKE_CURRENT_BINARY_DIR}/${O})
endforeach()

set(OHEADS)
foreach(H ${HEADS})
	set(OHEADS ${OHEADS} ${CMAKE_BINARY_DIR}/include/${H})
endforeach()
add_custom_command(OUTPUT ${OHEADS}
	COMMAND ${CMAKE_COMMAND} -E copy ${HEADS} ${CMAKE_BINARY_DIR}/include
	DEPENDS ${HEADS}
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

include_directories(${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_CURRENT_SOURCE_DIR})

add_library(vivacious SHARED ${FULLSRC})
add_library(vivacious-static STATIC EXCLUDE_FROM_ALL ${FULLSRC})

add_custom_target(src-lua DEPENDS ${LUA})
add_dependencies(vivacious src-lua)
add_dependencies(vivacious-static src-lua)

if((UNIX AND NOT APPLE) OR CYGWIN)
	target_link_libraries(vivacious dl)
endif()

if(LUA_ENABLE)
	target_link_libraries(vivacious ${LUA_LIB})
endif()
