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

#include <xcb/xcb.h>
#include <xcb/xcb_ewmh.h>

#define XCB_LIST(F) \
	F(xcb_connection_t*, connect, const char*, int*) \
	F(void, disconnect, xcb_connection_t*) \
	F(void, screen_next, xcb_screen_iterator_t*) \
	F(xcb_screen_iterator_t, setup_roots_iterator, const xcb_setup_t*) \
	F(xcb_setup_t*, get_setup, xcb_connection_t*) \
	F(xcb_window_t, generate_id, xcb_connection_t*) \
	F(xcb_void_cookie_t, create_window, xcb_connection_t*, uint8_t, xcb_window_t, xcb_window_t, int16_t, int16_t, uint16_t, uint16_t, uint16_t, uint16_t, xcb_visualid_t, uint32_t, const uint32_t*) \
	F(int, flush, xcb_connection_t*) \
	F(xcb_void_cookie_t, destroy_window, xcb_connection_t*, xcb_window_t) \
	F(xcb_void_cookie_t, map_window, xcb_connection_t*, xcb_window_t) \
	F(xcb_void_cookie_t, change_property, xcb_connection_t*, uint8_t, xcb_window_t, xcb_atom_t, xcb_atom_t, uint8_t, uint32_t, const void*) \
	F(xcb_void_cookie_t, configure_window, xcb_connection_t*, xcb_window_t, uint16_t, const uint32_t*) \
	F(xcb_get_geometry_cookie_t, get_geometry, xcb_connection_t*, xcb_drawable_t) \
	F(xcb_get_geometry_reply_t*, get_geometry_reply, xcb_connection_t*, xcb_get_geometry_cookie_t, xcb_generic_error_t**) \
// END XCB_LIST

#define EWMH_LIST(F) \
	F(xcb_intern_atom_cookie_t*, ewmh_init_atoms, xcb_connection_t*, xcb_ewmh_connection_t*) \
	F(uint8_t, ewmh_init_atoms_replies, xcb_ewmh_connection_t*, xcb_intern_atom_cookie_t*, xcb_generic_error_t**) \
// END EWMH_LIST

typedef struct {
	void* libxcb;	// Lib handle
	void* libewmh;	// Xcb EWMH support

#define _memb(T, N, ...) T (*N)(__VA_ARGS__);
	XCB_LIST(_memb)
	EWMH_LIST(_memb)
} Xcb;

int _vVlibxcb(Xcb*);
void _vVfreexcb(Xcb*);

#endif // Vv_ENABLE_X
