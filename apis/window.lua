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

vk = require 'vulkan'
vki = require 'vkinitializer'

WindowManager = {doc = [[
	A connection to the system's window manager, which provides a place to render
	things onto the screen. In particular, creates Surfaces.
]]}

WindowManager.type.Events = flags{
	doc = "A selection of Events that the user can input to a Window",
	{'mouse_press', 'm'},
	{'mouse_release', 'M'},
	{'mouse_moved', 'X'},
	{'key_press', 'k'},
	{'key_release', 'K'},
}

WindowManager.Window = {doc = [[
	A Window managed by this WindowManager. Can recieve events, and contains a
	single Surface.
]]}

WindowManager.v0_1_1.newWindow = {
	doc = "Create a new window. May not be visible until `show` is called.",
	returns = {WindowManager.Window},
	{'extent', vk.Vk.Extent2D},
	{'allowedEvents', WindowManager.Events},
}

WindowManager.Window.v0_1_1.show = {
	doc = "Ensure this Window is actually rendering on the screen.",
}

WindowManager.Window.v0_1_1.setTitle = {
	doc = "Set the Window's title, which usually appears up top somewhere.",
	{'title', string},
}

WindowManager.Window.v0_1_1.setFullscreen = {
	doc = "Enable (or disable) a Window's fullscreen state.",
	{'enabled', boolean},
}

WindowManager.Window.v0_1_1.setSize = {
	doc = "Set the size (in pixels) of a Window.",
	{'extent', vk.Vk.Extent2D},
}

WindowManager.Window.v0_1_1.getSize = {
	doc = "Get the size of this Window (in pixels).",
	returns = {vk.Vk.Extent2D},
}

WindowManager.v0_1_1.getSize = {
	doc = "Get the size of the entire screen. Useful for real estate guesstimations.",
	returns = {vk.Vk.Extent2D},
}

WindowManager.Window.v0_1_1.createVkSurface = {
	doc = "Create a Surface that can access this Window, or fail trying.",
	returns = {vk.Instance.SurfaceKHR, vk.Vk.Result},
	{'instance', vk.Instance},
}

WindowManager.v0_1_2.getInstanceInfo = {
	doc = "Obtain the VkInstanceCreatorInfo that needs to be applied to use this Manager.",
	returns = {vki.VkInstanceCreator.Info},
}
