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
#include "internal.h"

#ifdef Vv_ENABLE_X
VvAPI VvWindowManager libVv_createWindowManager_X();
#endif

VvAPI VvVk libVv_createVk_libdl();

VvAPI libVv_createVkInstanceCreator_test();

#endif // H_libvivacious
