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

// The Rules collects rules, and is capible of resolving them as well.
_Vv_TYPEDEF(VvVkBp_Rules);

// About rule ids (rids): valid rids are positive and non-zero.

// Commands in this API which add rules return an int, which is either the rid
// of the new rule, or 0 if the rule would conflict with another rule. If an
// equivalent rule already exists, then the rid of the other rule can be used.
// Those commands also take a float argument, which is the priority of the rule,
// which if positive is used to determine between choices in an implementation
// -specific manner, or if 0 indicates absolute requirement.

_Vv_STRUCT(Vv_VulkanBoilerplate) {
	// The life(time) of a Rules.
	VvVkBp_Rules* (*create)(const Vv_Vulkan*, const VvVk_Binding*);
	void (*destroy)(VvVkBp_Rules*);

	// Attempt to build all the Vulkan handles requested.
	// Returns 0 on success.
	int (*resolve)(VvVkBp_Rules*);

	// Checks if a rule was satified by the results from .resolve.
	// Should return 0 if resolve has not been called yet.
	// Should also accept valid nonexistant rules, and return a true value.
	int (*satisfied)(const VvVkBp_Rules*, int rid);

	// Remove a rule from a Rules. Should allow valid but nonexistant rids.
	void (*remove)(VvVkBp_Rules*, int rid);

	// Add a rule limiting the min version of Vulkan needed.
	int (*addVersion)(VvVkBp_Rules*, float, uint32_t version);

	// Add a rule which adds a layer to the Instance (and Device).
	int (*addLayer)(VvVkBp_Rules*, float, const char* layer);

	// Add a rule which adds an extension for the Instance.
	int (*addInstExt)(VvVkBp_Rules*, float, const char* ext);

	// Add a rule which sets the AppInfo for Instance creation.
	int (*addAppInfo)(VvVkBp_Rules*, float,
		const char* name, uint32_t ver);

	// Set the place to place the Instance after creation.
	void (*setInstance)(VvVkBp_Rules*, VkInstance*);
};

// This implementation chooses between options based on the sum of the pris
// of the rules that would be satisified.
extern const Vv_VulkanBoilerplate vVvkbp_sum;

#endif // H_vivacious_vkbplate
