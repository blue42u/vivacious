set(GENS
	suptest.h)
set(CPS
	test.h)

foreach(G ${GENS})
	string(REPLACE ".h" ".lua" LG ${G})
	add_custom_command(OUTPUT ${G}
		COMMAND lua ${CMAKE_CURRENT_SOURCE_DIR}/${LG}
			${CMAKE_CURRENT_BINARY_DIR}/${G}
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
		MAIN_DEPENDENCY ${LG})
endforeach()

foreach(C ${CPS})
	add_custom_command(OUTPUT ${C}
		COMMAND ${CMAKE_COMMAND} -E copy
			${CMAKE_CURRENT_SOURCE_DIR}/${C}
			${CMAKE_CURRENT_BINARY_DIR}/${C}
		MAIN_DEPENDENCY ${C})
endforeach()

add_custom_target(include DEPENDS ${GENS} ${CPS})
