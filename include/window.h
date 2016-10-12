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

#ifndef H_vivacious_window
#define H_vivacious_window 0	// Acts as the 'major' version of the header.

#include <vivacious/core.h>

// First off, the types needed to use this API
typedef enum {
	VvWINDOW_EVENT_MOUSE_PRESS,
	VvWINDOW_EVENT_MOUSE_RELEASE,
	VvWINDOW_EVENT_MOUSE_MOVED,
	VvWINDOW_EVENT_KEY_PRESS,
	VvWINDOW_EVENT_KEY_RELEASE,
} VvWindowEventMask;
_Vv_HANDLE(VvWindow)

// Now, the API itself
_Vv_API(VvWindowAPI) {
	// Cleanup and clone the State
	void (*cleanup)(VvState);
	VvState (*clone)(const VvState);

	// Create a new window for the screen. May or may not be visible
	// immediately after creation.
	VvWindow (*CreateWindow)(const VvState, int width, int height,
		VvWindowEventMask events);

	// Close/Destroy a window. After this, the window is invalid.
	void (*DestroyWindow)(const VvState, VvWindow);

	// Show a window on the screen. Should be called after all
	// setup is done on the window.
	void (*ShowWindow)(const VvState, VvWindow);

	// Set the window's title. <name> is assumed to be a null-terminated
	// character array, as is convention with C strings.
	void (*SetTitle)(const VvState, VvWindow, const char* name);

	// Create a VkSurface based on a Window. May return NULL on error.
	void* (*CreateVkSurface)(const VvState, VvWindow);

	// Set a Window as the current GL context.
	void (*SetGLContext)(const VvState, VvWindow);
};
#ifndef _VvWindowAPI_def
#define _VvWindowAPI_def	// To prevent double-define
_Vv_HANDLE(VvWindowAPI)
#endif

// And other APIs that the implementations need
#ifndef _VvVulkanAPI_def
#define _VvVulkanAPI_def
_Vv_HANDLE(VvVulkanAPI)
#endif

#ifndef _VvOpenGLAPI_def
#define _VvOpenGLAPI_def
_Vv_HANDLE(VvOpenGLAPI)
#endif

const VvWindowAPI_c _vVloadWindow_X(int, VvState*,
	const VvVulkanAPI_c, VvState,
	const VvOpenGLAPI_c, VvState);
#define vVloadWindow_X(S, V, VS, G, GS) _vVloadWindow_X(H_vivacious_window, \
	(S), (V), (VS), (G), (GS))
#define vVloadWindow_X_Vulkan(S, V, VS) vVloadWindow_X(S, V, VS, NULL, NULL)

#endif // H_vivacious_window
