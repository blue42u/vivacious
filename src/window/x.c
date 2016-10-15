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

struct VvWiConnection {			// For us, VvStates have our data!
	xcb_connection_t* conn;		// Connection to the X server
	xcb_screen_t* screen;		// Preferred Screen
	Xcb xcb;			// libxcb data, with commands
	// NOTE: When GL support is added, this needs to become hybrid Xlib/XCB
#ifdef Vv_ENABLE_VULKAN
	const VvVulkan* vkapi;
	const VvVulkanBinding* vkb;
	const VvVulkan_1_0* vk;
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
		width ? width : XCB_NONE, height ? height : XCB_NONE,
		XCB_NONE, XCB_WINDOW_CLASS_INPUT_OUTPUT,
		wc->screen->root_visual,
		0, NULL);
	wc->xcb.flush(wc->conn);
	return r;
}

static void DestroyWindow(VvWiConnection* wc, VvWiWindow* wind) {
	wc->xcb.destroy_window(wc->conn, wind->id);
}

static void ShowWindow(VvWiConnection* wc, VvWiWindow* wind) {
	fprintf(stderr, "STUB: VvWindowAPI_X ShowWindow!\n");
}

static void SetTitle(VvWiConnection* wc, VvWiWindow* wind, const char* name) {
	fprintf(stderr, "STUB: VvWindowAPI_X SetTitle!\n");
}

#ifdef Vv_ENABLE_VULKAN
static void AddVulkan(VvWiConnection* wc, const VvVulkan* vkapi,
	const VvVulkanBinding* vkb, void* inst) {
	fprintf(stderr, "STUB: VvWindowAPI_X AddVulkan!\n");
}

static void* CreateVkSurface(VvWiConnection* wc, VvWiWindow* wind) {
	fprintf(stderr, "STUB: VvWindowAPI_X CreateVkSurface!\n");
	return NULL;
}
#else
static void AddVulkan(VvWiConnection* wc, const struct VvVulkan* vkapi,
	const struct VvVulkanBinding* vkb, void* inst) {
}
static void* CreateVkSurface(VvWiConnection* wc, VvWiWindow* wind) {
	return NULL;
}
#endif

static const VvWindow api = {
	Connect, Disconnect,
	CreateWindow, DestroyWindow,
	ShowWindow, SetTitle,
	AddVulkan, CreateVkSurface,
};

VvAPI const VvWindow* vVloadWindow_X() { return &api; }

#endif // Vv_ENABLE_X
