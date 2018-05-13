set(OUT ${CMAKE_BINARY_DIR}/include/vivacious)

gen(USE btest OUTDIR ${CMAKE_BINARY_DIR}/include/vivacious SUFFIX .md
	SPECS vulkan vkinitializer)
add_custom_target(include DEPENDS ${GEN_OUTS})
