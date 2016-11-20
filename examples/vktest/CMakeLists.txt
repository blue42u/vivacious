add_executable(vktest EXCLUDE_FROM_ALL
	vulkantest.c
	common.c
	window.c
	instdev.c
	debug.c
	swapchain.c
	cbuffers.c
)
target_link_libraries(vktest vivacious)

add_test(NAME build_vk COMMAND "${CMAKE_COMMAND}" --build ${CMAKE_BINARY_DIR}
	--target vktest)
add_test(NAME vk COMMAND $<TARGET_FILE:vktest>)
set_tests_properties(vk PROPERTIES DEPENDS build_vk)
