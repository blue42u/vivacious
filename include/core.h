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
}

/*
	This file also (for now) contains the info on the helper macros.
	To activate, define `Vv_CHOICE` to reference a Vv structure
	(not pointer to) at any point in which the helper macros are used.
	So applications can put an `extern Vv` in a common header, and
	implementations can use the same name for the first argument.

	`Vv_CHOICE` may be evaluated multiple times in any one macro.

	If an implementation wishes to use the helper macros, there is
	a particular order in which the API layers are layed out, which
	is to prevent cyclic dependencies. This order is defined here,
	and can be enabled by defining `Vv_IMP` with the enum constant
	`Vv_IMP_<shorthand>`.

	In either case, `Vv_<shorthand>_ENABLED` will be defined
	if the helper macros are allowed for that API. By writing implementation
	code using the helper macros, and defining `Vv_IMP` correctly, it is
	possible to ensure (at compile-time) that the implementation will not
	cause a cyclic dependency between APIs.

	The helper macros are defined in their APIs headers, and the available
	helper macros for an API are as follows:
		`vV<shorthand>` references the API structure.
		`vV<shorthand>_<function>(...)` (funcs start with l-case)
			calls the function with Vv_CHOICE as the first arg.

	Most helper macros are based on two generic ones, written here, which
	allow for fast refactoring of the choice system.
*/

// Generic helper macros
#define vVcore_API(SHORTHAND) *(Vv_CHOICE).SHORTHAND
#define vVcore_FUNC(SHORT, FUNC, ...) \
vVcore_API(SHORT).FUNC(vVcore_API(SHORT), __VA_ARGS__)
#define vVcore_FUNCNARGS(SHORT, FUNC) \
vVcore_API(SHORT).FUNC(vVcore_API(SHORT))

// Layer listings
_Vv_ENUM(Vv_IMP_ENUM) {
	Vv_IMP_vk, Vv_IMP_wi, // First layer
	Vv_IMP_vkb, Vv_IMP_vkm, Vv_IMP_vkp,	// Second layer
	Vv_IMP_ENUM_END
};

#ifdef Vv_IMP		// Setup to make writing the layers easier
#define Vv_IMP_UNDEF_LATER
#define Vv_IMP Vv_IMP_ENUM_END	// So all APIs are enabled
#endif // !Vv_IMP

// First layer: vk and wi
#if Vv_IMP != Vv_IMP_vk && Vv_IMP != Vv_IMP_wi
#define Vv_vk_ENABLED
#define Vv_wi_ENABLED

// Second layer: vkb, vkm and vkp
#if Vv_IMP != Vv_IMP_vkb && Vv_IMP != Vv_IMP_vkm && Vv_IMP != Vv_IMP_vkp
#define Vv_vkb_ENABLED
#define Vv_vkm_ENABLED
#define Vv_vkp_ENABLED

// End of layers.

#endif // !vkb && !vkm && !vkp
#endif // !vk && !wi
#endif // Vv_IMP

#ifdef Vv_IMP_UNDEF_LATER
#undef Vv_IMP_UNDEF_LATER
#undef Vv_IMP
#endif

#endif // H_vivacious_core
