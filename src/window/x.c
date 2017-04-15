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

#ifdef Vv_ENABLE_X

#define Vv_CHOICE *V
#define Vv_IMP_wi

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

#ifndef Vv_vk_ENABLED
#error Vv_IMP
#endif

struct VvWi_Connection {		// For us, VvStates have our data!
	xcb_connection_t* conn;		// Connection to the X server
	xcb_screen_t* screen;		// Preferred Screen
	xcb_ewmh_connection_t ewmh;	// Extended Window Manager Hints
	Xcb xcb;			// libxcb data, with commands
	// NOTE: When GL support is added, this needs to become hybrid Xlib/XCB
};

struct VvWi_Window {
	VvWi_Connection* c;
	xcb_window_t id;	// The window's id
};

static VvWi_Connection* Connect(const Vv* V) {
	VvWi_Connection* wc = malloc(sizeof(VvWi_Connection));

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

static void Disconnect(const Vv* V, VvWi_Connection* wc) {
	if(wc->xcb.ewmh_init_atoms) {	// If we have EWMH support
		xcb_ewmh_connection_wipe(&wc->ewmh);
	}
	wc->xcb.disconnect(wc->conn);
	_vVfreexcb(&wc->xcb);
	free(wc);
}

static VvWi_Window* CreateWindow(const Vv* V, VvWi_Connection* wc, int width, int height,
	VvWi_EventMask mask) {
	VvWi_Window* r = malloc(sizeof(VvWi_Window));
	r->c = wc;
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

static void DestroyWindow(const Vv* V, VvWi_Window* w) {
	w->c->xcb.destroy_window(w->c->conn, w->id);
	w->c->xcb.flush(w->c->conn);
	free(w);
}

static void ShowWindow(const Vv* V, VvWi_Window* w) {
	w->c->xcb.map_window(w->c->conn, w->id);
	w->c->xcb.flush(w->c->conn);
}

static void SetTitle(const Vv* V, VvWi_Window* w, const char* name) {
	w->c->xcb.change_property(w->c->conn, XCB_PROP_MODE_REPLACE, w->id,
		XCB_ATOM_WM_NAME, XCB_ATOM_STRING, 8,
		strlen(name), name);
	w->c->xcb.flush(w->c->conn);
}

#if defined(Vv_ENABLE_VULKAN) && defined(VK_KHR_xcb_surface)
static int CreateVkSurface(const Vv* V, VvWi_Window* w, void* inst,
	void* psurf) {

	if(!&vVvk_KHR_xcb_surface)
		return VK_ERROR_EXTENSION_NOT_PRESENT;
	VkXcbSurfaceCreateInfoKHR xsci = {
		VK_STRUCTURE_TYPE_XCB_SURFACE_CREATE_INFO_KHR, NULL,
		0, w->c->conn, w->id,
	};
	return vVvk_CreateXcbSurfaceKHR(inst, &xsci, NULL, psurf);
}
#else
static int CreateVkSurface(const Vv* V, VvWi_Window* w, void* inst,
	void* psurf) {

	return -7;	// VK_ERROR_EXTENSION_NOT_PRESENT
}
#endif

static void SetFullscreen(const Vv* V, VvWi_Window* w, int en) {
	if(w->c->xcb.ewmh_init_atoms && w->c->ewmh._NET_WM_STATE_FULLSCREEN) {
		xcb_atom_t at = 0;
		if(en) at |= w->c->ewmh._NET_WM_STATE_FULLSCREEN;
		w->c->xcb.change_property(
			w->c->conn, XCB_PROP_MODE_REPLACE, w->id,
			w->c->ewmh._NET_WM_STATE, XCB_ATOM_ATOM, 32,
			1, &at);
		w->c->xcb.flush(w->c->conn);
	} else fprintf(stderr, "Attempted fullscreen without EWMH!\n");
}

static void SetWindowSize(const Vv* V, VvWi_Window* w, const int ext[2]) {
	uint32_t values[] = { ext[0], ext[1] };
	w->c->xcb.configure_window(w->c->conn, w->id,
		XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT,
		values);
	w->c->xcb.flush(w->c->conn);
}

static void GetWindowSize(const Vv* V, VvWi_Window* w, int ext[2]) {
	xcb_get_geometry_cookie_t cookie = w->c->xcb.get_geometry(
		w->c->conn, w->id);
	xcb_get_geometry_reply_t* geom = w->c->xcb.get_geometry_reply(
		w->c->conn, cookie, NULL);
	if(geom) {
		ext[0] = geom->width;
		ext[1] = geom->height;
		free(geom);
	}
}

static void GetScreenSize(const Vv* V, VvWi_Connection* wc, int ext[2]) {
	xcb_get_geometry_cookie_t cookie = wc->xcb.get_geometry(
		wc->conn, wc->screen->root);
	xcb_get_geometry_reply_t* geom = wc->xcb.get_geometry_reply(
		wc->conn, cookie, NULL);
	if(geom) {
		ext[0] = geom->width;
		ext[1] = geom->height;
		free(geom);
	}
}

VvAPI const Vv_Window vVwi_Default = {	// TMP
	.connect=Connect, .disconnect=Disconnect,
	.createWindow=CreateWindow, .destroyWindow=DestroyWindow,
	.showWindow=ShowWindow, .setTitle=SetTitle,
	.createVkSurface=CreateVkSurface,
	.setFullscreen=SetFullscreen,
	.setWindowSize=SetWindowSize, .getWindowSize=GetWindowSize,
	.getScreenSize=GetScreenSize,
};

#endif // Vv_ENABLE_X
