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

#ifndef H_vivacious_vkbplate
#define H_vivacious_vkbplate

#include <vivacious/core.h>
#include <vivacious/vulkan.h>
#include <vivacious/window.h>

// The Rules holds all the requests and requirements on the initial Vulkan
// system. Currently that includes from the Instance to the Device and Queues.
_Vv_TYPEDEF(VvVkBp_Rules);

// About rule ids (rids): valid rids are positive and non-zero.

// Commands in this API which add rules should return an int, which is either
// the rid of the new rule, or 0 if the rule would never be satified (if the
// implementation supports such early checking).

_Vv_STRUCT(Vv_VulkanBoilerplate) {
	// Create a Rules, which have a connection to Vk constantly.
	VvVkBp_Rules* (*Create)(const Vv_Vulkan*, const VvVk_Binding*);

	// Destroy a Rules. Does not clean up the created Vulkan types.
	void (*Destroy)(VvVkBp_Rules*);

	// Remove a rule from a Rules, to save repetition.
	void (*Remove)(VvVkBp_Rules*, int rid);

	// Add a rule limiting the version of Vulkan required.
	int (*Version)(VvVkBp_Rules*, uint32_t version);

	// Add a rule which requests a layer for the instance.
	int (*Layer)(VvVkBp_Rules*, const char* layer);

	// Add an extension for the instance.
	int (*InstanceExtension)(VvVkBp_Rules*, const char* ext);

	// Not really a rule, but set the applicationName and Version in AppInfo
	void (*ApplicationInfo)(VvVkBp_Rules*, const char* name, uint32_t ver);

	// Resolve the Instance from the rules, if possible.
	// Returns 0 on success, or a valid rid on error, or <0 on fatal error.
	int (*ResolveInstance)(VvVkBp_Rules*, VkInstance*);
};

// This implementation just selects the first one that works. Very crude.
extern const Vv_VulkanBoilerplate vVvkbp_first;

#endif // H_vivacious_vkbplate
