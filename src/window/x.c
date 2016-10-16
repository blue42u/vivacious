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

#ifdef Vv_ENABLE_X

#include <vivacious/window.h>
#include "internal.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#ifdef Vv_ENABLE_VULKAN
#define VK_USE_PLATFORM_XCB_KHR
#define VK_USE_PLATFORM_XLIB_KHR
#include <vivacious/vulkan.h>
#endif

#include "xcb.h"

struct VvWiConnection {			// For us, VvStates have our data!
	xcb_connection_t* conn;		// Connection to the X server
	xcb_screen_t* screen;		// Preferred Screen
	xcb_ewmh_connection_t ewmh;	// Extended Window Manager Hints
	Xcb xcb;			// libxcb data, with commands
	// NOTE: When GL support is added, this needs to become hybrid Xlib/XCB
#if defined(Vv_ENABLE_VULKAN) && defined(VK_KHR_xcb_surface)
	const VvVulkan_KHR_xcb_surface* vk;
	VkInstance inst;
#endif
};

struct VvWiWindow {
	xcb_window_t id;	// The window's id
};

static VvWiConnection* Connect() {
	VvWiConnection* wc = malloc(sizeof(VvWiConnection));

	if(_vVlibxcb(&wc->xcb)) {
		free(wc);
		return NULL;
	}

	int screen;
	wc->conn = wc->xcb.connect(NULL, &screen);
	if(!wc->conn) {
		free(wc);
		return NULL;
	}

	xcb_screen_iterator_t sit = wc->xcb.setup_roots_iterator(
		wc->xcb.get_setup(wc->conn));
	for(int i=0; i<screen; i++) wc->xcb.screen_next(&sit);
	wc->screen = sit.data;
	// This one always works.

	if(wc->xcb.ewmh_init_atoms) {	// If we have EWMH support
		xcb_intern_atom_cookie_t* cookie
			= wc->xcb.ewmh_init_atoms(wc->conn, &wc->ewmh);
		if(!wc->xcb.ewmh_init_atoms_replies(&wc->ewmh, cookie, NULL)) {
			wc->xcb.disconnect(wc->conn);
			free(wc);
			return NULL;
		}
	}

	return wc;
}

static void Disconnect(VvWiConnection* wc) {
	wc->xcb.disconnect(wc->conn);
	_vVfreexcb(&wc->xcb);
	free(wc);
}

static VvWiWindow* CreateWindow(VvWiConnection* wc, int width, int height,
	VvWiEventMask mask) {
	VvWiWindow* r = malloc(sizeof(VvWiWindow));
	r->id = wc->xcb.generate_id(wc->conn);
	wc->xcb.create_window(wc->conn, XCB_COPY_FROM_PARENT, r->id,
		wc->screen->root, XCB_NONE, XCB_NONE,
		width, height,
		10, XCB_WINDOW_CLASS_INPUT_OUTPUT,
		wc->screen->root_visual,
		0, NULL);
	wc->xcb.flush(wc->conn);
	return r;
}

static void DestroyWindow(VvWiConnection* wc, VvWiWindow* wind) {
	wc->xcb.destroy_window(wc->conn, wind->id);
	wc->xcb.flush(wc->conn);
}

static void ShowWindow(VvWiConnection* wc, VvWiWindow* wind) {
	wc->xcb.map_window(wc->conn, wind->id);
	wc->xcb.flush(wc->conn);
}

static void SetTitle(VvWiConnection* wc, VvWiWindow* wind, const char* name) {
	wc->xcb.change_property(wc->conn, XCB_PROP_MODE_REPLACE, wind->id,
		XCB_ATOM_WM_NAME, XCB_ATOM_STRING, 8,
		strlen(name), name);
	wc->xcb.flush(wc->conn);
}

#if defined(Vv_ENABLE_VULKAN) && defined(VK_KHR_xcb_surface)
static void AddVulkan(VvWiConnection* wc, const VvVulkan* vkapi,
	const VvVulkanBinding* vkb, void* inst) {
	wc->vk = vkapi->ext->KHR_xcb_surface(vkb);
	wc->inst = (VkInstance)inst;
}

static int CreateVkSurface(VvWiConnection* wc, VvWiWindow* wind, void* psurf) {
	if(!wc->vk || !wc->vk->CreateXcbSurfaceKHR)
		return VK_ERROR_EXTENSION_NOT_PRESENT;
	VkXcbSurfaceCreateInfoKHR xsci = {
		VK_STRUCTURE_TYPE_XCB_SURFACE_CREATE_INFO_KHR, NULL,
		0, wc->conn, wind->id,
	};
	return wc->vk->CreateXcbSurfaceKHR(wc->inst, &xsci, NULL, psurf);
}
#else
static void AddVulkan(VvWiConnection* wc, const struct VvVulkan* vkapi,
	const struct VvVulkanBinding* vkb, void* inst) {
}
static int CreateVkSurface(VvWiConnection* wc, VvWiWindow* wind, void* psurf) {
	return -7;	// VK_ERROR_EXTENSION_NOT_PRESENT
}
#endif

static void SetFullscreen(VvWiConnection* wc, VvWiWindow* wind, int en) {
	if(wc->xcb.ewmh_init_atoms && wc->ewmh._NET_WM_STATE_FULLSCREEN) {
		xcb_atom_t at = 0;
		if(en) at |= wc->ewmh._NET_WM_STATE_FULLSCREEN;
		wc->xcb.change_property(
			wc->conn, XCB_PROP_MODE_REPLACE, wind->id,
			wc->ewmh._NET_WM_STATE, XCB_ATOM_ATOM, 32,
			1, &at);
		wc->xcb.flush(wc->conn);
	} else fprintf(stderr, "Fullscreen without EWMH!\n");
}

static void SetWindowSize(VvWiConnection* wc, VvWiWindow* wind,
	const int ext[2]) {
	uint32_t values[] = { ext[0], ext[1] };
	wc->xcb.configure_window(wc->conn, wind->id,
		XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT,
		values);
	wc->xcb.flush(wc->conn);
}

static void GetWindowSize(VvWiConnection* wc, VvWiWindow* wind,
	int ext[2]) {
	xcb_get_geometry_cookie_t cookie = wc->xcb.get_geometry(wc->conn,
		wind->id);
	xcb_get_geometry_reply_t* geom = wc->xcb.get_geometry_reply(wc->conn,
		cookie, NULL);
	if(geom) {
		ext[0] = geom->width;
		ext[1] = geom->height;
		free(geom);
	}
}

static void GetScreenSize(VvWiConnection* wc, int ext[2]) {
	xcb_get_geometry_cookie_t cookie = wc->xcb.get_geometry(wc->conn,
		wc->screen->root);
	xcb_get_geometry_reply_t* geom = wc->xcb.get_geometry_reply(wc->conn,
		cookie, NULL);
	if(geom) {
		ext[0] = geom->width;
		ext[1] = geom->height;
		free(geom);
	}
}

static const VvWindow api = {
	Connect, Disconnect,
	CreateWindow, DestroyWindow,
	ShowWindow, SetTitle,
	AddVulkan, CreateVkSurface,
	SetFullscreen,
	SetWindowSize, GetWindowSize,
	GetScreenSize,
};

VvAPI const VvWindow* vVloadWindow_X() { return &api; }

#endif // Vv_ENABLE_X
