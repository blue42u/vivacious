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

void enter(void* ud, VkCommandBuffer cb) {
	printf("Entering scope %s {\n", (const char*)ud);
}

void leave(void* ud, VkCommandBuffer cb) {
	printf("} Leaving scope %s;\n", (const char*)ud);
}

void inside(void* ud, VkCommandBuffer cb) {
	printf("Doing Op %s;\n", (const char*)ud);
}

#define addOp(NAME, SCOPES, DEPENDS) ({ \
	VvVkP_Scope* _scps[] = SCOPES; \
	VvVkP_Dependency _deps[] = DEPENDS; \
	vkp.addOperation(b, NULL, inside, NAME, \
		sizeof(_scps)/sizeof(VvVkP_Scope*), _scps, \
		sizeof(_deps)/sizeof(VvVkP_Dependency), _deps); \
})

int main() {
	setupVk();
	setupCb();

	VvVkP_Builder* b = vkp.create(&vkbind, 0, NULL);

	VvVkP_Scope* sps[] = {
		vkp.addScope(b, enter, leave, "1", VK_FALSE, 0),
		vkp.addScope(b, enter, leave, "2", VK_FALSE, 0),
	};

	VvVkP_Operation* ops[3];
	ops[0] = addOp("1:1", { sps[0] }, {});
	ops[1] = addOp("1:2", { sps[0] }, { ops[0] });
	ops[2] = addOp("2:1", { sps[1] }, { ops[0] });

	vkp.depends(b, ops[2], 2, (VvVkP_Dependency[]){ {ops[0]}, {ops[1]} });
	vkp.removeOperation(b, ops[1]);

	vkp.destroy(b);

	cleanupCb();
	cleanupVk();
	return 0;
}
