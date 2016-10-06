## Guidelines for API creation and management.

Every API in vV has a single `vV<name>API` structure type that acts as 
the interface that applications use. Because all of the functions are 
accessed as pointers in the `vV*API` structure, there can be multiple 
and many implementations of the API, each with its benefits and 
downsides. From here on out, the `vV*API` structure will simply by 
called the API.

Every API should be defined in a single header in this directory, which 
has proper define fences to prevent unintended errors. The name of the 
constant used should be `H_vivacious_<name>`, and have a small integer 
value. This value should act like the major version in semver for the 
header, and checked by macro upon loading of the implementation.

Every function pointer in an API should have `const VvConfig` as the 
first argument to the function. The type is declared in core.h as 
`typedef void* VvConfig`.

Since `VvConfig` is an opaque handle, every API should have a 
member/function with the signature `void (*cleanup)(VvConfig)`. After 
calling this, the given `VvConfig` should be considered invalid, and can 
be removed.

When updating an API, new elements should be placed at the bottom of the 
structure, to allow minorly old versions of headers to work with new 
versions of vV. Removing elements of the structure is not possible 
without incrementing the header version, as instructed by semver.

An implementation is a function that returns a const pointer to a filled 
API, and is is named `_vVload<name>_<imp>`, where `<imp>` is an 
identifier to distinguish between implementations of the same API. The 
full signature of this for an API named `Cool` and an implementation 
identified as `Fast` would be
`const VvCoolAPI* _vVloadCool_Fast(int version, VvConfig*, ...)`.

The `...` in the implmentation signature should be replaced with none or 
multiple `const Vv*API *` arguments, which will fill the VvConfig opaque
handle with the dependancy APIs needed for this implementation.

Every implementation declared in a header should have a macro that 
should be used to call the function, which fills in the `version` 
argument of the call with the header version, `H_vivacious_*`. The macro 
should be called `vVload<name>_<imp>`.
