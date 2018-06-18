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

#include <vivacious/vivacious.h>
#include <stdio.h>
#include <stdlib.h>

int main() {
	const char* err;
	VvWindowManager* wm = vVcreateWindowManager(&err);
	if(!wm) { fprintf(stderr, "Error creating WindowManager: %s\n", err); return 1; }

	VkExtent2D size = vVgetSize(wm);
	printf("Screen dimensions: %dx%d\n", size.width, size.height);

	VvVk* vk = vVcreateVk(&err);
	if(!vk) { fprintf(stderr, "Error creating Vk: %s\n", err); return 1; }

	VkInstance inst_I;
	VkResult r = vVvkCreateInstance(vk, &(VkInstanceCreateInfo){
		.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
		.enabledExtensionCount = wm->instinfo->extensions_cnt,
		.ppEnabledExtensionNames = wm->instinfo->extensions,
	}, NULL, &inst_I);
	if(r < 0) { fprintf(stderr, "Error creating Instance: %d\n", r); return 1; }
	VvVkInstance* inst = vVwrapVkInstance(vk, inst_I);

	size.width /= 2, size.height /= 2;
	VvWindow* win = vVnewWindow(wm, inst, size, "none", &r);
	if(!win) { fprintf(stderr, "Error creating Window: %d\n", r); return 1; }
	vVshow(win);
	vVsetTitle(win, "Test Window");

	size = vVgetSize(win);
	printf("Window dimensions: %dx%d\n", size.width, size.height);
	vVsetSize(win, (VkExtent2D){ 100, 100 });
	size = vVgetSize(win);
	printf("New window dimensions: %dx%d\n", size.width, size.height);

	vVsetFullscreen(win, true);
	size = vVgetSize(win);
	printf("Fullscreen window dimensions: %dx%d\n", size.width, size.height);

	vVdestroy(win);
	vVdestroy(wm);

	printf("Windows have been cleaned up!\n");

	vVvkDestroyInstance(inst, NULL);
	vVdestroy(inst);
	vVdestroy(vk);

	return 0;
}
