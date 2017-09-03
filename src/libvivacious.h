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

#ifndef H_libvivacious
#define H_libvivacious

#include <vivacious/vivacious.h>

extern const struct libVvVk {
	const VvVk* libdl;
} libVv_vk;

extern const struct libVvWi {
	const VvWi* x;
} libVv_wi;

extern const struct libVvVkB {
	const VvVkB* test;
} libVv_vkb;

extern const struct libVvVkM {
	const VvVkM* test;
} libVv_vkm;

extern const struct libVvVkP {
	const VvVkP* test;
} libVv_vkp;

#endif // H_libvivacious