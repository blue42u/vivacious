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

#ifdef Vv_ENABLE_VULKAN
#include <vivacious/vulkan.h>
#endif

#include "xcb.h"

_Vv_INTERN(VvState) {			// For us, VvStates have our data!
	xcb_connection_t* conn;		// Connection to the X server
	xcb_screen_t* screen;		// Preferred Screen
	Xcb xcb;			// libxcb data, with commands
	// NOTE: When GL support is added, this needs to become hybrid Xlib/XCB
	VvVulkanAPI_c vkapi;
	VvState vkst;
};

_Vv_INTERN(VvWindow) {
	xcb_window_t window;	// A window ('s id)
};

static VvState init() {
	VvState st = malloc(sizeof(VvState_t));

	if(_vVlibxcb(&st->xcb)) {
		free(st);
		return NULL;
	}

	int screen;
	st->conn = st->xcb.connect(NULL, &screen);
	if(!st->conn) {
		free(st);
		return NULL;
	}

	xcb_screen_iterator_t sit = st->xcb.setup_roots_iterator(
		st->xcb.get_setup(st->conn));
	for(int i=0; i<screen; i++) st->xcb.screen_next(&sit);
	st->screen = sit.data;
	// This one always works.

	return st;
}

static void cleanup(VvState st) {
	st->xcb.disconnect(st->conn);
	_vVfreexcb(&st->xcb);
	free(st);
}

static VvState clone(const VvState st) {
	VvState res = malloc(sizeof(VvState_t));
	res->vkapi = st->vkapi;
	res->vkst = st->vkst;
	_vVlibxcb(&res->xcb);
	int screen;
	res->conn = res->xcb.connect(NULL, &screen);
	xcb_screen_iterator_t sit = res->xcb.setup_roots_iterator(
		res->xcb.get_setup(res->conn));
	for(int i=0; i<screen; i++) res->xcb.screen_next(&sit);
	res->screen = sit.data;
	return res;
}

static VvWindow CreateWindow(const VvState st, int width, int height,
	VvWindowEventMask mask) {
	VvWindow r = malloc(sizeof(VvWindow_t));
	r->window = st->xcb.generate_id(st->conn);
	st->xcb.create_window(st->conn, XCB_COPY_FROM_PARENT, r->window,
		st->screen->root, XCB_NONE, XCB_NONE,
		width ? width : XCB_NONE, height ? height : XCB_NONE,
		XCB_NONE, XCB_WINDOW_CLASS_INPUT_OUTPUT,
		st->screen->root_visual,
		0, NULL);
	st->xcb.flush(st->conn);
	return r;
}

static void DestroyWindow(const VvState st, VvWindow wind) {
	st->xcb.destroy_window(st->conn, wind->window);
}

static void ShowWindow(const VvState st, VvWindow wind) {
	fprintf(stderr, "STUB: VvWindowAPI_X ShowWindow!\n");
}

static void SetTitle(const VvState st, VvWindow wind, const char* name) {
	fprintf(stderr, "STUB: VvWindowAPI_X SetTitle!\n");
}

static void* CreateVkSurface(const VvState st, VvWindow wind) {
	fprintf(stderr, "STUB: VvWindowAPI_X CreateVkSurface!\n");
	return NULL;
}

static void SetGLContext(const VvState st, VvWindow wind) {
	fprintf(stderr, "STUB: VvWindowAPI_X SetGLContext!\n");
}

static const VvWindowAPI_t api = {
	cleanup, clone,
	CreateWindow, DestroyWindow,
	ShowWindow, SetTitle,
	CreateVkSurface, SetGLContext,
};

VvAPI const VvWindowAPI_c _vVloadWindow_X(int ver, VvState* st,
	const VvVulkanAPI_c vkapi, VvState vkst,
	const VvOpenGLAPI_c glapi, VvState glst) {
	if(ver != H_vivacious_window) return NULL;
	*st = init();
	if(!*st) return NULL;
	*st->vkapi = vkapi;
	*st->vkst = vkst;
	return &api;
}

#endif // Vv_ENABLE_X
