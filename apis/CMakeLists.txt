gen(USE headerc OUTDIR ${CMAKE_BINARY_DIR}/include/vivacious SUFFIX .h
	SPECS vulkan vkinitializer
	TARGET include)

gen(USE docsmd OUTDIR ${CMAKE_BINARY_DIR}/docs SUFFIX .md
	SPECS vulkan vkinitializer
	TARGET docs)

include_directories(${CMAKE_BINARY_DIR}/include)
add_definitions("-ferror-limit=1000")
add_executable(inctest test.c)
