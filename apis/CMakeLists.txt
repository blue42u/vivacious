function(gen GEN OUT SUFF EOUTS EDEPS)
	file(MAKE_DIRECTORY ${OUT})
	foreach(S ${ARGN})
		set(OUTS ${OUTS} ${OUT}/${S}${SUFF})
		set(DEPS ${DEPS} ${S}.lua)
	endforeach()
	foreach(S ${EOUTS})
		set(OUTS ${OUTS} ${OUT}/${S}${SUFF})
	endforeach()
	add_custom_command(OUTPUT ${OUTS}
		COMMAND ${LUA_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/stdlib.lua
			${GEN} ${CMAKE_SOURCE_DIR}/apis ${ARGN}
		WORKING_DIRECTORY ${OUT}
		MAIN_DEPENDENCY generator/${GEN}.lua
		DEPENDS stdlib.lua ${DEPS} ${EDEPS})
	set(ALLOUTS ${ALLOUTS} ${OUTS} PARENT_SCOPE)
endfunction(gen)

# Standard C headers, using the standard C header generator
gen(c ${CMAKE_BINARY_DIR}/include/vivacious .h	"vivacious;core" ""
	test
)

# Vulkan Vv interface generator
#add_custom_command(OUTPUT ${B}/vulkan.h
#	COMMAND ${LUA_EXECUTABLE} ${SL} vulkan ${B} vulkan
#	generator/stdlib.lua c ${OUT} ${GEN_C}
#	WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
#	MAIN_DEPENDENCY generator/vulkan.lua
#	DEPENDS stdlib.lua vulkan.lua)

add_custom_target(include DEPENDS ${ALLOUTS})
