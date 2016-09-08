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

typedef char* string;	// Abstract char* into string, helps array params

// Many of the files will define function-like macros. These macros
// are of six varieties: setup_*, to_*, alloc_*, fill_*, free_* and push_*

// setup_* macros define the needed sub-types for the type in question.
// Use: setup_<type>((<type>)ref, pathname);
#define setup_string(R, P)
#define setup_float(R, P)
#define setup_uint8_t(R, P)
#define setup_uint32_t(R, P)
#define setup_uint64_t(R, P)
#define setup_int32_t(R, P)
#define setup_size_t(R, P)
#define setup_VkBool32(R, P)
#define setup_VkDeviceSize(R, P)

// to_* macros convert a compatible Lua object into the C type.
// Use: to_<type>((lua_State*)L, (<type>)data, pathname);
#define to_string(L, D, P) ({ (D) = luaL_checkstring(L, -1); })
#define to_float(L, D, P) ({ (D) = luaL_checknumber(L, -1); })
#define to_uint8_t(L, D, P) ({ (D) = luaL_checkinteger(L, -1); })
#define to_uint32_t(L, D, P) to_uint8_t(L, D, P)
#define to_uint64_t(L, D, P) to_uint8_t(L, D, P)
#define to_int32_t(L, D, P) to_uint8_t(L, D, P)
#define to_size_t(L, D, P) to_uint8_t(L, D, P)
#define to_VkBool32(L, D, P) ({ (D) = lua_toboolean(L, -1); })
#define to_VkDeviceSize(L, D, P) to_uint8_t(L, D, P)

// free_* macros free any extra data that the corrosponding to_* alloc'd.
// Use: free_<type>((<type>)data, pathname);
#define free_string(R, P)
#define free_float(R, P)
#define free_uint8_t(R, P)
#define free_uint32_t(R, P)
#define free_uint64_t(R, P)
#define free_int32_t(R, P)
#define free_size_t(R, P)
#define free_VkBool32(R, P)
#define free_VkDeviceSize(R, P)

// push_* macros convert a C type into a suitable Lua object.
// Use: push_<type>((lua_State*)L, (<type>)data)
#define push_string(L, D) lua_pushstring(L, (D))
#define push_float(L, D) lua_pushnumber(L, (D))
#define push_uint8_t(L, D) lua_pushinteger(L, (D))
#define push_uint32_t(L, D) push_uint8_t(L, D)
#define push_uint64_t(L, D) push_uint8_t(L, D)
#define push_int32_t(L, D) push_uint8_t(L, D)
#define push_size_t(L, D) push_uint8_t(L, D)
#define push_VkBool32(L, D) lua_pushboolean(L, (D))
#define push_VkDeviceSize(L, D) push_uint8_t(L, D)

// These are the odd types that are only used a few places, but make a mess
#define to_PFN_vkAllocationFunction(L, R, P) ({ (R) = NULL; })
#define to_PFN_vkReallocationFunction(L, R, P) ({ (R) = NULL; })
#define to_PFN_vkFreeFunction(L, R, P) ({ (R) = NULL; })
#define to_PFN_vkInternalAllocationNotification(L, R, P) ({ (R) = NULL; })
#define to_PFN_vkInternalFreeNotification(L, R, P) ({ (R) = NULL; })

#define IN_LVULKAN

#include "lvulkan-enum.c"	// Handles enums (VkStructureType, etc.)
#include "lvulkan-bitmask.c"	// Handles bitmasks (VkQueueFlags, etc.)
#include "lvulkan-handle.c"	// Handles the handles (VkInstance, etc.)
#include "lvulkan-struct.c"	// Handles the structs (VkSubmitInfo, etc.)

// TMP: To keep link errors away!
void loadLVulkan(lua_State* L) { lua_pushnil(L); }

#endif
