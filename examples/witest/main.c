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

#define Vv_CHOICE V
#include <vivacious/window.h>
#include <stdio.h>
#include <stdlib.h>

Vv V = {.wi=&vVwi_Default};

int main() {
	VvWi_Connection* con = vVwi_connect();

	int size[2];
	vVwi_getScreenSize(con, size);
	printf("Screen dimensions: %dx%d\n", size[0], size[1]);

	VvWi_Window* win = vVwi_createWindow(con, size[0] / 2, size[1] / 2, 0);
	vVwi_showWindow(win);
	vVwi_setTitle(win, "Test Window");

	vVwi_getWindowSize(win, size);
	printf("Window dimensions: %dx%d\n", size[0], size[1]);
	size[0] = 100;
	size[1] = 100;
	vVwi_setWindowSize(win, size);
	vVwi_getWindowSize(win, size);
	printf("New window dimensions: %dx%d\n", size[0], size[1]);

	vVwi_setFullscreen(win, 1);
	vVwi_getWindowSize(win, size);
	printf("Fullscreen window dimensions: %dx%d\n", size[0], size[1]);

	vVwi_destroyWindow(win);
	vVwi_disconnect(con);

	return 0;
}
