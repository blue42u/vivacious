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

typedef struct {
	char name[100];
} UData;

void enter(const VvVk_Binding* vkb, void* udata, VkCommandBuffer cb) {
	UData* ud = udata;
	printf("Setting State %s!\n", ud->name);
}

void leave(const VvVk_Binding* vkb, void* udata, VkCommandBuffer cb) {
	UData* ud = udata;
	printf("Unsetting State %s!\n", ud->name);
}

void inside(const VvVk_Binding* vkb, void* udata, VkCommandBuffer cb) {
	UData* ud = udata;
	printf("Executing Subpass %s!\n", ud->name);
}

#define addSub(DATA, SCOPES, DEPENDS) ({ \
	VvVkP_State* _stats[] = SCOPES; \
	VvVkP_Dependency _deps[] = DEPENDS; \
	vkp.addSubpass(g, &(UData)DATA, 0, \
		sizeof(_stats)/sizeof(VvVkP_State*), _stats, \
		sizeof(_deps)/sizeof(VvVkP_Dependency), _deps); \
})

int main() {
	setupVk();
	setupCb();

	VvVkP_Graph* g = vkp.create(sizeof(UData));

	VvVkP_State* stats[] = {
		vkp.addState(g, "1"),
		vkp.addState(g, "2"),
	};

	VvVkP_Subpass* subs[4];
	subs[0] = addSub({"1:1"}, { stats[0] }, {});
	subs[1] = addSub({"1:2"}, { stats[0] }, { subs[0] });
	subs[2] = addSub({"2:1"}, { stats[1] }, { subs[0] });
	subs[3] = addSub({"2:2"}, { stats[1] }, { subs[2] });

	vkp.addDepends(g, subs[2],
		2, (VvVkP_Dependency[]){ {subs[0]}, {subs[1]} });
	vkp.removeSubpass(g, subs[3]);

	int statcnt;
	UData* udstats = vkp.getStates(g, &statcnt);
	for(int i=0; i<statcnt; i++)
		printf("Checking State %s...\n", udstats[i].name);
	free(udstats);

	int subcnt;
	UData* udsubs = vkp.getSubpasses(g, &subcnt);
	for(int i=0; i<subcnt; i++)
		printf("Checking Subpass %s...\n", udsubs[i].name);
	free(udsubs);

	vkp.execute(g, NULL, NULL, NULL, enter, leave, inside);

	vkp.destroy(g);

	cleanupCb();
	cleanupVk();
	return 0;
}
