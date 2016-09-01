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
// are of two varieties: to_* and push_*

// to_* macros convert a compatible Lua object into the C type.
// Use: to_<type>((lua_State*)L, (<type>)data);
#define to_string(L, D) ({ (D) = luaL_checkstring(L, -1); })
#define to_float(L, D) ({ (D) = luaL_checknumber(L, -1); })
#define to_uint8_t(L, D) ({ (D) = luaL_checkinteger(L, -1); })
#define to_uint32_t(L, D) to_uint8_t(L, D)
#define to_uint64_t(L, D) to_uint8_t(L, D)
#define to_int32_t(L, D) to_uint8_t(L, D)
#define to_size_t(L, D) to_uint8_t(L, D)
#define to_VkBool32(L, D) ({ (D) = lua_toboolean(L, -1); })

// push_* macros convert a C type into a suitable Lua object.
// Use: push_<type>((lua_State*)L, (<type>)data);
#define push_string(L, D) lua_pushstring(L, (D))
#define push_float(L, D) lua_pushnumber(L, (D))
#define push_uint8_t(L, D) lua_pushinteger(L, (D))
#define push_uint32_t(L, D) push_uint8_t(L, D)
#define push_uint64_t(L, D) push_uint8_t(L, D)
#define push_int32_t(L, D) push_uint8_t(L, D)
#define push_size_t(L, D) push_uint8_t(L, D)
#define push_VkBool32(L, D) lua_pushboolean(L, (D))

#define IN_LVULKAN

#include "lvulkan-enum.c"	// Defines to_<enum> and push_<enum> macros
//#include "lvulkan-bitmask.c"	// Defines to_<bitm> and push_<bitm> macros
//#include "lvulkan-struct.c"	// Defines to_<struct> and push_<struct> macros

// TMP: To keep link errors away!
void loadLVulkan(lua_State* L) { lua_pushnil(L); }

#endif
