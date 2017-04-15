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

#include "common.h"
#include <vivacious/window.h>

static VvWi_Connection* conn;
static VvWi_Window* win;

void createWindow() {
	conn = vVwi_connect();

	int ext[2] = {0,0};
	vVwi_getScreenSize(conn, ext);

	win = vVwi_createWindow(conn, ext[0], ext[1], 0);
	vVwi_setTitle(win, "Example Vulkan Thing!");
	vVwi_showWindow(win);

	VkResult r = vVwi_createVkSurface(win, com.inst, &com.surf);
	if(r<0) error("Error creating surface: %d!\n", r);
}

void destroyWindow() {
	vVvk_DestroySurfaceKHR(com.inst, com.surf, NULL);
	vVwi_destroyWindow(win);
	vVwi_disconnect(conn);
}
