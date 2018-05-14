set(OUT ${CMAKE_BINARY_DIR}/include/vivacious)

gen(USE headerc OUTDIR ${CMAKE_BINARY_DIR}/include/vivacious SUFFIX .h
	SPECS vulkan vkinitializer)
add_custom_target(include DEPENDS ${GEN_OUTS})
