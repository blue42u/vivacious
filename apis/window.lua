--[========================================================================[
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
--]========================================================================]

-- luacheck: globals array method callable versioned
require 'core.common'
local vk = require 'vulkan'
local vki = require 'vkinitializer'
local wi = {__directives={'include <vivacious/vulkan.h>', 'include <vivacious/vkinitializer.h>'}}

--[[ Removed until headerc is upgraded to support this
local emask = {__name = 'EventFlags', __enum = {
	{name='mouse_press', flag='m'},
	{name='mouse_release', flag='M'},
	{name='mouse_moved', flag='X'},
	{name='key_press', flag='k'},
	{name='key_release', flag='K'},
}, __mask=true}
]]

wi.Window = {__name = 'Window',
	__doc = [[
		A Window managed by this WindowManager. Can recieve events, and contains a
		single Surface which can be used to render to the screen.
	]],
	__index = versioned{
		'0.1.0',
		{name='manager', type=wi.WindowManager, doc="The presiding window manager."},
		{name='instance', type=vk.Instance, doc="The instance used to make this window."},
		method{'destroy', "Destroy this window"},
		'0.1.1',
		method{'show', "Ensure this window is actually rendering on the screen."},
		method{'setTitle', "Set the window's title, which usually appears up top somewhere.",
			{'title', 'string'}
		},
		method{'setFullscreen', "Enable (or disable) a Window's fullscreen state.",
			{'enabled', 'boolean'}
		},
		method{'setSize', "Set the size (in pixels) of a Window.",
			{'extent', vk.Extent2D}
		},
		method{'getSize', "Get the size of this window (in pixels).",
			{'extent', vk.Extent2D, ret=true}
		},
		{name='surface', type=vk.SurfaceKHR, doc="The Vulkan handle for this window."},
	},
}

wi.WindowManager = {__name = 'WindowManager',
	__doc = [[
		A connection to the system's window manager, which provides a place to
		comfortably render things onto the screen. In particular, creates Surfaces.
	]],
	__index = versioned{
		'0.1.0',
		method{'destroy', "Destroy this window"},
		'0.1.1',
		method{'getSize', "Get the size of the entire screen. Useful for real estate guesstimations.",
			{'extent', vk.Extent2D, ret=true}
		},
		method{'newWindow', "Create a new window, and return it.",
			{'instance', vk.Instance, doc="The Vulkan Instance that will contain the Surface."},
			{'extent', vk.Extent2D},
			{'allowedEvents', 'string'},
			{'window', wi.Window, ret=true},
			{'result', vk.Result, ret=true}
		},
		'0.1.2',
		{name='instinfo', type=vki.InstanceCreator.Info,
			doc="Required settings for Instances in order to use this WindowManager."}
	},
}

wi.Window.__index[1].type = wi.WindowManager	-- Post-link

wi.__index = versioned{
	'0.1.0',
	callable{'createWindowManager', "Create a default WindowManager",
		{'wm', wi.WindowManager, canbenil=true, ret=true},
		{'error', 'string', canbenil=true, ret=true}
	},
}

return wi
