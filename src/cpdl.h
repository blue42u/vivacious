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

#ifndef H_cpdl
#define H_cpdl

// This header defines a few functions for dynamic loading, heavily inspired
// by libdl.

// Open a dynamic library. The three different strings are the different names
// for the library by platform. Returns a handle.
void* _vVopendl(const char* nix, const char* mac, const char* win);

// Obtain a function from the library given.
void* _vVsymdl(void* handle, const char* sym);

// Close a library.
void _vVclosedl(void* handle);

#endif // H_cpdl
