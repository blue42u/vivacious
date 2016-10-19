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
#define H_vivacious_window

#include <vivacious/core.h>

// This enum acts as a bitmask for event types later
_Vv_ENUM(VvWiEventMask) {
	VvWI_EVENT_NONE = 0,
	VvWI_EVENT_MOUSE_PRESS = 1,
	VvWI_EVENT_MOUSE_RELEASE = 2,
	VvWI_EVENT_MOUSE_MOVED = 4,
	VvWI_EVENT_KEY_PRESS = 8,
	VvWI_EVENT_KEY_RELEASE = 16,
};

// A Connection is a connection to the window manager.
_Vv_TYPEDEF(VvWiConnection);

// A Window is the opaque handle for a window on a screen, somewhere...
// ...Hopefully. Maybe our implementation is tricking us. Or maybe not.
_Vv_TYPEDEF(VvWiWindow);

// Dependancy structs. Referenced here to avoid -Wvisibility warnings.
struct VvVulkan;
struct VvVulkanBinding;

_Vv_STRUCT(VvWindow) {
	// Connect to the system's window manager.
	VvWiConnection* (*Connect)();

	// Disconnect. Also can clean stuff up. Consider the connection
	// invalid after this.
	void (*Disconnect)(VvWiConnection*);

	// Create a new window for the screen. May or may not be visible
	// immediately after creation, use ShowWindow to be sure.
	VvWiWindow* (*CreateWindow)(VvWiConnection*, int width, int height,
		VvWiEventMask events);

	// Close/Destroy a window. After this, the window is invalid.
	void (*DestroyWindow)(VvWiWindow*);

	// Show a window on the screen, if its not shown already.
	void (*ShowWindow)(VvWiWindow*);

	// Set the window's title. <name> is assumed to be a null-terminated
	// character array, as is convention with C strings.
	void (*SetTitle)(VvWiWindow*, const char* name);

	// Create a VkSurface based on a Window. Returns a VkResult, and
	// <psurf> is a VkSurface*.
	int (*CreateVkSurface)(VvWiWindow*, void* inst, void* psurf,
		const struct VvVulkan*, const struct VvVulkanBinding*);

	// Make a window fullscreen if <enable> is a true value, otherwise
	// make the window windowed.
	void (*SetFullscreen)(VvWiWindow*, int enable);

	// Set the size of a window.
	void (*SetWindowSize)(VvWiWindow*, const int[2]);

	// Get the size of a window.
	void (*GetWindowSize)(VvWiWindow*, int[2]);

	// Get the size of the screen.
	void (*GetScreenSize)(VvWiConnection*, int[2]);
};

const VvWindow* vVloadWindow_X();

#endif // H_vivacious_window
