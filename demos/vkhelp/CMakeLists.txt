set(SHADERS)
function(glsl stage name)
add_custom_command(OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/${name}.spv
		COMMAND glslangValidator -V
			-o ${CMAKE_CURRENT_SOURCE_DIR}/${name}.spv
			${CMAKE_CURRENT_SOURCE_DIR}/${name}.${stage}
		MAIN_DEPENDENCY ${name}.${stage})
set(SHADERS ${SHADERS} ${CMAKE_CURRENT_SOURCE_DIR}/${name}.spv PARENT_SCOPE)
endfunction(glsl)

glsl(vert load)
glsl(vert small)
glsl(vert base)
glsl(vert recolor)
glsl(frag render)

add_custom_command(OUTPUT shaders.h
		COMMAND ${LUA_EXECUTABLE}
			${CMAKE_CURRENT_SOURCE_DIR}/shaders.lua
			${CMAKE_CURRENT_BINARY_DIR}/shaders.h
			${CMAKE_SOURCE_DIR}/include
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
		MAIN_DEPENDENCY shaders.lua
		DEPENDS ${SHADERS})
add_custom_target(vkhelp-demo-lua DEPENDS shaders.h)

include_directories(${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_CURRENT_SOURCE_DIR})

add_executable(vkhelp-demo EXCLUDE_FROM_ALL
	main.c
	debug.c
)
add_dependencies(vkhelp-demo vkhelp-demo-lua)
target_link_libraries(vkhelp-demo vivacious)
