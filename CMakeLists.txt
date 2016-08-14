project(vivacious)
cmake_minimum_required(VERSION 3.0)

set(VULKAN_ENABLE ON CACHE BOOL "Enable Vulkan support")
set(VULKAN_INCLUDE_DIR "" CACHE PATH "Vulkan include directory")

include_directories(
	${VULKAN_INCLUDE_DIR}
	${CMAKE_BINARY_DIR}/include)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

if(VULKAN_ENABLE)
add_definitions(-DvV_ENABLE_VULKAN)
endif(VULKAN_ENABLE)

add_subdirectory(include)
add_subdirectory(src)
add_subdirectory(examples)

add_dependencies(vivacious include)
