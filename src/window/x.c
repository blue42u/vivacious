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

#define VK_USE_PLATFORM_XCB_KHR
#include <vivacious/window.h>
#include "internal.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "xcb.h"

struct Manager_I {
	VvWindowManager _P;
	xcb_connection_t* conn;		// Connection to the X server
	xcb_screen_t* screen;		// Preferred Screen
	xcb_ewmh_connection_t ewmh;	// Extended Window Manager Hints
	Xcb xcb;			// libxcb data, with commands
};
static const struct VvWindowManager_M manager_M;

struct Window_I {
	VvWindow _P;
	xcb_window_t id;	// The window's id
};
static const struct VvWindow_M window_M;

static const char* exts[] = {"VK_KHR_surface", "VK_KHR_xcb_surface"};
static VvVkInstanceInfo iinfo = {
	.name = NULL, .version = 0,
	.extensions_cnt = sizeof(exts)/sizeof(exts[1]), .extensions = exts,
	.layers_cnt = 0, .layers = NULL,
	.vkversion = VK_MAKE_VERSION(1,0,0),
};

VvWindowManager* libVv_createWindowManager_X(const char** err) {
	struct Manager_I* self = malloc(sizeof(struct Manager_I));
	self->_P = (VvWindowManager){
		._M = &manager_M, .instinfo = &iinfo,
	};

	if(_vVlibxcb(&self->xcb)) {
		*err = "Cound not load libxcb!";
		free(self);
		return NULL;
	}

	int screen;
	self->conn = self->xcb.connect(NULL, &screen);
	if(self->xcb.connection_has_error(self->conn)) {
		switch(self->xcb.connection_has_error(self->conn)) {
			case XCB_CONN_ERROR:
				*err = "Could not connect to X server: stream error!"; break;
			case XCB_CONN_CLOSED_EXT_NOTSUPPORTED:
				*err = "Could not connect to X server: unsupported extension!"; break;
			case XCB_CONN_CLOSED_MEM_INSUFFICIENT:
				*err = "Could not connect to X server: ran out of memory!"; break;
			case XCB_CONN_CLOSED_REQ_LEN_EXCEED:
				*err = "Could not connect to X server: request length exceeded!"; break;
			case XCB_CONN_CLOSED_PARSE_ERR:
				*err = "Could not connect to X server: parse error in DISPLAY!"; break;
			case XCB_CONN_CLOSED_INVALID_SCREEN:
				*err = "Could not connect to X server: invalid screen!"; break;
			default: *err = "Could not connect to X server!";
		};
		self->xcb.disconnect(self->conn);
		_vVfreexcb(&self->xcb);
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
			*err = "Could not load EWMH atoms!";
			_vVfreexcb(&self->xcb);
			return NULL;
		}
	}

	return &self->_P;
}

#define MSELF struct Manager_I* self_R = (struct Manager_I*)_P;

static void manager_destroy(VvWindowManager* _P) { MSELF;
	if(self_R->xcb.ewmh_init_atoms) {
		xcb_ewmh_connection_wipe(&self_R->ewmh);
	}
	self_R->xcb.disconnect(self_R->conn);
	_vVfreexcb(&self_R->xcb);
	free(self_R);
}

static VkExtent2D manager_getSize(VvWindowManager* _P) { MSELF;
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

static VvWindow* manager_newWindow(VvWindowManager* _P, VvVkInstance* inst,
	VkExtent2D extent, const char* evts, VkResult* result) { MSELF;
	struct Window_I* w = malloc(sizeof(struct Window_I));
	w->_P = (VvWindow){
		._M = &window_M, .manager = _P, .instance = inst,
	};

	w->id = self_R->xcb.generate_id(self_R->conn);
	self_R->xcb.create_window(self_R->conn, XCB_COPY_FROM_PARENT, w->id,
		self_R->screen->root, XCB_NONE, XCB_NONE,
		extent.width, extent.height,
		10, XCB_WINDOW_CLASS_INPUT_OUTPUT,
		self_R->screen->root_visual,
		0, NULL);
	self_R->xcb.flush(self_R->conn);

	VkSurfaceKHR surf;
	VkResult r = vVvkCreateXcbSurfaceKHR(inst, &(VkXcbSurfaceCreateInfoKHR){
		.sType = VK_STRUCTURE_TYPE_XCB_SURFACE_CREATE_INFO_KHR,
		.connection = self_R->conn, .window = w->id,
	}, NULL, &surf);
	if(result) *result = r;
	if(r < 0) {
		self_R->xcb.destroy_window(self_R->conn, w->id);
		self_R->xcb.flush(self_R->conn);
		free(w);
		return NULL;
	} else {
		w->_P.surface = vVwrapVkSurfaceKHR(inst, surf);
		return &w->_P;
	}
}

static const struct VvWindowManager_M manager_M = {
	.destroy = manager_destroy,
	.getSize = manager_getSize, .newWindow = manager_newWindow,
};

#define WSELF struct Window_I* self_R = (struct Window_I*)_P; \
struct Manager_I* wm = (struct Manager_I*)_P->manager;

static void window_destroy(VvWindow* _P) { WSELF;
	wm->xcb.destroy_window(wm->conn, self_R->id);
	wm->xcb.flush(wm->conn);
	free(self_R);
}

static void window_show(VvWindow* _P) { WSELF;
	wm->xcb.map_window(wm->conn, self_R->id);
	wm->xcb.flush(wm->conn);
}

static void window_setTitle(VvWindow* _P, const char* title) { WSELF;
	wm->xcb.change_property(wm->conn,
		XCB_PROP_MODE_REPLACE, self_R->id,
		XCB_ATOM_WM_NAME, XCB_ATOM_STRING, 8,
		strlen(title), title);
	wm->xcb.flush(wm->conn);
}

static void window_setFullscreen(VvWindow* _P, bool enabled) { WSELF;
	if(wm->xcb.ewmh_init_atoms && wm->ewmh._NET_WM_STATE_FULLSCREEN) {
		xcb_atom_t at = 0;
		if(enabled) at |= wm->ewmh._NET_WM_STATE_FULLSCREEN;
		wm->xcb.change_property(
			wm->conn, XCB_PROP_MODE_REPLACE, self_R->id,
			wm->ewmh._NET_WM_STATE, XCB_ATOM_ATOM, 32,
			1, &at);
		wm->xcb.flush(wm->conn);
	} else fprintf(stderr, "Attempted fullscreen without EWMH!\n");
}

static void window_setSize(VvWindow* _P, VkExtent2D extent) { WSELF;
	uint32_t values[] = { extent.width, extent.height };
	wm->xcb.configure_window(wm->conn, self_R->id,
		XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT,
		values);
	wm->xcb.flush(wm->conn);
}

static VkExtent2D window_getSize(VvWindow* _P) { WSELF;
	xcb_get_geometry_cookie_t cookie = wm->xcb.get_geometry(wm->conn, self_R->id);
	xcb_get_geometry_reply_t* geom =
		wm->xcb.get_geometry_reply(wm->conn, cookie, NULL);
	VkExtent2D ext = {0,0};
	if(geom) {
		ext.width = geom->width;
		ext.height = geom->height;
		free(geom);
	}
	return ext;
}

static const struct VvWindow_M window_M = {
	.destroy = window_destroy,
	.show = window_show, .setTitle = window_setTitle,
	.setFullscreen = window_setFullscreen, .setSize = window_setSize,
	.getSize = window_getSize,
};
