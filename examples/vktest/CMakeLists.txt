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
