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

#define VK_USE_PLATFORM_XCB_KHR
#include <vivacious/window.h>
#include "internal.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "xcb.h"

struct VvWindowManager {
	struct VvWindowManager_P _P;
	xcb_connection_t* conn;		// Connection to the X server
	xcb_screen_t* screen;		// Preferred Screen
	xcb_ewmh_connection_t ewmh;	// Extended Window Manager Hints
	Xcb xcb;			// libxcb data, with commands
};
static const struct VvWindowManager_M VvWindowManager_IMPM;

struct VvWindowManagerWindow {
	struct VvWindowManagerWindow_P _P;
	xcb_window_t id;	// The window's id
};
static const struct VvWindowManagerWindow_M VvWindowManagerWindow_IMPM;

VvWindowManager libVv_createWindowManager_X() {
	VvWindowManager_R self = malloc(sizeof(struct VvWindowManager));
	self->_P._M = &VvWindowManager_IMPM;

	if(_vVlibxcb(&self->xcb)) {
		free(self);
		return NULL;
	}

	int screen;
	self->conn = self->xcb.connect(NULL, &screen);
	if(!self->conn) {
		free(self);
		return NULL;
	}

	xcb_screen_iterator_t sit = self->xcb.setup_roots_iterator(
		self->xcb.get_setup(self->conn));
	for(int i=0; i<screen; i++) self->xcb.screen_next(&sit);
	self->screen = sit.data;

	if(self->xcb.ewmh_init_atoms) { // If we have EWMH support
		xcb_intern_atom_cookie_t* cookie
			= self->xcb.ewmh_init_atoms(self->conn, &self->ewmh);
		if(!self->xcb.ewmh_init_atoms_replies(&self->ewmh, cookie, NULL)) {
			self->xcb.disconnect(self->conn);
			free(self);
			return NULL;
		}
	}

	return (VvWindowManager)self;
}

static VvWindowManager_destroy_IMP
	if(self_R->xcb.ewmh_init_atoms) {
		xcb_ewmh_connection_wipe(&self_R->ewmh);
	}
	self_R->xcb.disconnect(self_R->conn);
	_vVfreexcb(&self_R->xcb);
	free(self_R);
}

static VvWindowManager_getSize_IMP
	xcb_get_geometry_cookie_t cookie = self_R->xcb.get_geometry(
		self_R->conn, self_R->screen->root);
	xcb_get_geometry_reply_t* geom = self_R->xcb.get_geometry_reply(
		self_R->conn, cookie, NULL);
	VkExtent2D out = {0,0};
	if(geom) {
		out.width = geom->width;
		out.height = geom->height;
		free(geom);
	}
	return out;
}

static VvWindowManager_getInstanceInfo_IMP
	return VvVkInstanceCreatorInfo_V(
		Vv_ARRAY(extensions, (const char*[]){"VK_KHR_xcb_surface"}),
	);;
}

static VvWindowManager_newWindow_IMP
	VvWindowManagerWindow_R w = malloc(sizeof(struct VvWindowManagerWindow));
	w->_P._M = &VvWindowManagerWindow_IMPM;
	w->_P.windowmanager = self;

	w->id = self_R->xcb.generate_id(self_R->conn);
	self_R->xcb.create_window(self_R->conn, XCB_COPY_FROM_PARENT, w->id,
		self_R->screen->root, XCB_NONE, XCB_NONE,
		extent.width, extent.height,
		10, XCB_WINDOW_CLASS_INPUT_OUTPUT,
		self_R->screen->root_visual,
		0, NULL);
	self_R->xcb.flush(self_R->conn);
	return (VvWindowManagerWindow)w;
}

#define WM ((VvWindowManager_R)self->windowmanager)
static VvWindowManagerWindow_destroy_IMP
	WM->xcb.destroy_window(WM->conn, self_R->id);
	WM->xcb.flush(WM->conn);
	free(self_R);
}

static VvWindowManagerWindow_show_IMP
	WM->xcb.map_window(WM->conn, self_R->id);
	WM->xcb.flush(WM->conn);
}

static VvWindowManagerWindow_setTitle_IMP
	WM->xcb.change_property(WM->conn,
		XCB_PROP_MODE_REPLACE, self_R->id,
		XCB_ATOM_WM_NAME, XCB_ATOM_STRING, 8,
		strlen(title), title);
	WM->xcb.flush(WM->conn);
}

static VvWindowManagerWindow_setFullscreen_IMP
	if(WM->xcb.ewmh_init_atoms && WM->ewmh._NET_WM_STATE_FULLSCREEN) {
		xcb_atom_t at = 0;
		if(enabled) at |= WM->ewmh._NET_WM_STATE_FULLSCREEN;
		WM->xcb.change_property(
			WM->conn, XCB_PROP_MODE_REPLACE, self_R->id,
			WM->ewmh._NET_WM_STATE, XCB_ATOM_ATOM, 32,
			1, &at);
		WM->xcb.flush(WM->conn);
	} else fprintf(stderr, "Attempted fullscreen without EWMH!\n");
}

static VvWindowManagerWindow_setSize_IMP
	uint32_t values[] = { extent.width, extent.height };
	WM->xcb.configure_window(WM->conn, self_R->id,
		XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT,
		values);
	WM->xcb.flush(WM->conn);
}

static VvWindowManagerWindow_getSize_IMP
	xcb_get_geometry_cookie_t cookie = WM->xcb.get_geometry(WM->conn, self_R->id);
	xcb_get_geometry_reply_t* geom =
		WM->xcb.get_geometry_reply(WM->conn, cookie, NULL);
	VkExtent2D ext = {0,0};
	if(geom) {
		ext.width = geom->width;
		ext.height = geom->height;
		free(geom);
	}
	return ext;
}

static VvWindowManagerWindow_createVkSurface_IMP
	VkResult dres;
	if(!ret1) ret1 = &dres;
	if(!instance->_M->vkCreateXcbSurfaceKHR) {
		*ret1 = VK_ERROR_EXTENSION_NOT_PRESENT;
		return NULL;
	}
	VkSurfaceKHR surf;
	*ret1 = vVvkCreateXcbSurfaceKHR(instance, &VkXcbSurfaceCreateInfoKHR_V(
		.connection = WM->conn, .window = self->id,
	), NULL, &surf);
	if(*ret1 < 0) return NULL;
	else return vVwrapVkSurfaceKHR(surf, instance);
}

static const VvWindowManager_IMP;
static const VvWindowManagerWindow_IMP;

#endif // Vv_ENABLE_X
