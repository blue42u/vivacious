set(OUT ${CMAKE_BINARY_DIR}/include/vivacious)

gen(USE headerc OUTDIR ${CMAKE_BINARY_DIR}/include/vivacious SUFFIX .h
	SPECS vulkan vkinitializer
	TARGET include)

gen(USE docsmd OUTDIR ${CMAKE_BINARY_DIR}/docs SUFFIX .md
	SPECS vulkan vkinitializer
	TARGET docs)
