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

#include "common.h"
#include <vivacious/window.h>

#define winapi vVwi_X

static VvWi_Connection* conn;
static VvWi_Window* win;

void createWindow() {
	conn = winapi.Connect();

	int ext[2] = {0,0};
	winapi.GetScreenSize(conn, ext);

	win = winapi.CreateWindow(conn, ext[0], ext[1], 0);
	winapi.SetTitle(win, "Example Vulkan Thing!");
	winapi.ShowWindow(win);

	VkResult r = winapi.CreateVkSurface(win, com.inst, &com.surf, &vkb);
	if(r<0) error("Error creating surface: %d!\n", r);
}

void destroyWindow() {
	vks->DestroySurfaceKHR(com.inst, com.surf, NULL);
	winapi.DestroyWindow(win);
	winapi.Disconnect(conn);
}
