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

#ifndef H_vivacious_window
#define H_vivacious_window

#include <vivacious/core.h>

// This enum acts as a bitmask for event types later
_Vv_ENUM(VvWi_EventMask) {
	VvWI_EVENT_NONE = 0,
	VvWI_EVENT_MOUSE_PRESS = 1,
	VvWI_EVENT_MOUSE_RELEASE = 2,
	VvWI_EVENT_MOUSE_MOVED = 4,
	VvWI_EVENT_KEY_PRESS = 8,
	VvWI_EVENT_KEY_RELEASE = 16,
};

// A Connection is a connection to the window manager.
_Vv_TYPEDEF(VvWi_Connection);

// A Window is the opaque handle for a window on a screen, somewhere...
// ...Or maybe our implementation is tricking us. We don't care.
_Vv_TYPEDEF(VvWi_Window);

// Dependancy structs. Referenced here to avoid -Wvisibility warnings.
struct Vv_Vulkan;
struct VvVk_Binding;

_Vv_STRUCT(Vv_Window) {
	// Connect to the system's window manager.
	VvWi_Connection* (*connect)(const Vv*);
#ifdef Vv_wi_ENABLED
#define vVwi_connect() _vVcore_FUNCNARGS(wi, connect)
#endif

	// Disconnect, and destroy the connection.
	void (*disconnect)(const Vv*, VvWi_Connection*);
#ifdef Vv_wi_ENABLED
#define vVwi_disconnect(...) _vVcore_FUNC(wi, disconnect, __VA_ARGS__)
#endif

	// Create a new window for the screen. May or may not be visible
	// immediately after creation, use showWindow to be sure.
	VvWi_Window* (*createWindow)(const Vv*, VvWi_Connection*, int width,
		int height, VvWi_EventMask events);
#ifdef Vv_wi_ENABLED
#define vVwi_createWindow(...) _vVcore_FUNC(wi, createWindow, __VA_ARGS__)
#endif

	// Close/Destroy a window. After this, the window is invalid.
	void (*destroyWindow)(const Vv*, VvWi_Window*);
#ifdef Vv_wi_ENABLED
#define vVwi_destroyWindow(...) _vVcore_FUNC(wi, destroyWindow, __VA_ARGS__)
#endif

	// Show a window on the screen, if its not shown already.
	void (*showWindow)(const Vv*, VvWi_Window*);
#ifdef Vv_wi_ENABLED
#define vVwi_showWindow(...) _vVcore_FUNC(wi, showWindow, __VA_ARGS__)
#endif

	// Set the window's title.
	void (*setTitle)(const Vv*, VvWi_Window*, const char* name);
#ifdef Vv_wi_ENABLED
#define vVwi_setTitle(...) _vVcore_FUNC(wi, setTitle, __VA_ARGS__)
#endif

	// Create a VkSurface based on a Window. Returns a VkResult, and
	// <psurf> is a VkSurface*.
	int (*createVkSurface)(const Vv*, VvWi_Window*, void* inst,
		void* psurf);
#ifdef Vv_wi_ENABLED
#define vVwi_createVkSurface(...) _vVcore_FUNC(wi, createVkSurface, __VA_ARGS__)
#endif

	// Make a window fullscreen if <enable> is a true value, otherwise
	// make the window windowed.
	void (*setFullscreen)(const Vv*, VvWi_Window*, int enable);
#ifdef Vv_wi_ENABLED
#define vVwi_setFullscreen(...) _vVcore_FUNC(wi, setFullscreen, __VA_ARGS__)
#endif

	// Set the size of a window.
	void (*setWindowSize)(const Vv*, VvWi_Window*, const int[2]);
#ifdef Vv_wi_ENABLED
#define vVwi_setWindowSize(...) _vVcore_FUNC(wi, setWindowSize, __VA_ARGS__)
#endif

	// Get the size of a window.
	void (*getWindowSize)(const Vv*, VvWi_Window*, int[2]);
#ifdef Vv_wi_ENABLED
#define vVwi_getWindowSize(...) _vVcore_FUNC(wi, getWindowSize, __VA_ARGS__)
#endif

	// Get the size of the screen.
	void (*getScreenSize)(const Vv*, VvWi_Connection*, int[2]);
#ifdef Vv_wi_ENABLED
#define vVwi_getScreenSize(...) _vVcore_FUNC(wi, getScreenSize, __VA_ARGS__)
#endif
};

extern const Vv_Window vVwi_Default;

#endif // H_vivacious_window
