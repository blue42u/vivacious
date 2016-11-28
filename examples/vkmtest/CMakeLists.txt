add_executable(vkmtest EXCLUDE_FROM_ALL
	main.c
	debug.c
)
target_link_libraries(vkmtest vivacious)
