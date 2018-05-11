--[========================================================================[
   Copyright 2016-2018 Jonathon Anderson

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
--]========================================================================]

local vk = require 'vulkan'
local vki = {__index={}}

local arr = setmetatable({}, {
	__call = function(t,k) return t[k] end,
	__index = function(t,k)
		t[k] = {__index={{name='__sequence', type=k}}}
		return t[k]
	end,
})

local iInfo = {__name = 'VkInstanceInfo',
	__doc = [[
		A set of restrictions that can be appended to an InstanceCreator.
	]],
	__index = {
		'0.1.1',
		{name='name', type='string',
			doc="Name of the application, overwrites any previous value."},
		{name='version', type=vk.version,
			doc="Version of the application, overwrites any previous value."},
		{name='extensions', type=arr'string', doc="Required Instance extensions."},
		{name='layers', type=arr'string', doc="Required Instance layers."},
		{name='vkversion', type=vk.version, doc="Compatible version of Vulkan."},
	},
}

vki.InstanceCreator = {__name = 'VkInstanceCreator',
	Info = iInfo,
	__doc = [[
		Collects requirements on a future created VkInstance, and afterward attempt
		to create an Instance that satisfies all these requirements.
	]],
	__index = {
		'0.2.0',
		{name='append', doc="Append the requirements specified in <info> to this Creator.",
			type={__call={method=true,
				{name='return', type=vk.Result},
				{name='info', type=iInfo}
			}},
		},
		{name='create', doc="Attempt to create an Instance that satisfies all the requirements.",
			type={__call={method=true,
				{name='return', type=vk.Instance, canbenil=true},
				{name='return', type=vk.Result}
			}},
		},
		{name='reset', type={__call={method=true}},
			doc="Resets all the requirements in this Creator."},
	},
}
table.insert(vki.__index, {name='createVkInstanceCreator', version='0.1.0',
	type={__call={method=true,
		{name='return', type=vki.InstanceCreator, canbenil=true},
		{name='return', type='string', canbenil=true},
		{name='vulkan', type=vk.Vk}
	}},
})

local dTask = {__name = 'VkDeviceTask',
	__doc = [[
		The specification of a task, which will be assigned a Queue on Device creation.
	]],
	__index = {
		'0.1.1',
		{name='family', type='index', ifnil=0,
			doc="Tasks with the same <family> will share Queue families."},
		{name='index', type='index', ifnil=0, readonly=true,
			doc="Index of the Queue assigned to this task."},
		{name='flags', type=vk.QueueFlags, ifnil='',
			doc="Required flags for the assigned Queue."},
		{name='priority', type='number', ifnil=0.5,
			doc="Minimal priority of the Queue."},
		'0.1.2',
		{name='presentable', type='boolean', ifnil=false,
			doc="Whether this Queue must be able to present."},
	},
}

local dInfo = {__name = 'VkDeviceInfo',
	__index = {
		'0.1.1',
		{name='tasks', type=arr(dTask), canbenil=true,
			doc="Tasks that will be assigned Queues."},
		{name='compare', type={__call={
			{name='return', type='boolean'},
			{name='a', type=vk.PhysicalDevice},
			{name='b', type=vk.PhysicalDevice}}
		}, canbenil=true, doc="Defines a preference-order on PhysicalDevices."},
		{name='valid', type={__call={
			{name='return', type='boolean'},
			{name='pd', type=vk.PhysicalDevice}}
		}, canbenil=true, doc="Defines a validator on PhysicalDevices"},
		{name='extensions', type=arr'string', canbenil=true,
			doc="Required Device-level extensions"},
		'0.1.2',
		{name='surface', type=vk.SurfaceKHR, canbenil=true,
			doc="Surface that Tasks may require presentation capabilites for"},
		{name='features', type='nil', canbenil=true,
			doc="Features that must be enabled"},
	},
}

vki.DeviceCreator = {__name = 'VkDeviceCreator',
	Task = dTask, Info = dInfo,
	__doc = [[
		Collects requirements for the Device and PhysicalDevice, and will attempt to
		find and create ones that satisfy the requirements.
	]],
	__index = {
		'0.2.0',
		{name='append', doc="Append new requirements to the Creator.",
			type={__call={method=true,
				{name='return', type=vk.Result},
				{name='info', type=dInfo}
			}},
		},
		{name='create', doc="Attempt to create a Device that satisfies the requirements.",
			type={__call={method=true,
				{name='return', type=vk.Device, canbenil=true},
				{name='return', type=vk.PhysicalDevice, canbenil=true},
				{name='return', type=vk.Result}
			}},
		},
		{name='reset', type={__call={method=true}},
			doc="Reset all the requirements appended to this Creator."},
	},
}
table.insert(vki.__index, {name='createVkDeviceCreator', version='0.1.1',
	type={__call={method=true,
		{name='return', type=vki.InstanceCreator, canbenil=true},
		{name='return', type='string', canbenil=true},
		{name='vulkan', type=vk.Instance}
	}},
})

return vki
