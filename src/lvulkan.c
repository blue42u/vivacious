/**************************************************************************
   Copyright 2016 Jonathon Anderson

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
***************************************************************************/

#if defined(Vv_ENABLE_VULKAN) && defined(Vv_ENABLE_LUA)

// This file puts together the pieces of the Lua-Vulkan binding in
// lvulkan-*.lua. As such, this file defines a few common things.

#include <stdlib.h>	// For malloc

#include "lua.h"	// For Lua
#include "vivacious/vulkan.h"	// For Vulkan

typedef const char* string;	// Abstract char* into string, helps array params

// Many of the files will define function-like macros. These macros
// are of three varieties: size_*, to_*, push_*

// size_* macros return the total size of the object on top of the stack.
// Use: size_<type>((lua_State*)L);
#define size_string(L) sizeof(const string)
#define size_float(L) sizeof(float)
#define size_uint8_t(L) sizeof(uint8_t)
#define size_uint32_t(L) sizeof(uint32_t)
#define size_uint64_t(L) sizeof(uint64_t)
#define size_int32_t(L) sizeof(int32_t)
#define size_size_t(L) sizeof(size_t)
#define size_VkBool32(L) sizeof(VkBool32)
#define size_VkDeviceSize(L) sizeof(VkDeviceSize)

// to_* macros convert a compatible Lua object into the C type. They also
// return a pointer to the space after the C object, in its full form.
// Use: to_<type>((lua_State*)L, (<type>*)ref);
#define to_BASE(L, R, T, V) ({ \
	*(T*)(R) = (V); \
	(void*)(R)+sizeof(T); \
})
#define to_string(L, R) to_BASE(L, R, string, luaL_optstring(L, -1, NULL))
#define to_float(L, R) to_BASE(L, R, float, luaL_optnumber(L, -1, 0))
#define to_uint8_t(L, R) to_BASE(L, R, uint8_t, luaL_optinteger(L, -1, 0))
#define to_uint32_t(L, R) to_BASE(L, R, uint32_t, luaL_optinteger(L, -1, 0))
#define to_uint64_t(L, R) to_BASE(L, R, uint64_t, luaL_optinteger(L, -1, 0))
#define to_int32_t(L, R) to_BASE(L, R, int32_t, luaL_optinteger(L, -1, 0))
#define to_size_t(L, R) to_BASE(L, R, size_t, luaL_optinteger(L, -1, 0))
#define to_VkBool32(L, R) to_BASE(L, R, VkBool32, lua_toboolean(L, -1))
#define to_VkDeviceSize(L, R) to_BASE(L, R, VkDeviceSize, \
	luaL_optinteger(L, -1, 0))

// push_* macros convert a C type into a suitable Lua object.
// Use: push_<type>((lua_State*)L, (<type>*)data)
#define push_string(L, D) lua_pushstring(L, *(const string*)(D))
#define push_float(L, D) lua_pushnumber(L, *(float*)(D))
#define push_uint8_t(L, D) lua_pushinteger(L, *(uint8_t*)(D))
#define push_uint32_t(L, D) lua_pushinteger(L, *(uint32_t*)(D))
#define push_uint64_t(L, D) lua_pushinteger(L, *(uint64_t*)(D))
#define push_int32_t(L, D) lua_pushinteger(L, *(int32_t*)(D))
#define push_size_t(L, D) lua_pushinteger(L, *(size_t*)(D))
#define push_VkBool32(L, D) lua_pushboolean(L, *(VkBool32*)(D))
#define push_VkDeviceSize(L, D) lua_pushinteger(L, *(VkDeviceSize*)(D))

// These are the odd types that are only used a few places, but make a mess
#define size_PFN_vkAllocationFunction(L) sizeof(PFN_vkAllocationFunction)
#define size_PFN_vkReallocationFunction(L) sizeof(PFN_vkReallocationFunction)
#define size_PFN_vkFreeFunction(L) sizeof(PFN_vkFreeFunction)
#define size_PFN_vkInternalAllocationNotification(L) sizeof(PFN_vkInternalAllocationNotification)
#define size_PFN_vkInternalFreeNotification(L) sizeof(PFN_vkInternalFreeNotification)
#define size_PFN_vkDebugReportCallbackEXT(L) sizeof(PFN_vkDebugReportCallbackEXT)
#define to_PFN_vkAllocationFunction(L, R) to_BASE(L, R, \
	PFN_vkAllocationFunction, NULL)
#define to_PFN_vkReallocationFunction(L, R) to_BASE(L, R, \
	PFN_vkReallocationFunction, NULL)
#define to_PFN_vkFreeFunction(L, R) to_BASE(L, R, \
	PFN_vkFreeFunction, NULL)
#define to_PFN_vkInternalAllocationNotification(L, R) to_BASE(L, R, \
	PFN_vkInternalAllocationNotification, NULL)
#define to_PFN_vkInternalFreeNotification(L, R) to_BASE(L, R, \
	PFN_vkInternalFreeNotification, NULL)
#define to_PFN_vkDebugReportCallbackEXT(L, R) to_BASE(L, R, \
	PFN_vkDebugReportCallbackEXT, NULL)
#define push_PFN_vkAllocationFunction(L, R) lua_pushnil(L)
#define push_PFN_vkReallocationFunction(L, R) lua_pushnil(L)
#define push_PFN_vkFreeFunction(L, R) lua_pushnil(L)
#define push_PFN_vkInternalAllocationNotification(L, R) lua_pushnil(L)
#define push_PFN_vkInternalFreeNotification(L, R) lua_pushnil(L)
#define push_PFN_vkDebugReportCallbackEXT(L, R) lua_pushnil(L)
#define push_void(L, R) lua_pushnil(L)

// This is particular is an odd type. This seems the best way to handle it.
#define size_VkSampleMask(L) sizeof(VkSampleMask)
#define push_VkSampleMask(L, R) ({ \
	VkSampleMask v = *(VkSampleMask*)R; \
	lua_newtable(L); \
	for(int i=0; i<32; i++) { \
		lua_pushboolean(L, v & (1<<i)); \
		lua_seti(L, -2, i+1); \
	} \
})

#define IN_LVULKAN

#include "lvulkan-enum.c"	// Handles enums (VkStructureType, etc.)
#include "lvulkan-bitmask.c"	// Handles bitmasks (VkQueueFlags, etc.)
#include "lvulkan-handle.c"	// Handles the handles (VkInstance, etc.)
#include "lvulkan-struct.c"	// Handles the structs (VkSubmitInfo, etc.)
#include "lvulkan-union.c"	// Handles the unions (VkClearValue, etc.)
#include "lvulkan-test.c"	// Compile-time test, for testing

// TMP: To keep link errors away!
void loadLVulkan(lua_State* L) { lua_pushnil(L); }

#endif
