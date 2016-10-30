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

#define vkbp vVvkbp_sum		// Choose our imp.
#define vVvk vVvk_lib

int main() {
	VvVk_Binding* bind = vVvk.Create();
	const VvVk_1_0* vk = vVvk.core->vk_1_0(bind);
	VvVkBp_Rules* rules = vkbp.create(&vVvk, bind);

	int verid = vkbp.addVersion(rules, 0, VK_MAKE_VERSION(1,1,0));
	int layid = vkbp.addLayer(rules, 0,
		"VK_LAYER_LUNARG_standard_validation");
	int extid = vkbp.addInstExt(rules, 0, "VK_KHR_surface");
	int apid =  vkbp.addAppInfo(rules, 0, "Boilerplate Test",
		VK_MAKE_VERSION(1,0,0));

	VkInstance inst;
	vkbp.setInstance(rules, &inst);

	int err;
	if((err = vkbp.resolve(rules))) {
		fprintf(stderr, "Error resolving! (");
		if(err < 0) fprintf(stderr, "general %d", err);
		else {
			if(err == verid) fprintf(stderr, "version");
			else if(err == layid) fprintf(stderr, "layer");
			else if(err == extid) fprintf(stderr, "inst ext");
			else if(err == apid) fprintf(stderr, "appinfo");
		}
		fprintf(stderr, ")\n");
		return 1;
	}

	fprintf(stderr, "Success! Now to clean up this mess...\n");

	vVvk.LoadInstance(bind, inst, VK_FALSE);
	vk->DestroyInstance(inst, NULL);

	return 0;
}
