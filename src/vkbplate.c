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

#include <vivacious/vkbplate.h>
#include "internal.h"
#include <stdlib.h>
#include <string.h>

_Vv_ENUM(RuleType) {
	RULE_VERSION,
	RULE_LAYER,
	RULE_INST_EXT,
};

_Vv_STRUCT(Rule) {
	int id;
	Rule* next;
	RuleType type;
	union {
		uint32_t version;	// RULE_VERSION
		const char* layer;	// RULE_LAYER
		const char* inst_ext;	// RULE_INST_EXT
	};
};

struct VvVkBp_Rules {
	Rule* headRule;	// This imp uses a linked-list approach for rules.
	Rule* tailRule;
	const char* appName;
	uint32_t appVer;

	const Vv_Vulkan* vkapi;
	const VvVk_Binding* vkb;
};

static VvVkBp_Rules* Create(const Vv_Vulkan* vkapi, const VvVk_Binding* vkb) {
	VvVkBp_Rules* r = malloc(sizeof(VvVkBp_Rules));
	r->headRule = NULL;
	r->tailRule = NULL;
	r->appName = "He didn't tell me :'(";
	r->appVer = VK_MAKE_VERSION(0,0,0);
	r->vkapi = vkapi;
	r->vkb = vkb;
	return r;
}

static void Destroy(VvVkBp_Rules* r) {
	Rule* rule = r->headRule;
	while(rule) {
		Rule* next = rule->next;
		free(rule);
		rule = next;
	}
	free(r);
}

static void Remove(VvVkBp_Rules* r, int id) {
	Rule* last = NULL;
	Rule* rl =  r->headRule;
	while(rl && rl->id < id) {
		last = rl;
		rl = rl->next;
	}
	if(!rl || rl->id > id) return;
	if(last) last->next = rl->next;
	else r->headRule = rl->next;
	free(rl);
}

// Internal function
static Rule* newRule(VvVkBp_Rules* r) {
	Rule* res = malloc(sizeof(Rule));
	res->next = NULL;
	if(r->tailRule) {
		res->id = r->tailRule->id + 1;
		r->tailRule->next = res;
	} else {
		res->id = 1;
		r->headRule = res;
	}
	r->tailRule = res;
	return res;
}

static int Version(VvVkBp_Rules* r, uint32_t ver) {
	Rule* rl = newRule(r);
	rl->type = RULE_VERSION;
	rl->version = ver;
	return rl->id;
}

static int Layer(VvVkBp_Rules* r, const char* lay) {
	Rule* rl = newRule(r);
	rl->type = RULE_LAYER;
	rl->layer = lay;
	return rl->id;
}

static int InstanceExtension(VvVkBp_Rules* r, const char* ext) {
	Rule* rl = newRule(r);
	rl->type = RULE_INST_EXT;
	rl->inst_ext = ext;
	return rl->id;
}

static void ApplicationInfo(VvVkBp_Rules* r, const char* n, uint32_t v) {
	r->appName = n;
	r->appVer = v;
}

static int ResolveInstance(VvVkBp_Rules* r, VkInstance* pi) {
	const VvVk_1_0* vk = r->vkapi->core->vk_1_0(r->vkb);

	uint32_t lpc;
	vk->EnumerateInstanceLayerProperties(&lpc, NULL);
	VkLayerProperties* lps = malloc(lpc*sizeof(VkLayerProperties));
	vk->EnumerateInstanceLayerProperties(&lpc, lps);

	uint32_t epc;
	vk->EnumerateInstanceExtensionProperties(NULL, &epc, NULL);
	VkExtensionProperties* eps = malloc(epc*sizeof(VkExtensionProperties));
	vk->EnumerateInstanceExtensionProperties(NULL, &epc, eps);

	int layc = 0;
	int extc = 0;

	int tmp;

	Rule* rl = r->headRule;
	while(rl) {
		switch(rl->type) {
		case RULE_LAYER:
			tmp = 0;
			for(int i=0; i<lpc; i++)
				if(!strcmp(lps[i].layerName, rl->layer)) {
					tmp = 1;
					break;
				}
			if(tmp == 0) {
				free(lps);
				free(eps);
				return rl->id;
			}
			layc++; break;
		case RULE_INST_EXT:
			tmp = 0;
			for(int i=0; i<epc; i++)
				if(!strcmp(eps[i].extensionName,rl->inst_ext)) {
					tmp = 1;
					break;
				}
			if(tmp == 0) {
				free(lps);
				free(eps);
				return rl->id;
			}
			extc++; break;
		default: break;
		};
		rl = rl->next;
	}

	free(lps);
	free(eps);

	uint32_t apiver = 0;
	const char** lays = malloc(layc*sizeof(char*));
	const char** exts = malloc(extc*sizeof(char*));
	layc = extc = 0;

	rl = r->headRule;
	while(rl) {
		switch(rl->type) {
		case RULE_VERSION:
			if(apiver < rl->version)
				apiver = rl->version;
			break;
		case RULE_LAYER:
			lays[layc] = rl->layer;
			layc++;
			break;
		case RULE_INST_EXT:
			exts[extc] = rl->inst_ext;
			extc++;
			break;
		};
		rl = rl->next;
	}

	VkApplicationInfo ai = {
		VK_STRUCTURE_TYPE_APPLICATION_INFO, NULL,
		r->appName, r->appVersion,
		"Vivacious", VK_MAKE_VERSION()
	};

	return -1;
}

VvAPI const Vv_VulkanBoilerplate vVvkbp_first = {
	Create, Destroy,
	Remove,
	Version, Layer, InstanceExtension,
	ApplicationInfo,
	ResolveInstance,
};

#endif // Vv_ENABLE_VULKAN
