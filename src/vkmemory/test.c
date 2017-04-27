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

#ifdef Vv_ENABLE_VULKAN

#define Vv_CHOICE *V
#define Vv_IMP_vkm

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

	VkPhysicalDevice pdev;
	VkDevice dev;
};

static VvVkM_Pool* create(const Vv* V, VkPhysicalDevice pdev, VkDevice dev) {

	VvVkM_Pool* pool = malloc(sizeof(VvVkM_Pool));
	*pool = (VvVkM_Pool) {
		.cnt = 0, .recs = NULL,
		.pdev = pdev, .dev = dev,
	};
	return pool;
}

static void destroy(const Vv* V, VvVkM_Pool* pool) {
	for(int i=0; i < pool->cnt; i++) {
		if(pool->recs[i].mem)
			vVvk10_FreeMemory(pool->dev, pool->recs[i].mem, NULL);
	}
	free(pool->recs);
	free(pool);
}

static void registerGeneral(const Vv* V, VvVkM_Pool* pool, VkMemoryPropertyFlags ideal,
	VkMemoryPropertyFlags req, VkMemoryRequirements* mreq) {

	ideal |= req;
	pool->cnt++;
	pool->recs = realloc(pool->recs, sizeof(Resource)*pool->cnt);
	Resource* rec = &pool->recs[pool->cnt-1];
	*rec = (Resource){ .isAlloced = 0, };

	VkPhysicalDeviceMemoryProperties pdmp;
	vVvk10_GetPhysicalDeviceMemoryProperties(pool->pdev, &pdmp);

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

static void registerBuffer(const Vv* V, VvVkM_Pool* pool, VkBuffer b,
	VkMemoryPropertyFlags ideal, VkMemoryPropertyFlags req) {

	VkMemoryRequirements mreq;
	vVvk10_GetBufferMemoryRequirements(pool->dev, b, &mreq);
	registerGeneral(V, pool, ideal, req, &mreq);
	pool->recs[pool->cnt-1].isImage = 0;
	pool->recs[pool->cnt-1].buff = b;
}

static void registerImage(const Vv* V, VvVkM_Pool* pool, VkImage i,
	VkMemoryPropertyFlags ideal, VkMemoryPropertyFlags req) {

	VkMemoryRequirements mreq;
	vVvk10_GetImageMemoryRequirements(pool->dev, i, &mreq);
	registerGeneral(V, pool, ideal, req, &mreq);
	pool->recs[pool->cnt-1].isImage = 1;
	pool->recs[pool->cnt-1].img = i;
}

static VkResult bind(const Vv* V, VvVkM_Pool* pool) {
	for(int i=0; i < pool->cnt; i++) {
		if(pool->recs[i].isAlloced) continue;
		Resource* rec = &pool->recs[i];

		VkMemoryRequirements mreq;
		if(rec->isImage) {
			vVvk10_GetImageMemoryRequirements(pool->dev,
				rec->img, &mreq);
		} else {
			vVvk10_GetBufferMemoryRequirements(pool->dev,
				rec->buff, &mreq);
		}
		VkResult r = vVvk10_AllocateMemory(pool->dev,
			&(VkMemoryAllocateInfo){

			.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
			.allocationSize = mreq.size,
			.memoryTypeIndex = rec->mtype,
		}, NULL, &rec->mem);
		if(r < 0) return r;

		if(rec->isImage) {
			r = vVvk10_BindImageMemory(pool->dev, rec->img,
				rec->mem, 0);
			if(r < 0) return r;
		} else {
			r = vVvk10_BindBufferMemory(pool->dev, rec->buff,
				rec->mem, 0);
			if(r < 0) return r;
		}
		rec->isAlloced = 1;
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

static int findImage(VvVkM_Pool* pool, VkImage img) {
	for(int i=0; i < pool->cnt; i++) {
		Resource* rec = &pool->recs[i];
		if(rec->isImage && rec->img == img) {
			return i;
		}
	}
	return -1;
}

static VkResult mapBuffer(const Vv* V, VvVkM_Pool* pool, VkBuffer b, void** out) {
	Resource* rec = &pool->recs[findBuffer(pool, b)];
	return vVvk10_MapMemory(pool->dev, rec->mem,
		0, VK_WHOLE_SIZE, 0, out);
}

static VkResult mapImage(const Vv* V, VvVkM_Pool* pool, VkImage i, void** out) {
	Resource* rec = &pool->recs[findImage(pool, i)];
	return vVvk10_MapMemory(pool->dev, rec->mem,
		0, VK_WHOLE_SIZE, 0, out);
}

static void unmapBuffer(const Vv* V, VvVkM_Pool* pool, VkBuffer b) {
	Resource* rec = &pool->recs[findBuffer(pool, b)];
	vVvk10_UnmapMemory(pool->dev, rec->mem);
}

static void unmapImage(const Vv* V, VvVkM_Pool* pool, VkImage i) {
	Resource* rec = &pool->recs[findImage(pool, i)];
	vVvk10_UnmapMemory(pool->dev, rec->mem);
}

static VkMappedMemoryRange getRangeBuffer(const Vv* V, VvVkM_Pool* pool, VkBuffer b) {
	Resource* rec = &pool->recs[findBuffer(pool, b)];
	return (VkMappedMemoryRange){
		.sType=VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
		.memory=rec->mem,
		.offset=0,
		.size=VK_WHOLE_SIZE,
	};
}

static VkMappedMemoryRange getRangeImage(const Vv* V, VvVkM_Pool* pool, VkImage i) {
	Resource* rec = &pool->recs[findImage(pool, i)];
	return (VkMappedMemoryRange){
		.sType=VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
		.memory=rec->mem,
		.offset=0,
		.size=VK_WHOLE_SIZE,
	};
}

static void unbindBuffer(const Vv* V, VvVkM_Pool* pool, VkBuffer b) {}
static void unbindImage(const Vv* V, VvVkM_Pool* pool, VkImage i) {}

static void destroyGeneral(const Vv* V, VvVkM_Pool* pool, int ind) {
	if(pool->recs[ind].isAlloced)
		vVvk10_FreeMemory(pool->dev, pool->recs[ind].mem, NULL);
	for(int i=ind+1; i < pool->cnt; i++)
		pool->recs[i-1] = pool->recs[i];
	pool->cnt--;
	pool->recs = realloc(pool->recs, pool->cnt*sizeof(Resource));
}

static void destroyBuffer(const Vv* V, VvVkM_Pool* pool, VkBuffer b) {
	int ind = findBuffer(pool, b);
	vVvk10_DestroyBuffer(pool->dev, pool->recs[ind].buff, NULL);
	destroyGeneral(V, pool, ind);
}

static void destroyImage(const Vv* V, VvVkM_Pool* pool, VkImage i) {
	int ind = findImage(pool, i);
	vVvk10_DestroyImage(pool->dev, pool->recs[ind].img, NULL);
	destroyGeneral(V, pool, ind);
}

const Vv_VulkanMemoryManager libVv_vkm_test = {
	.create = create,
	.destroy = destroy,

	.registerBuffer=registerBuffer, .registerImage=registerImage,
	.bind=bind,
	.unbindBuffer=unbindBuffer, .unbindImage=unbindImage,
	.destroyBuffer=destroyBuffer, .destroyImage=destroyImage,

	.mapBuffer=mapBuffer, .mapImage=mapImage,
	.unmapBuffer=unmapBuffer, .unmapImage=unmapImage,
	.getRangeBuffer=getRangeBuffer, .getRangeImage=getRangeImage,
};

#endif // Vv_ENABLE_VULKAN
