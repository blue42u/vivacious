configure_file(vivacious.h ${CMAKE_BINARY_DIR}/include/vivacious/vivacious.h)

gen(USE core/headerc OUTDIR ${CMAKE_BINARY_DIR}/include/vivacious SUFFIX .h
	SPECS vulkan vkinitializer
	TARGET include ALL)

gen(USE core/docsmd OUTDIR ${CMAKE_BINARY_DIR}/docs SUFFIX .md
	SPECS vulkan vkinitializer
	TARGET docs ALL)
