project(vivacious)
cmake_minimum_required(VERSION 3.0)

if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.3")
	# Silence an odd error. It turns out that setting the visibility does
	# not change the static compile, and the executables are not libraries.
	# All the non-static non-API functions are prefixed with _vV, so this
	# *shouldn't* cause any issues with an earlier CMake.
	cmake_policy(SET CMP0063 NEW)
endif()

# Vulkan options
set(VULKAN_ENABLE ON CACHE BOOL "Enable Vulkan support")
set(VULKAN_INCLUDE_DIR "" CACHE PATH "Vulkan include directory")

# Lua options
set(LUA_ENABLE ON CACHE BOOL "Enable Lua support")
set(LUA_INCLUDE_DIR "" CACHE PATH "Lua include directory")
set(LUA_LIB "lua5.3" CACHE PATH "Lua library")
set(LUA_EXECUTABLE "lua5.3" CACHE PATH "Lua executable command")

# XCB options
set(X_ENABLE ON CACHE BOOL "Enable X support")
set(X_INCLUDE_DIR "" CACHE PATH "X include directory")
if(WIN32 OR CYGWIN)
	set(X_ENABLE OFF)
endif()

# Include it all
include_directories(
	${VULKAN_INCLUDE_DIR}
	${LUA_INCLUDE_DIR}
	${X_INCLUDE_DIR}
	${CMAKE_BINARY_DIR}/include)

# Set the output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# Add the usual compile-time definitions
if(VULKAN_ENABLE)
add_definitions(-DVv_ENABLE_VULKAN)
endif(VULKAN_ENABLE)

if(LUA_ENABLE)
add_definitions(-DVv_ENABLE_LUA)
endif(LUA_ENABLE)

if(X_ENABLE)
add_definitions(-DVv_ENABLE_X)
endif(X_ENABLE)

# A few CMake settings
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_C_STANDARD 99)

add_definitions(-DVv_VERSION_MAJOR=0 -DVv_VERSION_MINOR=1 -DVv_VERSION_PATCH=2)

# Generation helper function
function(gen)
	cmake_parse_arguments(PARSE_ARGV 0 A
		""
		"USE;OUTDIR;SUFFIX"
		"DEPENDS;SPECS")
	if(A_OUTDIR)
		file(MAKE_DIRECTORY ${A_OUTDIR})
	else()
		set(A_OUTDIR ${CMAKE_CURRENT_BINARY_DIR})
	endif()
	set(GN ${CMAKE_SOURCE_DIR}/apis/core/${A_USE}.lua)
	set(SL ${CMAKE_SOURCE_DIR}/apis/core/generation.lua ${GN})
	foreach(S ${A_SPECS})
		set(S_OUT ${A_OUTDIR}/${S}${A_SUFFIX})
		set(S_DEPS ${SL})
		if(S MATCHES vulkan)
			set(S_DEPS ${S_DEPS}
				${CMAKE_SOURCE_DIR}/external/vulkan.lua
				${CMAKE_SOURCE_DIR}/external/slaxdom.lua
				${CMAKE_SOURCE_DIR}/external/slaxml.lua
				${CMAKE_SOURCE_DIR}/external/traversal.lua
				${CMAKE_SOURCE_DIR}/external/vulkan-docs/src/spec/vk.xml
			)
		endif()
		add_custom_command(OUTPUT ${S_OUT}
			COMMAND ${LUA_EXECUTABLE} ${GN} ${S} ${A_OUTDIR}
			WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
			MAIN_DEPENDENCY ${CMAKE_SOURCE_DIR}/apis/${S}.lua
			DEPENDS ${A_DEPENDS} ${S_DEPS})
		set(MYOUTS ${MYOUTS} ${S_OUT})
	endforeach()
	set(GEN_OUTS ${GEN_OUTS} ${MYOUTS} PARENT_SCOPE)
	set(GEN_SPECS ${GEN_SPECS} ${A_SPECS} PARENT_SCOPE)
endfunction(gen)

# And the real meat
add_subdirectory(apis)
add_subdirectory(src)
add_subdirectory(demos)

add_dependencies(vivacious include)
