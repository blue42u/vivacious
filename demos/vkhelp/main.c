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
#include "shaders.h"
#include "debug.h"
#include <stdio.h>
#include <time.h>

#define Vv_CHOICE V
Vv V;

// Userdata and callbacks for the Graph's State transitions
typedef struct {
	VkBuffer vbuff[2];
	VkShaderModule shader;
	VkPipeline pipe;
} Bind;
void set(void* ud, void* bind, VkCommandBuffer cb) {
	Bind* b = bind;
	if(b->vbuff[0]) vVvk_CmdBindVertexBuffers(cb, 0, 2, b->vbuff,
		(VkDeviceSize[]){0, 0});
	if(b->pipe) vVvk_CmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_GRAPHICS,
		b->pipe);
}

// Callback for the Graph's Steps
void cmd(void* ud, void* inst, VkCommandBuffer cb) {
	vVvk_CmdDraw(cb, 3, 1, 0, *(uint32_t*)inst);
}

// Callback for the Graph to identify the SubpassDescription. We have 1.
VkSubpassDescription spass(void* ud, size_t nsps, void** sps, size_t nsts, void** sts) {
	return (VkSubpassDescription){
		.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
		.colorAttachmentCount = 1,
		.pColorAttachments = (VkAttachmentReference*)ud,
	};
}

int main() {
	V = vV();

	// First we need a window, so we can actually display things
	VvWi_Connection* con = vVwi_connect();
	if(!con) error("Connecting to the Window manager", 0);
	VvWi_Window* win = vVwi_createWindow(con, 720, 720, 0);
	if(!win) error("Creating Window", 0);
	vVwi_setTitle(win, "Vulkan Helper Demo");
	vVwi_showWindow(win);

	// Then the Vulkan Instance, with the ability to draw on the window
	vVvk_load();	// Load the first Vk commands
	VkInstance inst;
	VkResult r = vVvkb_createInstance(&VvVkB_InstInfo(
		.name = "Vulkan Helper Demo", .version = 0,
		Vv_ARRAY(layers, (const char*[]){
			"VK_LAYER_LUNARG_standard_validation",	// Validation
		}),
		Vv_ARRAY(extensions, (const char*[]){
			"VK_EXT_debug_report",	// For debug.c
			"VK_KHR_surface",	// For the window
			vVwi_getVkExtension(con),	// Also for the window
		}),
	), &inst);
	if(r < 0) error("Creating Instance", r);
	vVvk_loadInst(inst, 0);		// Load the Instance-level Vk commands

	// Now we need the Surface, so that we can choose our Device properly
	VkSurfaceKHR surf;
	r = vVwi_createVkSurface(win, inst, &surf);
	if(r < 0) error("Creating Surface", r);

	// Then the PhysicalDevice and Device, with a GRAPHICS queue
	VkPhysicalDevice pdev;
	VkDevice dev;
	VvVkB_QueueSpec qs;
	r = vVvkb_createDevice(&VvVkB_DevInfo(
		.surface = surf,
		Vv_ARRAY(extensions, (const char*[]){
			"VK_KHR_swapchain",
		}),
		Vv_ARRAY(tasks, (VvVkB_TaskInfo[]){
			{.flags=VK_QUEUE_GRAPHICS_BIT, .presentable=1},
		}),
		.features = {
			.wideLines = VK_TRUE,
		},
	), inst, &dev, &pdev, &qs);
	if(r < 0) error("Creating Device", r);
	vVvk_loadDev(dev, 1);	// Load all the commands, at Device-level
	VkQueue q;
	vVvk_GetDeviceQueue(dev, qs.family, qs.index, &q);	// Need the Q

	// Now for the swapchain, so we have someplace to put our pixels
	VkSwapchainKHR swap;
	uint32_t icnt;
	VkSwapchainCreateInfoKHR swci = {
		.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
		.imageColorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
		.imageExtent = {720, 720},
		.imageArrayLayers = 1,
		.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
		.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE,
		.preTransform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
		.presentMode = VK_PRESENT_MODE_IMMEDIATE_KHR,
		.clipped = VK_TRUE,
	};
	r = vVvkb_createSwapchain(pdev, dev, surf, &swci,
	1, (VkFormatProperties){0, VK_FORMAT_FEATURE_COLOR_ATTACHMENT_BIT},
		&swap, &icnt);
	if(r < 0) error("Creating Swapchain", r);
	VkImage imgs[icnt];
	vVvk_GetSwapchainImagesKHR(dev, swap, &icnt, imgs);

	// We also need a Buffer for the vertex data
	VkBuffer buff;
	r = vVvk_CreateBuffer(dev, &(VkBufferCreateInfo){
		.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
		.size = 9*sizeof(float),
		.usage = VK_BUFFER_USAGE_VERTEX_BUFFER_BIT
			| VK_BUFFER_USAGE_TRANSFER_DST_BIT,
		.sharingMode = VK_SHARING_MODE_EXCLUSIVE,
	}, NULL, &buff);
	if(r < 0) error("Creating Buffer", r);

	// ...and a Buffer for the rotation data
	VkBuffer rotbuff;
	r = vVvk_CreateBuffer(dev, &(VkBufferCreateInfo){
		.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
		.size = 4*sizeof(float),
		.usage = VK_BUFFER_USAGE_VERTEX_BUFFER_BIT
			| VK_BUFFER_USAGE_TRANSFER_DST_BIT,
		.sharingMode = VK_SHARING_MODE_EXCLUSIVE,
	}, NULL, &rotbuff);
	if(r < 0) error("Creating rotation Buffer", r);

	// ... And the memory for said Buffers
	VvVkM_Pool* pool = vVvkm_create(pdev, dev);
	vVvkm_registerBuffer(pool, buff,0,VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
	vVvkm_registerBuffer(pool, rotbuff, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
		VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
	r = vVvkm_bind(pool);
	if(r < 0) error("Binding Memory", r);

	// The one Buffer we want to access via host memory. Let's get a pointer.
	void* rbuff_void;
	r = vVvkm_mapBuffer(pool, rotbuff, &rbuff_void);
	if(r < 0) error("Mapping memory", r);
	float* rbuff = rbuff_void;

	// Now for some command buffers so that we can actually do things
	VkCommandPool cpool;
	r = vVvk_CreateCommandPool(dev, &(VkCommandPoolCreateInfo){
		.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
		.queueFamilyIndex = qs.family,
	}, NULL, &cpool);
	if(r < 0) error("Creating CommandPool", r);

	VkCommandBuffer render[icnt];
	r = vVvk_AllocateCommandBuffers(dev, &(VkCommandBufferAllocateInfo){
		.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
		.commandPool = cpool,
		.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
		.commandBufferCount = icnt,
	}, render);
	if(r < 0) error("Allocating CommandBuffers", r);

	// Side note, we *do* have to load the vertex data. Use render[0].
	r = vVvk_BeginCommandBuffer(render[0], &(VkCommandBufferBeginInfo){
		.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
		.pInheritanceInfo = NULL,
	});
	if(r < 0) error("Beginning CommandBuffer", r);
	vVvk_CmdUpdateBuffer(render[0], buff, 0, 6*sizeof(float), (float[]){
		.2, .6,
		.2, -.6,
		.6, .6,
	});

	// We're also going to transition the Swapchain into the PRESENT layout
	VkImageMemoryBarrier imb[icnt];
	for(int i=0; i<icnt; i++) {
		imb[i] = (VkImageMemoryBarrier){
			.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
			.srcAccessMask = VK_ACCESS_MEMORY_WRITE_BIT,
			.dstAccessMask = VK_ACCESS_MEMORY_WRITE_BIT,
			.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED,
			.newLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
			.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
			.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
			.image = imgs[i],
			.subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0,1, 0,1},
		};
	}
	vVvk_CmdPipelineBarrier(render[0],
		VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
		VK_PIPELINE_STAGE_ALL_GRAPHICS_BIT,
		0,
		0, NULL,
		0, NULL,
		icnt, imb);

	vVvk_EndCommandBuffer(render[0]);
	vVvk_QueueSubmit(q, 1, &(VkSubmitInfo){
		.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
		.commandBufferCount = 1,
		.pCommandBuffers = &render[0],
	}, NULL);
	vVvk_QueueWaitIdle(q);	// Wait for it to finish, sync.

	// Now we load a Bank with the 5 shader components...
	VvVkS_Bank* bank = vVvks_createBank();
	#define C(VN, SN) VvVkS_Component* VN = vVvks_loadShader(bank, \
		&(VkShaderModuleCreateInfo){ \
			.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO, \
			.codeSize = sizeof(SN), \
			.pCode = SN, \
		});
	C(Cload, spv_load);
	C(Csmall, spv_small);
	C(Cbase, spv_base);
	C(Crecolor, spv_recolor);
	C(Crender, spv_render);

	// ...and construct the 4 shaders out of those components
	struct {
		VkShaderModule ad, AD, bc, BC;
	} shader;
	r = vVvks_construct(bank, dev, 3, (VvVkS_Component*[]){
		Cload, Cbase, Crender
	}, &shader.AD);
	if(r < 0) error("Constructing AD's shader!", r);
	r = vVvks_construct(bank, dev, 4, (VvVkS_Component*[]){
		Cload, Csmall, Cbase, Crender
	}, &shader.ad);
	if(r < 0) error("Constructing ad's shader!", r);
	r = vVvks_construct(bank, dev, 4, (VvVkS_Component*[]){
		Cload, Cbase, Crecolor, Crender
	}, &shader.BC);
	if(r < 0) error("Constructing BC's shader!", r);
	r = vVvks_construct(bank, dev, 5, (VvVkS_Component*[]){
		Cload, Csmall, Cbase, Crecolor, Crender
	}, &shader.bc);
	if(r < 0) error("Constructing bc's shader!", r);

	// Now for a RenderPass, we first need to specify the Graph...
	VvVkP_Graph* g = vVvkp_create();
	struct {
		Bind vbuff, ad, AD, bc, BC;
	} binds = {{.vbuff={buff, rotbuff}},
		{.shader=shader.ad}, {.shader=shader.AD},
		{.shader=shader.bc}, {.shader=shader.BC}};
	struct {
		VvVkP_State *vbuff, *ad, *AD, *bc, *BC;
	} states = {vVvkp_addState(g, &binds.vbuff, 0),
		vVvkp_addState(g, &binds.ad, 1),
		vVvkp_addState(g, &binds.AD, 1),
		vVvkp_addState(g, &binds.bc, 1),
		vVvkp_addState(g, &binds.BC, 1)};
	uint32_t insts[] = {0, 1, 2, 3};
	struct {
		VvVkP_Step *a, *A, *b, *B, *c, *C, *d, *D;
	} steps;
	#define DEP(S) &VvVkP_Dependency(.step=steps.S, \
		.srcStage=VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, \
		.dstStage=VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT)
	steps.c = vVvkp_addStep(g, &insts[2], 0, 2, (VvVkP_State*[]){states.vbuff,
		states.bc}, 0, NULL);
	steps.b = vVvkp_addStep(g, &insts[1], 0, 2, (VvVkP_State*[]){states.vbuff,
		states.bc}, 1, (VvVkP_Dependency*[]){ DEP(c) });
	steps.D = vVvkp_addStep(g, &insts[3], 0, 2, (VvVkP_State*[]){states.vbuff,
		states.AD}, 0, NULL);
	steps.C = vVvkp_addStep(g, &insts[2], 0, 2, (VvVkP_State*[]){states.vbuff,
		states.BC}, 1, (VvVkP_Dependency*[]){ DEP(D) });
	steps.B = vVvkp_addStep(g, &insts[1], 0, 2, (VvVkP_State*[]){states.vbuff,
		states.BC}, 2, (VvVkP_Dependency*[]){ DEP(C), DEP(b) });
	steps.d = vVvkp_addStep(g, &insts[3], 0, 2, (VvVkP_State*[]){states.vbuff,
		states.ad}, 1, (VvVkP_Dependency*[]){ DEP(B) });
	steps.A = vVvkp_addStep(g, &insts[0], 0, 2, (VvVkP_State*[]){states.vbuff,
		states.AD}, 1, (VvVkP_Dependency*[]){ DEP(B) });
	steps.a = vVvkp_addStep(g, &insts[0], 0, 2, (VvVkP_State*[]){states.vbuff,
		states.ad}, 1, (VvVkP_Dependency*[]){ DEP(A) });

	// ...and then build the RenderPass out of it.
	VkAttachmentDescription ad = {
		.format = swci.imageFormat,
		.samples = VK_SAMPLE_COUNT_1_BIT,
		.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
		.storeOp = VK_ATTACHMENT_STORE_OP_STORE,
		.initialLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
		.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
	};
	VkAttachmentReference ar = {
		.attachment = 0,
		.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
	};
	VkRenderPass rpass = vVvkp_getRenderPass(g, dev, 1, &ad, spass, &ar, &r);
	if(!rpass) error("Getting render pass!", r);

	// Now for Pipelines. This is just the ton of settings it takes.
	VkPipelineVertexInputStateCreateInfo pvisci = {
		.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		.vertexBindingDescriptionCount = 2,
		.pVertexBindingDescriptions = (VkVertexInputBindingDescription[]){
			{
				.binding = 0,
				.stride = 2*sizeof(float),
				.inputRate = VK_VERTEX_INPUT_RATE_VERTEX,
			}, {
				.binding = 1,
				.stride = sizeof(float),
				.inputRate = VK_VERTEX_INPUT_RATE_INSTANCE,
			}
		},
		.vertexAttributeDescriptionCount = 2,
		.pVertexAttributeDescriptions = (VkVertexInputAttributeDescription[]){
			{
				.location = 0,
				.binding = 0,
				.format = VK_FORMAT_R32G32_SFLOAT,
			}, {
				.location = 1,
				.binding = 1,
				.format = VK_FORMAT_R32_SFLOAT,
			}
		},
	};
    VkPipelineInputAssemblyStateCreateInfo piasci = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
    };
	VkPipelineViewportStateCreateInfo pvsci = {
		.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		.viewportCount = 1,
		.pViewports = &(VkViewport){
			0, 0, swci.imageExtent.width, swci.imageExtent.height, -1, 1,
		},
		.scissorCount = 1,
		.pScissors = &(VkRect2D){
			.offset = {0,0},
			.extent = swci.imageExtent,
		},
	};
	VkPipelineRasterizationStateCreateInfo prsci = {
		.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		.polygonMode = VK_POLYGON_MODE_FILL,
		.frontFace = VK_FRONT_FACE_CLOCKWISE,
		.lineWidth = 3,
	};
	VkPipelineMultisampleStateCreateInfo pmsci = {
		.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT,
	};
	VkPipelineColorBlendStateCreateInfo pcbsci = {
		.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		.attachmentCount = 1,
		.pAttachments = &(VkPipelineColorBlendAttachmentState){
			.colorWriteMask = VK_COLOR_COMPONENT_R_BIT
				| VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT
				| VK_COLOR_COMPONENT_A_BIT,
		},
	};

	VkPipelineLayout pl;
	r = vVvk_CreatePipelineLayout(dev, &(VkPipelineLayoutCreateInfo){
		.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
	}, NULL, &pl);

	// Now we go through the States and make pipelines for the ones with shaders
	size_t stcnt = vVvkp_getStates(g, NULL, NULL);
	void** stats = malloc(stcnt*sizeof(void*));
	int* spinds = malloc(stcnt*sizeof(void*));
	VkGraphicsPipelineCreateInfo* gpcis = malloc(stcnt*sizeof(VkGraphicsPipelineCreateInfo));
	VkPipelineShaderStageCreateInfo* psscis = malloc(2*stcnt*sizeof(VkPipelineShaderStageCreateInfo));
	stcnt = vVvkp_getStates(g, stats, spinds);
	size_t pcnt = 0;
	for(size_t i = 0; i < stcnt; i++) {
		Bind* b = stats[i];
		if(b->shader) {
			psscis[2*pcnt] = (VkPipelineShaderStageCreateInfo){
				.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
				.stage = VK_SHADER_STAGE_FRAGMENT_BIT,
				.module = b->shader,
				.pName = "main",
			};
			psscis[2*pcnt+1] = (VkPipelineShaderStageCreateInfo){
				.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
				.stage = VK_SHADER_STAGE_VERTEX_BIT,
				.module = b->shader,
				.pName = "main",
			};
			gpcis[pcnt] = (VkGraphicsPipelineCreateInfo){
				.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
				.stageCount = 2, .pStages = &psscis[2*pcnt],
				.pVertexInputState = &pvisci,
	            .pInputAssemblyState = &piasci,
				.pViewportState = &pvsci,
				.pRasterizationState = &prsci,
				.pMultisampleState = &pmsci,
				.pColorBlendState = &pcbsci,
				.layout = pl,
				.renderPass = rpass,
				.subpass = spinds[i],
			};
			pcnt++;
		}
	}
	free(spinds);

	// ...and copy over the Pipeline to the State for easy access
	VkPipeline* pipes = malloc(stcnt*sizeof(VkPipeline));
	r = vVvk_CreateGraphicsPipelines(dev, NULL, pcnt, gpcis, NULL, pipes);
	pcnt = 0;
	for(size_t i = 0; i < stcnt; i++) {
		Bind* b = stats[i];
		if(b->shader) {
			b->pipe = pipes[pcnt];
			pcnt++;
		}
	}
	free(stats);
	free(psscis);
	free(gpcis);

	// Now to record the render operations in the command buffers
	vVvk_ResetCommandPool(dev, cpool, 0);
	VkImageView ivs[icnt];
	VkFramebuffer fbs[icnt];
	for(int i = 0; i < icnt; i++) {
		// Create the ImageView for this particular image in the Swapchain
		r = vVvk_CreateImageView(dev, &(VkImageViewCreateInfo){
			.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
			.image = imgs[i],
			.viewType = VK_IMAGE_VIEW_TYPE_2D,
			.format = swci.imageFormat,
			.subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0,1, 0,1},
		}, NULL, &ivs[i]);
		if(r < 0) error("Creating ImageView!", r);

		// Create the FrameBuffer for this particular image in the Swapchain
		r = vVvk_CreateFramebuffer(dev, &(VkFramebufferCreateInfo){
			.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
			.renderPass = rpass,
			.attachmentCount = 1,
			.pAttachments = &ivs[i],
			.width = swci.imageExtent.width, .height = swci.imageExtent.height,
			.layers = 1,
		}, NULL, &fbs[i]);
		if(r < 0) error("Creating Framebuffer!", r);

		// Begin the CommandBuffer
		r = vVvk_BeginCommandBuffer(render[i], &(VkCommandBufferBeginInfo){
			.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
		});
		if(r < 0) error("Beginning CommandBuffer!", r);

		// Record the Graph, with all the render operations
		vVvkp_record(g, render[i], &(VkRenderPassBeginInfo){
			.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
			.renderPass = rpass, .framebuffer = fbs[i],
			.renderArea = {{0,0}, swci.imageExtent},
			.clearValueCount = 1,
			.pClearValues = &(VkClearValue){.color={.float32={0,0,0,1}}},
		}, &imgs[i], set, NULL, NULL, NULL, cmd, NULL);

		r = vVvk_EndCommandBuffer(render[i]);
		if(r < 0) error("Ending CommandBuffer!", r);
	}

	// We need 2 Semaphores to sequence rendering and access to the screen
	VkSemaphore draw, pres;
	r = vVvk_CreateSemaphore(dev, &(VkSemaphoreCreateInfo){
		.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
	}, NULL, &draw);
	if(r < 0) error("Creating Seamphore!", r);
	r = vVvk_CreateSemaphore(dev, &(VkSemaphoreCreateInfo){
		.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
	}, NULL, &pres);
	if(r < 0) error("Creating Seamphore!", r);

	// And a bunch of Fences to make sure we don't close up shop too early
	VkFence fences[icnt];
	for(int i=0; i<icnt; i++) {
		r = vVvk_CreateFence(dev, &(VkFenceCreateInfo){
			.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
			.flags = VK_FENCE_CREATE_SIGNALED_BIT,
		}, NULL, &fences[i]);
		if(r < 0) error("Creating Fences!", r);
	}

#define time() ({ \
	struct timespec t; \
	clock_gettime(CLOCK_MONOTONIC, &t); \
	t.tv_sec + t.tv_nsec/1000000000.; \
})

	// And now for the main loop
	int fcnt = 0;
	rbuff[0] = rbuff[1] = rbuff[2] = rbuff[3] = 0;
	double start = time(), tim;
	while((tim = time() - start) < 5) {
		// First get the next image to render into
		uint32_t i;
		r = vVvk_AcquireNextImageKHR(dev, swap, UINT64_MAX, draw, NULL, &i);
		if(r < 0) error("Acquiring image!", r);

		// Wait for the CommandBuffer to finish up, so we can use it again
		r = vVvk_WaitForFences(dev, 1, &fences[i], VK_TRUE, UINT64_MAX);
		if(r < 0) error("Waiting for Fence!", r);
		r = vVvk_ResetFences(dev, 1, &fences[i]);
		if(r < 0) error("Resetting Fence!", r);

		// Submit the CommandBuffer
		r = vVvk_QueueSubmit(q, 1, &(VkSubmitInfo){
			.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
			.waitSemaphoreCount = 1, .pWaitSemaphores = &draw,
			.pWaitDstStageMask = (VkPipelineStageFlags[]){
				VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
			},
			.commandBufferCount = 1, .pCommandBuffers = &render[i],
			.signalSemaphoreCount = 1, .pSignalSemaphores = &pres,
		}, fences[i]);
		if(r < 0) error("Submitting CommandBuffer!", r);

		// And queue up the presentation of our render
		r = vVvk_QueuePresentKHR(q, &(VkPresentInfoKHR){
			.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
			.waitSemaphoreCount = 1, .pWaitSemaphores = &pres,
			.swapchainCount = 1, .pSwapchains = &swap, .pImageIndices = &i,
		});
		if(r < 0) error("Presenting!", r);

		// Rotate the tris
		rbuff[1] = 3.14*(2*3+1.5) * tim/5;
		rbuff[2] = 3.14*(2*2+1)   * tim/5;
		rbuff[3] = 3.14*(2*1+.5)  * tim/5;
		fcnt++;
	}
	printf("FPS: %f   mSPF: %f\n", fcnt/tim, tim/fcnt*1000);

	// Wait for all our CommandBuffers to finish before the final cleanup
	r = vVvk_WaitForFences(dev, icnt, fences, VK_TRUE, UINT64_MAX);
	if(r < 0) error("Waiting for fences!", r);

	// Cleanup
	vVvk_DestroySemaphore(dev, draw, NULL);
	vVvk_DestroySemaphore(dev, pres, NULL);
	for(int i=0; i < icnt; i++) {
		vVvk_DestroyFence(dev, fences[i], NULL);
		vVvk_DestroyFramebuffer(dev, fbs[i], NULL);
		vVvk_DestroyImageView(dev, ivs[i], NULL);
	}
	for(size_t i = 0; i < pcnt; i++)
		vVvk_DestroyPipeline(dev, pipes[i], NULL);
	free(pipes);
	vVvk_DestroyPipelineLayout(dev, pl, NULL);
	vVvk_DestroyShaderModule(dev, shader.AD, NULL);
	vVvk_DestroyShaderModule(dev, shader.ad, NULL);
	vVvk_DestroyShaderModule(dev, shader.BC, NULL);
	vVvk_DestroyShaderModule(dev, shader.bc, NULL);
	vVvks_destroyBank(bank);
	vVvkp_destroy(g);
	vVvk_FreeCommandBuffers(dev, cpool, icnt, render);
	vVvk_DestroyCommandPool(dev, cpool, NULL);
	vVvkm_unmapBuffer(pool, rotbuff);
	vVvkm_destroy(pool);
	vVvk_DestroyBuffer(dev, rotbuff, NULL);
	vVvk_DestroyBuffer(dev, buff, NULL);
	vVvk_DestroySwapchainKHR(dev, swap, NULL);
	vVvk_DestroyDevice(dev, NULL);
	vVwi_destroyWindow(win);
	vVwi_disconnect(con);
	vVvk_DestroySurfaceKHR(inst, surf, NULL);
	vVvk_DestroyInstance(inst, NULL);
	vVvk_unload();

	return 0;
}
