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

#ifdef Vv_ENABLE_VULKAN

#include <vivacious/vkmemory.h>
#include "internal.h"
#include <stdlib.h>
#include <stdio.h>

_Vv_STRUCT(Resource) {
	int isImage;
	union {
		VkBuffer buff;
		VkImage img;
	};
	int isAlloced;
	union {
		VkDeviceMemory mem;
		uint32_t mtype;
	};
};

struct VvVkM_Pool {
	int cnt;
	Resource* recs;

	const VvVk_1_0* vk;
	VkPhysicalDevice pdev;
	VkDevice dev;
};

static VvVkM_Pool* create(const VvVk_Binding* vkb, VkPhysicalDevice pdev,
	VkDevice dev) {

	VvVkM_Pool* pool = malloc(sizeof(VvVkM_Pool));
	*pool = (VvVkM_Pool) {
		.cnt = 0, .recs = NULL,
		.vk = vkb->core->vk_1_0,
		.pdev = pdev, .dev = dev,
	};
	return pool;
}

static void destroy(VvVkM_Pool* pool) {
	for(int i=0; i < pool->cnt; i++) {
		if(pool->recs[i].mem)
			pool->vk->FreeMemory(pool->dev,
				pool->recs[i].mem, NULL);
	}
	free(pool->recs);
	free(pool);
}

static void registerGeneral(VvVkM_Pool* pool, VkMemoryPropertyFlags ideal,
	VkMemoryPropertyFlags req, VkMemoryRequirements* mreq) {

	ideal |= req;
	pool->cnt++;
	pool->recs = realloc(pool->recs, sizeof(Resource)*pool->cnt);
	Resource* rec = &pool->recs[pool->cnt-1];
	*rec = (Resource){ .isAlloced = 0, };

	VkPhysicalDeviceMemoryProperties pdmp;
	pool->vk->GetPhysicalDeviceMemoryProperties(pool->pdev, &pdmp);

	for(int i=0; i<pdmp.memoryTypeCount; i++) {
		if((mreq->memoryTypeBits & (1<<i))
			&& ((pdmp.memoryTypes[i].propertyFlags&ideal)==ideal)) {

			rec->mtype = i;
			return;
		}
	}
	for(int i=0; i<pdmp.memoryTypeCount; i++) {
		if((mreq->memoryTypeBits & (1<<i))
			&& ((pdmp.memoryTypes[i].propertyFlags & req) == req)) {

			rec->mtype = i;
			return;
		}
	}
	rec->mtype = -1;
}

static void registerBuffer(VvVkM_Pool* pool, VkBuffer b,
	VkMemoryPropertyFlags ideal, VkMemoryPropertyFlags req) {

	VkMemoryRequirements mreq;
	pool->vk->GetBufferMemoryRequirements(pool->dev, b, &mreq);
	registerGeneral(pool, ideal, req, &mreq);
	pool->recs[pool->cnt-1].isImage = 0;
	pool->recs[pool->cnt-1].buff = b;
}

static VkResult bind(VvVkM_Pool* pool) {
	for(int i=0; i < pool->cnt; i++) {
		if(pool->recs[i].isAlloced) continue;
		Resource* rec = &pool->recs[i];
		VkMemoryRequirements mreq;
		if(rec->isImage) {
		} else {
			pool->vk->GetBufferMemoryRequirements(pool->dev,
				rec->buff, &mreq);
			VkResult r = pool->vk->AllocateMemory(pool->dev,
				&(VkMemoryAllocateInfo){

				.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
				.allocationSize = mreq.size,
				.memoryTypeIndex = rec->mtype,
			}, NULL, &rec->mem);
			if(r < 0) return r;
			r = pool->vk->BindBufferMemory(pool->dev, rec->buff,
				rec->mem, 0);
			if(r < 0) return r;
			rec->isAlloced = 1;
		}
	}
	return VK_SUCCESS;
}

static int findBuffer(VvVkM_Pool* pool, VkBuffer b) {
	for(int i=0; i < pool->cnt; i++) {
		Resource* rec = &pool->recs[i];
		if(!rec->isImage && rec->buff == b) {
			return i;
		}
	}
	return -1;
}

static VkResult mapBuffer(VvVkM_Pool* pool, VkBuffer b, void** out) {
	Resource* rec = &pool->recs[findBuffer(pool, b)];
	return pool->vk->MapMemory(pool->dev, rec->mem,
		0, VK_WHOLE_SIZE, 0, out);
}

static void unmapBuffer(VvVkM_Pool* pool, VkBuffer b) {
	Resource* rec = &pool->recs[findBuffer(pool, b)];
	pool->vk->UnmapMemory(pool->dev, rec->mem);
}

static VkMappedMemoryRange getRangeBuffer(VvVkM_Pool* pool, VkBuffer b) {
	Resource* rec = &pool->recs[findBuffer(pool, b)];
	return (VkMappedMemoryRange){
		.sType=VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
		.memory=rec->mem,
		.offset=0,
		.size=VK_WHOLE_SIZE,
	};
}

static void unbindBuffer(VvVkM_Pool* pool, VkBuffer b) {}

static void destroyBuffer(VvVkM_Pool* pool, VkBuffer b) {
	int ind = findBuffer(pool, b);
	Resource* rec = &pool->recs[ind];
	if(rec->isAlloced) pool->vk->FreeMemory(pool->dev, rec->mem, NULL);
	pool->vk->DestroyBuffer(pool->dev, rec->buff, NULL);

	for(int i=ind+1; i < pool->cnt; i++)
		pool->recs[i-1] = pool->recs[i];
	pool->cnt--;
	pool->recs = realloc(pool->recs, pool->cnt*sizeof(Resource));
}

VvAPI const Vv_VulkanMemoryManager vVvkm_test = {
	.create = create,
	.destroy = destroy,

	.registerBuffer=registerBuffer,
	.bind=bind,
	.unbindBuffer=unbindBuffer,
	.destroyBuffer=destroyBuffer,

	.mapBuffer=mapBuffer,
	.unmapBuffer=unmapBuffer,
	.getRangeBuffer=getRangeBuffer,
};

#endif // Vv_ENABLE_VULKAN
