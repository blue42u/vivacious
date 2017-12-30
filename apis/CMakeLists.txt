set(OUTDIR ${CMAKE_BINARY_DIR}/include/vivacious)
set(SL ${CMAKE_CURRENT_SOURCE_DIR}/generator/stdlib.lua)
function(gen A_GEN)
	cmake_parse_arguments(PARSE_ARGV 1 A "" "SUFFIXES" "EXTRAOUTS;EXTRADEPS;SPECS")
	file(MAKE_DIRECTORY ${OUTDIR})
	foreach(S ${A_SPECS})
		add_custom_command(OUTPUT ${OUTDIR}/${S}.h
			COMMAND ${LUA_EXECUTABLE} ${SL}
				${A_GEN} ${CMAKE_CURRENT_SOURCE_DIR} ${S}
			WORKING_DIRECTORY ${OUTDIR}
			MAIN_DEPENDENCY generator/${A_GEN}.lua
			DEPENDS ${SL} ${S}.lua ${A_EXTRADEPS})
		set(MYOUTS ${MYOUTS} ${OUTDIR}/${S}.h)
	endforeach()
	set(ALLOUTS ${ALLOUTS} ${MYOUTS} PARENT_SCOPE)
endfunction(gen)

# Standard C headers, using the standard C header generator
gen(c ${CMAKE_BINARY_DIR}/include/vivacious SUFFIXES ".h"
	EXTRAOUTS vivacious.h core.h
	SPECS test
)

# Vulkan Vv interface generator
#gen(cbound ${CMAKE_BINARY_DIR}/include/vivacious SUFFIXES ".h"
#	EXTRADEPS ${CMAKE_SOURCE_DIR}/external/vulkan.lua
#		${CMAKE_SOURCE_DIR}/external/vulkan-doc/src/spec/vk.xml
#	SPECS vulkan)

add_custom_command(OUTPUT ${OUTDIR}/vivacious.h ${OUTDIR}/core.h
	COMMAND ${LUA_EXECUTABLE} ${SL}
		c ${CMAKE_CURRENT_SOURCE_DIR} finalize ${A_SPECS}
	WORKING_DIRECTORY ${OUTDIR}
	MAIN_DEPENDENCY generator/c.lua
	DEPENDS ${SL} ${A_EXTRADEPS})

add_custom_target(include DEPENDS ${ALLOUTS})
