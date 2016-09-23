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

// size_* macros add up the EXTRA ALLOCATED size for the object on top.
// This is just the extra; the sizeof the type is factored in already.
// Use: size_<type>((lua_State*)L, (var size_t)total);
#define size_string(L, O)
#define size_float(L, O)
#define size_uint8_t(L, O)
#define size_uint32_t(L, O)
#define size_uint64_t(L, O)
#define size_int32_t(L, O)
#define size_size_t(L, O)
#define size_VkBool32(L, O)
#define size_VkDeviceSize(L, O)

// to_* macros convert a compatible Lua object into the C type. They also
// return a pointer to the space after the C object, in its full form.
// ref is a variable pointing to the next space not used by something else in a
// memory allocation the size of size_<type>(L). Only used by compound types.
// Use: to_<type>((lua_State*)L, (<type>)datum, (var void*)ref);
#define to_string(L, D, R) ({ (D) = luaL_checkstring(L, -1); })
#define to_float(L, D, R) ({ (D) = luaL_checknumber(L, -1); })
#define to_uint8_t(L, D, R) ({ (D) = luaL_checkinteger(L, -1); })
#define to_uint32_t(L, D, R) to_uint8_t(L, D, R)
#define to_uint64_t(L, D, R) to_uint8_t(L, D, R)
#define to_int32_t(L, D, R) to_uint8_t(L, D, R)
#define to_size_t(L, D, R) to_uint8_t(L, D, R)
#define to_VkBool32(L, D, R) ({ (D) = lua_toboolean(L, -1); })
#define to_VkDeviceSize(L, D, R) to_uint8_t(L, D, R)

// push_* macros convert a C type into a suitable Lua object.
// Use: push_<type>((lua_State*)L, (<type>)data)
#define push_string(L, D) lua_pushstring(L, (D))
#define push_float(L, D) lua_pushnumber(L, (D))
#define push_uint8_t(L, D) lua_pushinteger(L, (D))
#define push_uint32_t(L, D) lua_pushinteger(L, (D))
#define push_uint64_t(L, D) lua_pushinteger(L, (D))
#define push_int32_t(L, D) lua_pushinteger(L, (D))
#define push_size_t(L, D) lua_pushinteger(L, (D))
#define push_VkBool32(L, D) lua_pushboolean(L, (D))
#define push_VkDeviceSize(L, D) lua_pushinteger(L, (D))

// Now for some more interesting types. These are PFNs that Lua shouldn't have.
#define size_PFN_vkAllocationFunction(L, O)
#define size_PFN_vkReallocationFunction(L, O)
#define size_PFN_vkFreeFunction(L, O)
#define to_PFN_vkAllocationFunction(L, R) ({ (D) = NULL; })
#define to_PFN_vkReallocationFunction(L, R) ({ (D) = NULL; })
#define to_PFN_vkFreeFunction(L, R) ({ (D) = NULL; })
#define push_PFN_vkAllocationFunction(L, D) lua_pushnil(L)
#define push_PFN_vkReallocationFunction(L, D) lua_pushnil(L)
#define push_PFN_vkFreeFunction(L, D) lua_pushnil(L)

// These are PFNs that Lua could care about. TODO: Handle these
#define size_PFN_vkInternalAllocationNotification(L, O)
#define size_PFN_vkInternalFreeNotification(L, O)
#define size_PFN_vkDebugReportCallbackEXT(L, O)
#define to_PFN_vkInternalAllocationNotification(L, R) ({ (D) = NULL; })
#define to_PFN_vkInternalFreeNotification(L, R) ({ (D) = NULL; })
#define to_PFN_vkDebugReportCallbackEXT(L, R) ({ (D) = NULL; })
#define push_PFN_vkInternalAllocationNotification(L, D) lua_pushnil(L)
#define push_PFN_vkInternalFreeNotification(L, D) lua_pushnil(L)
#define push_PFN_vkDebugReportCallbackEXT(L, D) lua_pushnil(L)

// This a special bitmask. TODO: Decide whether to just use Lua's bitwise...
#define size_VkSampleMask(L) sizeof(VkSampleMask)
#define push_VkSampleMask(L, D) ({ \
	lua_newtable(L); \
	for(int i=0; i<32; i++) { \
		lua_pushboolean(L, (D) & (1<<i)); \
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
