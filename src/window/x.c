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

#include <vivacious/window.h>
#include "internal.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#ifdef Vv_ENABLE_VULKAN
#define VK_USE_PLATFORM_XCB_KHR
#include <vivacious/vulkan.h>
#endif

#include "xcb.h"

struct VvWindowManager_I {		// For us, VvStates have our data!
	xcb_connection_t* conn;		// Connection to the X server
	xcb_screen_t* screen;		// Preferred Screen
	xcb_ewmh_connection_t ewmh;	// Extended Window Manager Hints
	Xcb xcb;			// libxcb data, with commands
};

struct VvWindowManagerWindow_I {
	xcb_window_t id;	// The window's id
};

static const struct VvWindowManager_M M_M;
static const struct VvWindowManagerWindow_M W_M;

VvWindowManager libVv_createWindowManager_X() {
	VvWindowManager self = malloc(sizeof(struct VvWindowManager));
	self->_M = &M_M;
	self->_I = malloc(sizeof(struct VvWindowManager_I));

	if(_vVlibxcb(&self->_I->xcb)) {
		free(self->_I);
		free(self);
		return NULL;
	}

	int screen;
	self->_I->conn = self->_I->xcb.connect(NULL, &screen);
	if(!self->_I->conn) {
		free(self->_I);
		free(self);
		return NULL;
	}

	xcb_screen_iterator_t sit = self->_I->xcb.setup_roots_iterator(
		self->_I->xcb.get_setup(self->_I->conn));
	for(int i=0; i<screen; i++) self->_I->xcb.screen_next(&sit);
	self->_I->screen = sit.data;

	if(self->_I->xcb.ewmh_init_atoms) { // If we have EWMH support
		xcb_intern_atom_cookie_t* cookie
			= self->_I->xcb.ewmh_init_atoms(self->_I->conn, &self->_I->ewmh);
		if(!self->_I->xcb.ewmh_init_atoms_replies(&self->_I->ewmh, cookie, NULL)) {
			self->_I->xcb.disconnect(self->_I->conn);
			free(self->_I);
			free(self);
			return NULL;
		}
	}

	return self;
}

static void M_destroy(VvWindowManager self) {
	if(self->_I->xcb.ewmh_init_atoms) {
		xcb_ewmh_connection_wipe(&self->_I->ewmh);
	}
	self->_I->xcb.disconnect(self->_I->conn);
	_vVfreexcb(&self->_I->xcb);
	free(self->_I);
	free(self);
}

static VkExtent2D M_getSize(VvWindowManager self) {
	xcb_get_geometry_cookie_t cookie = self->_I->xcb.get_geometry(
		self->_I->conn, self->_I->screen->root);
	xcb_get_geometry_reply_t* geom = self->_I->xcb.get_geometry_reply(
		self->_I->conn, cookie, NULL);
	VkExtent2D out = {0,0};
	if(geom) {
		out.width = geom->width;
		out.height = geom->height;
		free(geom);
	}
	return out;
}

static VvVkInstanceCreatorInfo M_getInstanceInfo(VvWindowManager self) {
	return VvVkInstanceCreatorInfo_V(
		.extensionsCnt=1, .extensions=(const char*[]){"VK_KHR_xcb_surface"},
	);
}

static VvWindowManagerWindow M_newWindow(VvWindowManager self, VkExtent2D ext,
	VvWindowManagerEvents events) {
	VvWindowManagerWindow w = malloc(sizeof(struct VvWindowManagerWindow));
	w->_I = malloc(sizeof(struct VvWindowManagerWindow_I));
	w->_M = &W_M;
	w->windowmanager = self;

	w->_I->id = self->_I->xcb.generate_id(self->_I->conn);
	self->_I->xcb.create_window(self->_I->conn, XCB_COPY_FROM_PARENT, w->_I->id,
		self->_I->screen->root, XCB_NONE, XCB_NONE,
		ext.width, ext.height,
		10, XCB_WINDOW_CLASS_INPUT_OUTPUT,
		self->_I->screen->root_visual,
		0, NULL);
	self->_I->xcb.flush(self->_I->conn);
	return w;
}

#define WM self->windowmanager->_I
static void W_destroy(VvWindowManagerWindow self) {
	WM->xcb.destroy_window(WM->conn, self->_I->id);
	WM->xcb.flush(WM->conn);
	free(self->_I);
	free(self);
}

static void W_show(VvWindowManagerWindow self) {
	WM->xcb.map_window(WM->conn, self->_I->id);
	WM->xcb.flush(WM->conn);
}

static void W_setTitle(VvWindowManagerWindow self, const char* name) {
	WM->xcb.change_property(WM->conn,
		XCB_PROP_MODE_REPLACE, self->_I->id,
		XCB_ATOM_WM_NAME, XCB_ATOM_STRING, 8,
		strlen(name), name);
	WM->xcb.flush(WM->conn);
}

static void W_setFullscreen(VvWindowManagerWindow self, bool en) {
	if(WM->xcb.ewmh_init_atoms && WM->ewmh._NET_WM_STATE_FULLSCREEN) {
		xcb_atom_t at = 0;
		if(en) at |= WM->ewmh._NET_WM_STATE_FULLSCREEN;
		WM->xcb.change_property(
			WM->conn, XCB_PROP_MODE_REPLACE, self->_I->id,
			WM->ewmh._NET_WM_STATE, XCB_ATOM_ATOM, 32,
			1, &at);
		WM->xcb.flush(WM->conn);
	} else fprintf(stderr, "Attempted fullscreen without EWMH!\n");
}

static void W_setSize(VvWindowManagerWindow self, VkExtent2D ext) {
	uint32_t values[] = { ext.width, ext.height };
	WM->xcb.configure_window(WM->conn, self->_I->id,
		XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT,
		values);
	WM->xcb.flush(WM->conn);
}

static VkExtent2D W_getSize(VvWindowManagerWindow self) {
	xcb_get_geometry_cookie_t cookie = WM->xcb.get_geometry(
		WM->conn, self->_I->id);
	xcb_get_geometry_reply_t* geom = WM->xcb.get_geometry_reply(
		WM->conn, cookie, NULL);
	VkExtent2D ext = {0,0};
	if(geom) {
		ext.width = geom->width;
		ext.height = geom->height;
		free(geom);
	}
	return ext;
}

static VvVkSurfaceKHR W_createVkSurface(VvWindowManagerWindow self,
	VvVkInstance inst, VkResult* res) {

	VkResult dres;
	if(!res) res = &dres;
	if(!inst->_M->vkCreateXcbSurfaceKHR) {
		*res = VK_ERROR_EXTENSION_NOT_PRESENT;
		return NULL;
	}
	VkSurfaceKHR surf;
	*res = vVvkCreateXcbSurfaceKHR(inst, &VkXcbSurfaceCreateInfoKHR_V(
		.connection = WM->conn, .window = self->_I->id,
	), NULL, &surf);
	if(*res < 0) return NULL;
	else return vVwrapVkSurfaceKHR(surf, inst);
}

static const struct VvWindowManager_M M_M = {
	.destroy = M_destroy, .newWindow = M_newWindow,
	.getSize = M_getSize, .getInstanceInfo = M_getInstanceInfo,
};

static const struct VvWindowManagerWindow_M W_M = {
	.destroy = W_destroy, .show = W_show, .setTitle = W_setTitle,
	.setFullscreen = W_setFullscreen, .setSize = W_setSize,
	.getSize = W_getSize, .createVkSurface = W_createVkSurface,
};

#endif // Vv_ENABLE_X
