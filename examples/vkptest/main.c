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

VkRenderPass rpass;

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

#define STAGE VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT

#define addSub(DATA, SCOPES, DEPENDS) ({ \
	VvVkP_State* _stats[] = SCOPES; \
	VvVkP_Dependency _deps[] = DEPENDS; \
	for(int i=0; i<sizeof(_deps)/sizeof(_deps[0]); i++) { \
		_deps[i].srcStage = STAGE; \
		_deps[i].dstStage = STAGE; \
	} \
	vkp.addSubpass(g, &(UData)DATA, 0, \
		sizeof(_stats)/sizeof(VvVkP_State*), _stats, \
		sizeof(_deps)/sizeof(VvVkP_Dependency), _deps); \
})

int main() {
	setupVk();
	setupCb();
	setupWin();
	setupSChain();

	VkResult r;

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
		2, (VvVkP_Dependency[]){
			{subs[0],STAGE,STAGE},
			{subs[1],STAGE,STAGE}
		});
	vkp.removeSubpass(g, subs[3]);

	int statcnt;
	UData* udstats = vkp.getStates(g, &statcnt);
	for(int i=0; i<statcnt; i++)
		printf("Checking State %s...\n", udstats[i].name);
	free(udstats);

	int subcnt;
	UData* udsubs = vkp.getSubpasses(g, &subcnt);
	VkSubpassDescription subdes[subcnt];
	for(int i=0; i<subcnt; i++) {
		printf("Checking Subpass %s...\n", udsubs[i].name);
		subdes[i] = (VkSubpassDescription){
			0, VK_PIPELINE_BIND_POINT_GRAPHICS,
			0, NULL,
			1, (VkAttachmentReference[]){
				{0, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL },
			}, NULL,
			NULL,
			0, NULL,
		};
	}
	free(udsubs);

	uint32_t depcnt;
	VkSubpassDependency* deps = vkp.getDepends(g, &depcnt);
	r = vk->CreateRenderPass(dev, &(VkRenderPassCreateInfo){
		VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO, NULL,
		.attachmentCount = 1,
		.pAttachments = (VkAttachmentDescription[]){
			{
				.format = format,
				.samples = VK_SAMPLE_COUNT_1_BIT,
				.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
				.storeOp = VK_ATTACHMENT_STORE_OP_STORE,
				.initialLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
				.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
			},
		},
		.subpassCount = subcnt, .pSubpasses = subdes,
		.dependencyCount = depcnt, .pDependencies = deps,
	}, NULL, &rpass);
	if(r<0) error("creating RenderPass", r);
	free(deps);

	setupFBuff();

	r = vk->BeginCommandBuffer(cb, &(VkCommandBufferBeginInfo){
		VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO, NULL,
		.pInheritanceInfo = NULL,
	});
	if(r<0) error("starting CommandBuffer", r);
	vkp.execute(g, &vkbind, cb, &(VkRenderPassBeginInfo){
		VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO, NULL,
		.renderPass = rpass, .framebuffer = fbuff,
		.renderArea = { .offset = {0,0}, .extent = extent, },
		.clearValueCount = 1, .pClearValues = (VkClearValue[]){
			{},
		},
	}, enter, leave, inside);
	vk->EndCommandBuffer(cb);

	vk->DestroyRenderPass(dev, rpass, NULL);

	vkp.destroy(g);

	cleanupFBuff();
	cleanupSChain();
	cleanupWin();
	cleanupCb();
	cleanupVk();
	return 0;
}
