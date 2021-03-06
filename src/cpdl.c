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

#include "cpdl.h"
#include <stdlib.h>

#if defined(_WIN32)
#include <windows.h>

void* _vVopendl(const char* nix, const char* mac, const char* win) {
	if(!win) return NULL;
	HMODULE* lib = malloc(sizeof(HMODULE));
	*lib = LoadLibrary(win);
	if(!*lib) return NULL;
	return lib;
}

void* _vVsymdl(void* handle, const char* sym) {
	if(!handle) return NULL;
	return GetProcAddress(*(HMODULE*)handle, sym);
}

void _vVclosedl(void* handle) {
	FreeLibrary(*(HMODULE*)handle);
	free(handle);
}

#else
#include <dlfcn.h>

void* _vVopendl(const char* nix, const char* mac, const char* win) {
#if defined(__APPLE__)
	if(!mac) return NULL;
	return dlopen(mac, RTLD_LAZY | RTLD_LOCAL);
#else
	if(!nix) return NULL;
	return dlopen(nix, RTLD_LAZY | RTLD_LOCAL);
#endif
}

void* _vVsymdl(void* handle, const char* sym) {
	if(!handle) return NULL;
	return dlsym(handle, sym);
}

void _vVclosedl(void* handle) {
	dlclose(handle);
}

#endif // _WIN32
