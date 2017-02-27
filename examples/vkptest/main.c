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

void enter(const VvVk_Binding* vkb, void* name, VkCommandBuffer cb) {
	printf("Setting State %s!\n", (char*)name);
}

void leave(const VvVk_Binding* vkb, void* name, VkCommandBuffer cb) {
	printf("Unsetting State %s!\n", (char*)name);
}

void inside(const VvVk_Binding* vkb, void* name, VkCommandBuffer cb) {
	printf("Executing Command %s!\n", (char*)name);
}

#define addCmd(NAME, SCOPES, DEPENDS) ({ \
	VvVkP_State* _stats[] = SCOPES; \
	VvVkP_Dependency _deps[] = DEPENDS; \
	vkp.addCommand(g, NAME, 0, \
		sizeof(_stats)/sizeof(VvVkP_State*), _stats, \
		sizeof(_deps)/sizeof(VvVkP_Dependency), _deps); \
})

int main() {
	setupVk();
	setupCb();

	VvVkP_Graph* g = vkp.create(100);	// 100 chars for names

	VvVkP_State* stats[] = {
		vkp.addState(g, "1"),
		vkp.addState(g, "2"),
	};

	VvVkP_Command* cmds[4];
	cmds[0] = addCmd("1:1", { stats[0] }, {});
	cmds[1] = addCmd("1:2", { stats[0] }, { cmds[0] });
	cmds[2] = addCmd("2:1", { stats[1] }, { cmds[0] });
	cmds[3] = addCmd("2:2", { stats[1] }, { cmds[2] });

	vkp.addDepends(g, cmds[2],
		2, (VvVkP_Dependency[]){ {cmds[0]}, {cmds[1]} });
	vkp.removeCommand(g, cmds[3]);

	vkp.execute(g, NULL, NULL, NULL, enter, leave, inside);

	vkp.destroy(g);

	cleanupCb();
	cleanupVk();
	return 0;
}
