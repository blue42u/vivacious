# Vivacious

A full-featured game engine, with manners. Use the engine and platform APIs
in tandem, without entering support hell. Its fast, and natively supports both
Lua and Vulkan.

## Compiling

```
$ cmake path/to/vivacious
$ make
```

Many options are available, etc.

## Usage (from Lua)

```lua
local vV = require 'libvivacious'
local wind = vV.createWindow('My Cool Window')
... etc. ...
```

See the examples and documentation for more information.

## License

Apache Public License v2.0 © Jonathon Anderson
