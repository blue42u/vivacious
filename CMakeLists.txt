project(vivacious)
cmake_minimum_required(VERSION 3.0)

if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.3")
	# Silence an odd error. It turns out that setting the visibility does
	# not change the static compile, and the executables are not libraries.
	# All the non-static non-API functions are prefixed with _vV, so this
	# *shouldn't* cause any issues with an earlier CMake.
	cmake_policy(SET CMP0063 NEW)
endif()

set(VULKAN_ENABLE ON CACHE BOOL "Enable Vulkan support")
set(VULKAN_INCLUDE_DIR "" CACHE PATH "Vulkan include directory")

set(LUA_ENABLE ON CACHE BOOL "Enable Lua support")
set(LUA_INCLUDE_DIR "" CACHE PATH "Lua include directory")
set(LUA_LIB "lua5.3" CACHE PATH "Lua library")
set(LUA_EXECUTABLE "lua" CACHE PATH "Lua executable command")

set(X_ENABLE ON CACHE BOOL "Enable X support")
set(X_INCLUDE_DIR "" CACHE PATH "X include directory")
if(WIN32 OR CYGWIN)
	set(X_ENABLE OFF)
endif()

include_directories(
	${VULKAN_INCLUDE_DIR}
	${LUA_INCLUDE_DIR}
	${X_INCLUDE_DIR}
	${CMAKE_BINARY_DIR}/include)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

if(VULKAN_ENABLE)
add_definitions(-DVv_ENABLE_VULKAN)
endif(VULKAN_ENABLE)

if(LUA_ENABLE)
add_definitions(-DVv_ENABLE_LUA)
endif(LUA_ENABLE)

if(X_ENABLE)
add_definitions(-DVv_ENABLE_X)
endif(X_ENABLE)

set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_C_STANDARD 99)

add_definitions(-DVv_VERSION_MAJOR=0 -DVv_VERSION_MINOR=1 -DVv_VERSION_PATCH=0)

add_subdirectory(include)
add_subdirectory(src)
add_subdirectory(examples)

add_dependencies(vivacious include)
