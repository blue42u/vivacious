add_executable(vkbtest EXCLUDE_FROM_ALL
	main.c
	debug.c
)
target_link_libraries(vkbtest vivacious)
