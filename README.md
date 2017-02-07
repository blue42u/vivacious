# Vivacious

Vivacious (or vV for short) is an extensible layered graphics engine, built
from the ground up to use Vulkan. Choose different implementations at runtime,
for a case-specific performace boost.
Or let the engine choose for you. Your choice.

## Compiling

TL;DR: The usual `cmake` and `make` build. Outputs are in `build/libs`.

```
$ cd path/to/build/dir
$ cmake path/to/vivacious
$ make
```

By default, all supporting libraries are enabled. To disable a library, or
set a specific include path, change the following CMake settings:
- `<LIBRARY>_ENABLE`: Boolean, default ON.
- `<LIBRARY>_INCLUDE_DIR`: Path to the include directory for the library.

The libraries for which support can be enabled are as follows:
- `VULKAN`: Available from the Vulkan SDK.
- `LUA`: Available from lua.org or `liblua5.3-dev` on some Linux distros.
- `X`: Includes XCB, available from `libxcb1-dev` on some Linux distros.

## Small example

Currently, the vV API is still really big. For now, see the contents of the
`examples/` directory.

## License

Apache Public License v2.0 © Jonathon Anderson
