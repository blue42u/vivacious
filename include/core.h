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

#ifndef H_vivacious_core
#define H_vivacious_core

// This macro will create a typedef that acts as an opaque handle.
#define Vv_DEFINE_HANDLE(name) typedef struct _##name##_dummyT* name;

// This is a kind of handle many APIs use. Unified to allow for app-side
// managment.
Vv_DEFINE_HANDLE(VvConfig)

#endif // H_vivacious_core
