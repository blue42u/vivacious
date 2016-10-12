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

typedef struct {
	void* libxcb;	// Lib handle
	xcb_connection_t* (*connect)(const char*, int*);
	void (*disconnect)(xcb_connection_t*);
	void (*screen_next)(xcb_screen_iterator_t*);
	xcb_screen_iterator_t (*setup_roots_iterator)(const xcb_setup_t*);
	const xcb_setup_t* (*get_setup)(xcb_connection_t*);
	xcb_window_t (*generate_id)(xcb_connection_t*);
	xcb_void_cookie_t (*create_window)(xcb_connection_t*,
		uint8_t, xcb_window_t, xcb_window_t, int16_t, int16_t,
		uint16_t, uint16_t, uint16_t, uint16_t,
		xcb_visualid_t, uint32_t, const uint32_t*);
	int (*flush)(xcb_connection_t*);
	xcb_void_cookie_t (*destroy_window)(xcb_connection_t*, xcb_window_t);
} Xcb;

int _vVlibxcb(Xcb*);
void _vVfreexcb(Xcb*);

#endif // Vv_ENABLE_X
