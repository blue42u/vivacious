function(gen A_GEN A_OUT)
	cmake_parse_arguments(PARSE_ARGV 2 A "" "SUFFIXES" "EXTRAOUTS;EXTRADEPS;SPECS")
	file(MAKE_DIRECTORY ${A_OUT})
	set(SL ${CMAKE_CURRENT_SOURCE_DIR}/generator/stdlib.lua)
	foreach(S ${A_SPECS})
		set(S_OUTS)
		foreach(SS ${A_SUFFIXES})
			set(S_OUTS ${S_OUTS} ${A_OUT}/${S}${SS})
		endforeach()

		add_custom_command(OUTPUT ${S_OUTS}
			COMMAND ${LUA_EXECUTABLE} ${SL}
				${A_GEN} ${CMAKE_CURRENT_SOURCE_DIR} ${S}
			WORKING_DIRECTORY ${A_OUT}
			MAIN_DEPENDENCY generator/${A_GEN}.lua
			DEPENDS ${SL} ${S}.lua ${A_EXTRADEPS})
		set(MYOUTS ${MYOUTS} ${S_OUTS})
	endforeach()

	foreach(S ${A_EXTRAOUTS})
		set(OUTS ${OUTS} ${A_OUT}/${S})
	endforeach()

	add_custom_command(OUTPUT ${OUTS}
		COMMAND ${LUA_EXECUTABLE} ${SL}
			${A_GEN} ${CMAKE_CURRENT_SOURCE_DIR} finalize ${A_SPECS}
		WORKING_DIRECTORY ${A_OUT}
		MAIN_DEPENDENCY generator/${A_GEN}.lua
		DEPENDS ${SL} ${A_EXTRADEPS})

	set(ALLOUTS ${ALLOUTS} ${MYOUTS} ${OUTS} PARENT_SCOPE)
endfunction(gen)

# Standard C headers, using the standard C header generator
gen(c ${CMAKE_BINARY_DIR}/include/vivacious SUFFIXES ".h"
	EXTRAOUTS vivacious.h core.h
	SPECS test
)

# Vulkan Vv interface generator
#add_custom_command(OUTPUT ${B}/vulkan.h
#	COMMAND ${LUA_EXECUTABLE} ${SL} vulkan ${B} vulkan
#	generator/stdlib.lua c ${OUT} ${GEN_C}
#	WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
#	MAIN_DEPENDENCY generator/vulkan.lua
#	DEPENDS stdlib.lua vulkan.lua)

add_custom_target(include DEPENDS ${ALLOUTS})
