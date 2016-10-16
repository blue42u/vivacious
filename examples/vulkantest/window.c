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

static const VvWindow* winapi;
static VvWiConnection* conn;
static VvWiWindow* win;

void createWindow() {
	winapi = vVloadWindow_X();
	conn = winapi->Connect();

	int ext[2] = {0,0};
	winapi->GetScreenSize(conn, ext);

	win = winapi->CreateWindow(conn, ext[0], ext[1], 0);
	winapi->SetTitle(conn, win, "Example Vulkan Thing!");
	winapi->ShowWindow(conn, win);

	winapi->AddVulkan(conn, vkapi, vkb, com.inst);
	VkResult r = winapi->CreateVkSurface(conn, win, &com.surf);
	if(r<0) error("Error creating surface: %d!\n", r);
}

void destroyWindow() {
	vks->DestroySurfaceKHR(com.inst, com.surf, NULL);
	winapi->DestroyWindow(conn, win);
	winapi->Disconnect(conn);
}