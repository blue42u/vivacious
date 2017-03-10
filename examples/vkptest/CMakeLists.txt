add_executable(vkptest EXCLUDE_FROM_ALL
	main.c
	debug.c
	init.c
	swapchain.c
	window.c
	fbuff.c
)
target_link_libraries(vkptest vivacious)
