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

#include <vivacious/window.h>
#include <stdio.h>
#include <stdlib.h>

#define wi vVwi_X		// Should really be _test

int main() {
	VvWi_Connection* con = wi.connect();

	int size[2];
	wi.getScreenSize(con, size);
	printf("Screen dimensions: %dx%d\n", size[0], size[1]);

	VvWi_Window* win = wi.createWindow(con, size[0] / 2, size[1] / 2, 0);
	wi.showWindow(win);
	wi.setTitle(win, "Test Window");

	wi.getWindowSize(win, size);
	printf("Window dimensions: %dx%d\n", size[0], size[1]);
	size[0] = 100;
	size[1] = 100;
	wi.setWindowSize(win, size);
	wi.getWindowSize(win, size);
	printf("New window dimensions: %dx%d\n", size[0], size[1]);

	wi.setFullscreen(win, 1);
	wi.getWindowSize(win, size);
	printf("Fullscreen window dimensions: %dx%d\n", size[0], size[1]);

	wi.destroyWindow(win);
	wi.disconnect(con);

	return 0;
}
