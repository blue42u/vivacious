add_executable(vulkantest
	vulkantest.c
	common.c
	window.c
	instdev.c
	debug.c
)
target_link_libraries(vulkantest vivacious)
