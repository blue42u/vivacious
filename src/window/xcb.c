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

#define _libxcb(T, N, ...) xcb->N = _vVsymdl(xcb->libxcb, "xcb_" #N);
	XCB_LIST(_libxcb)

#define _libewmh(T, N, ...) xcb->N = _vVsymdl(xcb->libewmh, "xcb_" #N);
	EWMH_LIST(_libewmh)

	return 0;
}

#endif // Vv_ENABLE_X
