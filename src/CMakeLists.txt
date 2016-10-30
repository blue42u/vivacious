set(DIR
	lvulkan
)
set(SRC
	cpdl.c
	window/x.c
	window/xcb.c
	vkbplate.c
)
set(LUA
	vulkan.lua
)

foreach(D ${DIR})
	file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${D})
endforeach()

set(FULLSRC ${SRC})
foreach(L ${LUA})
	string(REPLACE ".lua" ".c" O ${L})
	add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${O}
		COMMAND lua ${L} ${CMAKE_CURRENT_BINARY_DIR}/${O}
			${CMAKE_SOURCE_DIR}/include
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
		MAIN_DEPENDENCY ${L})
	set(FULLSRC ${FULLSRC} ${CMAKE_CURRENT_BINARY_DIR}/${O})
endforeach()

include_directories(${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_CURRENT_SOURCE_DIR})

add_library(vivacious SHARED ${FULLSRC})
add_library(vivacious-static STATIC EXCLUDE_FROM_ALL ${FULLSRC})

if((UNIX AND NOT APPLE) OR CYGWIN)
	target_link_libraries(vivacious dl)
endif()

if(LUA_ENABLE)
	target_link_libraries(vivacious lua5.3)
endif()
