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

#include <vivacious/vkbplate.h>
#include <stdio.h>
#include <stdlib.h>

#include <unistd.h>

#define vkb vVvkb_test		// Choose our imp.
#define vVvk vVvk_lib

void error(const char* m, VkResult r) {
	if(r != 0) fprintf(stderr, "Error: %s! (%d)\n", m, r);
	else fprintf(stderr, "Error: %s!\n", m);
	exit(1);
}

int main() {
	VvVk_Binding* bind = vVvk.Create();
	const VvVk_1_0* vk = vVvk.core->vk_1_0(bind);
	VvVkB_InstInfo* ii = vkb.createInstInfo("VkBoilerplate Test",
		VK_MAKE_VERSION(1,0,0));

	vkb.setVersion(ii, VK_MAKE_VERSION(1,0,0));
	vkb.addLayers(ii, (const char*[]){
		"VK_LAYER_LUNARG_standard_validation", NULL });
	vkb.addInstExtensions(ii, (const char*[]){
		"VK_KHR_surface", "VK_KHR_xcb_surface", NULL });

	VkInstance inst;
	VkResult r = vkb.createInstance(vk, ii, &inst);
	if(r<0) error("Could not create instance", r);

	vVvk.LoadInstance(bind, inst, VK_FALSE);
	vk->DestroyInstance(inst, NULL);

	vVvk.Destroy(bind);

	sleep(1);

	return 0;
}
