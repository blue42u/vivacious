set(GENS
	suptest.h)
set(CPS
	test.h)

set(OUTPUT ${CMAKE_BINARY_DIR}/include/vivacious)

add_custom_target(include_dir
	${CMAKE_COMMAND} -E make_directory ${OUTPUT})

foreach(G ${GENS})
	string(REPLACE ".h" ".lua" LG ${G})
	add_custom_command(OUTPUT ${G}
		COMMAND lua ${LG} ${OUTPUT}/${G}
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
		MAIN_DEPENDENCY ${LG}
		DEPENDS include_dir)
endforeach()

foreach(C ${CPS})
	add_custom_command(OUTPUT ${C}
		COMMAND ${CMAKE_COMMAND} -E copy
			${CMAKE_CURRENT_SOURCE_DIR}/${C}
			${OUTPUT}/${C}
		DEPENDS include_dir)
endforeach()

add_custom_target(include DEPENDS ${GENS} ${CPS})
