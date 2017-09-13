add_custom_command(OUTPUT pipeline.c
		COMMAND ${LUA_EXECUTABLE} pipeline.lua
			${CMAKE_CURRENT_BINARY_DIR}/pipeline.c
			${CMAKE_SOURCE_DIR}/include
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
		MAIN_DEPENDENCY pipeline.lua
		DEPENDS vert.spv frag.spv)

include_directories(${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_CURRENT_SOURCE_DIR})

add_executable(vkptest EXCLUDE_FROM_ALL
	main.c
	debug.c
	init.c
	swapchain.c
	window.c
	fbuff.c
	pipeline.c
)
target_link_libraries(vkptest vivacious)
