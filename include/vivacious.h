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

#ifndef H_vivacious_vivacious
#define H_vivacious_vivacious

#include <vivacious/vulkan.h>
#include <vivacious/window.h>
#include <vivacious/vkbplate.h>
#include <vivacious/vkmemory.h>
#include <vivacious/vkpipeline.h>

#define vV_Default ({ \
	Vv V; \
	V.vk = vVvk_Default(&V); V.vk_binding = NULL; \
	V.wi = vVwi_Default(&V); \
	V.vkb = vVvkb_Default(&V); \
	V.vkm = vVvkm_Default(&V); \
	V.vkp = vVvkp_Default(&V); \
	V; \
})

#endif // H_vivacious_vivacious
