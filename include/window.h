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
	VvWi_Connection* (*connect)();

	// Disconnect, and destroy the connection.
	void (*disconnect)(VvWi_Connection*);

	// Create a new window for the screen. May or may not be visible
	// immediately after creation, use showWindow to be sure.
	VvWi_Window* (*createWindow)(VvWi_Connection*, int width, int height,
		VvWi_EventMask events);

	// Close/Destroy a window. After this, the window is invalid.
	void (*destroyWindow)(VvWi_Window*);

	// Show a window on the screen, if its not shown already.
	void (*showWindow)(VvWi_Window*);

	// Set the window's title.
	void (*setTitle)(VvWi_Window*, const char* name);

	// Create a VkSurface based on a Window. Returns a VkResult, and
	// <psurf> is a VkSurface*.
	int (*createVkSurface)(VvWi_Window*, void* inst, void* psurf,
		const struct VvVk_Binding*);

	// Make a window fullscreen if <enable> is a true value, otherwise
	// make the window windowed.
	void (*setFullscreen)(VvWi_Window*, int enable);

	// Set the size of a window.
	void (*setWindowSize)(VvWi_Window*, const int[2]);

	// Get the size of a window.
	void (*getWindowSize)(VvWi_Window*, int[2]);

	// Get the size of the screen.
	void (*getScreenSize)(VvWi_Connection*, int[2]);
};

extern const Vv_Window vVwi_X;

#endif // H_vivacious_window
