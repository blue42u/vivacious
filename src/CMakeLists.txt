set(SRC
	test.c)
add_library(vivacious SHARED ${SRC})
add_library(vivacious-static STATIC ${SRC})
