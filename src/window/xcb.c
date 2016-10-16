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

#include "xcb.h"
#include "cpdl.h"

void _vVfreexcb(Xcb* xcb) {
	_vVclosedl(xcb->libxcb);
}

int _vVlibxcb(Xcb* xcb) {
	xcb->libxcb = _vVopendl("libxcb.so", "libxcb.dynlib", NULL);
	if(!xcb->libxcb) return 1;
	xcb->libewmh = _vVopendl("libxcb-ewmh.so", "libxcb-ewmh.dynlib", NULL);

	xcb->connect = _vVsymdl(xcb->libxcb, "xcb_connect");
	xcb->disconnect = _vVsymdl(xcb->libxcb, "xcb_disconnect");
	xcb->screen_next = _vVsymdl(xcb->libxcb, "xcb_screen_next");
	xcb->setup_roots_iterator = _vVsymdl(xcb->libxcb, "xcb_setup_roots_iterator");
	xcb->get_setup = _vVsymdl(xcb->libxcb, "xcb_get_setup");
	xcb->generate_id = _vVsymdl(xcb->libxcb, "xcb_generate_id");
	xcb->create_window = _vVsymdl(xcb->libxcb, "xcb_create_window");
	xcb->flush = _vVsymdl(xcb->libxcb, "xcb_flush");
	xcb->destroy_window = _vVsymdl(xcb->libxcb, "xcb_destroy_window");
	xcb->map_window = _vVsymdl(xcb->libxcb, "xcb_map_window");
	xcb->change_property = _vVsymdl(xcb->libxcb, "xcb_change_property");
	xcb->ewmh_init_atoms = _vVsymdl(xcb->libewmh, "xcb_ewmh_init_atoms");
	xcb->ewmh_init_atoms_replies = _vVsymdl(xcb->libewmh, "xcb_ewmh_init_atoms_replies");

	return 0;
}

#endif // Vv_ENABLE_X
