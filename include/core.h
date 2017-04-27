/**************************************************************************
   Copyright 2016-2017 Jonathon Anderson

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

#ifndef H_vivacious_core
#define H_vivacious_core

// Convience macro for typedefing structures. Because repeatition is often bad.
// Use with a semicolon.
#define _Vv_TYPEDEF(name) typedef struct name name

// Convience macro for defining structure-based API types. Saves some typing.
// To be used as:
// _Vv_STRUCT(MyAwesomeStructure) {
//	int mySuperAwesomeMember;
// };
#define _Vv_STRUCT(name) \
_Vv_TYPEDEF(name); \
struct name

// Convience macro for defining enum-based API types. Saves some typing.
// To be used as:
// _Vv_ENUM(MyAwesomeEnum) {
//	MyAwesomeConstant, MyOtherAwesomeConstant,
// };
#define _Vv_ENUM(name) \
typedef enum name name; \
enum name

// The structure that holds every choice.
_Vv_STRUCT(Vv) {
	const struct Vv_Vulkan* vk; struct VvVk_Binding* vk_binding;
	const struct Vv_Window* wi;
	const struct Vv_VulkanBoilerplate* vkb;
	const struct Vv_VulkanMemoryManager* vkm;
	const struct Vv_VulkanPipeline* vkp;
};

// Generic helper macros, to save on typing in other places
#define _vVcore_API(SHORTHAND) (*(Vv_CHOICE).SHORTHAND)
#define _vVcore_FUNC(SHORT, FUNC, ...) \
_vVcore_API(SHORT).FUNC(&(Vv_CHOICE), __VA_ARGS__)
#define _vVcore_FUNCNARGS(SHORT, FUNC) \
_vVcore_API(SHORT).FUNC(&(Vv_CHOICE))

// Layer Vk
#if !defined(Vv_IMP_vk)
#define Vv_vk_ENABLED
#define _Vv_LAYER_vk_ENABLED
#endif // !IMP_vk

// Layer Wi
#if defined(_Vv_LAYER_vk_ENABLED) && !defined(Vv_IMP_wi)
#define Vv_wi_ENABLED
#define _Vv_LAYER_wi_ENABLED
#endif // LAY_vk && !IMP_wi

// Layer VkCore
#if defined(_Vv_LAYER_vk_ENABLED) && !defined(Vv_IMP_vkb) \
	&& !defined(Vv_IMP_vkm) && !defined(Vv_IMP_vkp)
#define _Vv_LAYER_vkcore_ENABLED
#define Vv_vkb_ENABLED
#define Vv_vkm_ENABLED
#define Vv_vkp_ENABLED
#endif // LAY_vk && !IMP_vkb && !IMP_vkm && !IMP_vkp

#endif // H_vivacious_core
