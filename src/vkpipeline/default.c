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

#ifdef Vv_ENABLE_VULKAN

#include <libvivacious.h>
#include "internal.h"

extern const VvVkP libVv_vkp_test;

VvAPI const struct libVvVkP libVv_vkp = {
	.test = &libVv_vkp_test,
};

VvAPI const VvVkP* vVvkp(const Vv* V) {
	return &libVv_vkp_test;
}

#endif
