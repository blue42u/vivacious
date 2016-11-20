add_executable(vkbtest EXCLUDE_FROM_ALL
	main.c
	debug.c
)
target_link_libraries(vkbtest vivacious)

add_test(NAME build_vkb COMMAND "${CMAKE_COMMAND}" --build ${CMAKE_BINARY_DIR}
	--target vkbtest)
add_test(NAME vkb COMMAND $<TARGET_FILE:vkbtest>)
set_tests_properties(vkb PROPERTIES DEPENDS build_vkb)
