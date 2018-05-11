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

-- luacheck: globals array method callable
require 'core.common'
local vk = require 'vulkan'
local vki = {__index={}}

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
		{name='extensions', type=array.string, doc="Required Instance extensions."},
		{name='layers', type=array.string, doc="Required Instance layers."},
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
		method{'append', "Append the requirements specified in <info> to this Creator.",
			{'return', vk.Result},
			{'info', iInfo}
		},
		method{'create', "Attempt to create an Instance that satisfies all the requirements.",
			{'return', vk.Instance, canbenil=true},
			{'return', vk.Result}
		},
		method{'reset', "Resets all the requirements in this Creator."},
	},
}
table.insert(vki.__index, callable{'createVkInstanceCreator', version='0.1.0',
	{'return', vki.InstanceCreator, canbenil=true},
	{'return', 'string', canbenil=true},
	{'vulkan', vk.Vk}
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
		{name='tasks', type=array[dTask], canbenil=true,
			doc="Tasks that will be assigned Queues."},
		callable{'compare', "Defines a preference-order on PhysicalDevices.",
			{'return', 'boolean'},
			{'a', vk.PhysicalDevice},
			{'b', vk.PhysicalDevice},
			canbenil=true
		},
		callable{'valid', "Defines a validator on PhysicalDevices",
			{'return', 'boolean'},
			{'pd', vk.PhysicalDevice},
			canbenil=true
		},
		{name='extensions', type=array.string, canbenil=true,
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
		method{'append', "Append new requirements to the Creator.",
			{'return', vk.Result},
			{'info', dInfo}
		},
		method{'create', "Attempt to create a Device that satisfies the requirements.",
			{'return', vk.Device, canbenil=true},
			{'return', vk.PhysicalDevice, canbenil=true},
			{'return', vk.Result}
		},
		method{'reset', "Reset all the requirements appended to this Creator."},
	},
}
table.insert(vki.__index, callable{'createVkDeviceCreator', version='0.1.1',
	{'return', vki.DeviceCreator, canbenil=true},
	{'return', 'string', canbenil=true},
	{'instance', vk.Instance}
})

return vki
