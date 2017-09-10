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

local std = require 'standard'
local wi = {api=std.precompound{
	shortname = 'Wi',
	longname = 'Window System',
	doc = "A common interface to the OS's windowing system.",
}}

wi.EventMask = std.bitmask{
	doc="A bitmask for event types",
	v0_1_1 = {
		'MOUSE_PRESS', 'MOUSE_RELEASE', 'MOUSE_MOVED',
		'KEY_PRESS', 'KEY_RELEASE',
	},
}

wi.Connection = std.handle{doc='A connection to the window manager'}

wi.api.v0_1_1.connect = std.func{
	doc = "Connect to the system's window manager",
	returns = wi.Connection,
}

wi.api.v0_1_1.disconnect = std.method{
	doc = "Disconnect from the window manager",
	wi.Connection,
}

wi.Window = std.handle{doc='A single window on the screen... maybe.'}

wi.api.v0_1_1.createWindow = std.method{
	doc = "Create a new window for the screen, may not be visible.",
	returns = wi.Window,
	wi.Connection,
	{std.integer, 'width'}, {std.integer, 'height'},
	{wi.EventMask, 'events'},
}

wi.api.v0_1_1.destroyWindow = std.method{
	doc = "Destroy a window, removing it from the screen",
	wi.Window
}

wi.api.v0_1_1.showWindow = std.method{
	doc = "Make a window visible on the screen, if it wasn't visible already",
	wi.Window,
}

wi.api.v0_1_1.setTitle = std.method{
	doc = "Set a window's reported title for the window manager",
	wi.Window,
	{std.string, 'title'},
}

wi.api.v0_1_1.setFullscreen = std.method{
	doc = "Enable (or disable) a window's fullscreen properties",
	wi.Window, {std.boolean, 'enabled'},
}

wi.api.v0_1_1.setWindowSize = std.method{
	doc = "Set the pixel size of a window",
	wi.Window, std.array{std.integer, size=2},
}

wi.api.v0_1_1.getWindowSize = std.method{
	doc = "Obtain the current size of a window",
	returns = std.array{std.integer, size=2},
	wi.Window,
}

wi.api.v0_1_1.getScreenSize = std.method{
	doc = "Obtain the current size of the screen",
	returns = std.array{std.integer, size=2},
	wi.Connection,
}

wi.api.v0_1_1.createVkSurface = std.method{
	doc = "Create a VkSurface based on a window. Returns a VkResult.",
	returns = std.integer,
	wi.Window,
	{std.udata, 'inst'},
	{std.udata, 'pSurf'},
}

wi.api = std.compound(wi.api)
return wi
