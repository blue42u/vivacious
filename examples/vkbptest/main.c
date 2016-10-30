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

#define vkbp vVvkbp_first	// Choose our imp.
#define vVvk vVvk_lib

int main() {
	VvVk_Binding* bind = vVvk.Create();
	VvVkBp_Rules* rules = vkbp.Create(&vVvk, bind);

	int verid = vkbp.Version(rules, VK_MAKE_VERSION(2,0,0));
	int layid = vkbp.Layer(rules, "VK_LAYER_LUNARG_standard_validation");
	int extid = vkbp.InstanceExtension(rules, "VK_KHR_surface");

	vkbp.ApplicationInfo(rules, "Boilerplate Test", VK_MAKE_VERSION(1,0,0));

	VkInstance inst;
	int err = vkbp.ResolveInstance(rules, &inst);
	if(err != 0) {
		fprintf(stderr, "Error resolving Instance! (");
		if(err < 0) fprintf(stderr, "general");
		else {
			if(err == verid) fprintf(stderr, "version");
			else if(err == layid) fprintf(stderr, "layer");
			else if(err == extid) fprintf(stderr, "inst ext");
		}
		fprintf(stderr, ")\n");
		return 1;
	}
}
