project(vivacious)
cmake_minimum_required(VERSION 3.0)

set(VULKAN_ENABLE ON CACHE BOOL "Enable Vulkan support")
set(VULKAN_INCLUDE_DIR "" CACHE PATH "Vulkan include directory")

include_directories(${VULKAN_INCLUDE_DIR})

add_subdirectory(src)
add_subdirectory(external)

string(REGEX REPLACE "([^;]+)" "src/\\1" SRC "${SRC}")
string(REGEX REPLACE "([^;]+)" "external/\\1" EXTERNAL "${EXTERNAL}")
add_library(vivacious ${SRC} ${EXTERNAL})

