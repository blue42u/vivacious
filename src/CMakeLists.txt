set(SRC
	test.c)
set(LUA
	suptest.lua)

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

add_library(vivacious SHARED ${FULLSRC})
add_library(vivacious-static STATIC EXCLUDE_FROM_ALL ${FULLSRC})
