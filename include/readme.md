## Overview

The Vivacious API, due to its layered nature, is a collection of smaller
specifications, each of which has a particular purpose. These smaller pieces
can and do depend on each other, but the possible dependencies are limited
to prevent cyclic dependencies. Each of these smaller pieces is called an
*API*, and encapsulates the functions that the API provides.

These APIs contain no actual code, they are merely specifications. Thus it is
up to the implementing library to provide *implementations*, filled versions of
the API structure. This allows for the application to decide at runtime which
implementation it would wish to use, as well as create and use its own.

It should be noted that the Vivacious API is implemented by *libvivacious*,
which we will use to term the library itself.

## API Names

Every API has a number of names used to refer to it, these are:
- Full Name, a Camel Case descriptive name for the API. Ex: GiantRobotManager
- Shorthand, a short sequence of lowercase characters (usually an acronym)
  which also uniquely identify the API. Ex: grobm
- Capital Shorthand, a version of the Shorthand preserving case. Ex: GRobM
- Header, the name used for the header's filename. Ex: grobotman.h
These names are used for the C naming scheme, although the only one to remember
to use the API is the Capital Shorthand (and the Shorthand). For the purposes
of this document, the Capital Shorthand is referenced by `<Sh>`, Shorthand by
`<sh>`, and Full Name by `<API>`.

## C Naming Scheme

Every symbol defined by vV headers includes a prefix to uniquely identify it
both as a part of Vivacious and as part of a specific API. This prefix takes
the form `vV<sh>_`, if the symbol is part of an API, and `vV_` if not. Private
symbols (usually macros) are prefixed with `_vV_`. Types use capitalization, so
the prefixes become `Vv<Sh>_`, `Vv_` and `_Vv_` respectively.

A small exception is that the API structure itself is not prefixed as part of
the API, which means that the name of the structure must be `vV_<API>`. This
may be changed in the future. Sooner rather than later.

There is one header file that is not part of the Vivacious API, libvivacious.h,
which provides access to the implementations available in libvivacious. These
implementations are available as `*libVv_<sh>.<implementation>`.

The C headers also define a collection of macros (and a type) referred to as the
"helper macros". The type consists of pointers to each API structure, called
(since its not part of any API) `Vv`. This structure allows APIs to depend on
one another, and a const pointer to `Vv` should be the first argument to any
API function. The macros are wrappers of an API's functions, and take the form
```
#define vV<sh>_<func>(...) (Vv_CHOICE).<sh>.<func>(&(Vv_CHOICE), ...)
```
where `Vv_CHOICE` is an application-defined macro which, when expanded, becomes
a reference to the `Vv` structure to use.

The helper macros be further limited by defining `Vv_IMP_<sh>`, which disables
the definition of helper macros for APIs which cannot be depended on by the API.
This is intended to aid in the creation of implementations, since the code can
use the helper macros and ensure valid inter-API dependency.

## Overall Guidelines

Each Vivacious API should be entirely contained in a single header file, with a
name based on the Full Name of the API. Any other headers that need to be
included may also be included by the API's header.

Every API should define a single `Vv_<API>` structure, as described earlier.

The first argument to any API's functions should be a `const Vv*`, to allow
access to other APIs.

All types defined by an API should be able to be used both with and without
the `struct` identifier (rationale 1).

If a function uses another API's type, then it should use the `struct`
identifier (if its an opaque handle and the other API has not been included)
to prevent warnings. This applies even if the other API is an external library.

Finally, the standard way to obtain implementations is to use the result of
the function `vV<sh>(const Vv*)`. In addition, the macro `vV()` from
vivacious.h returns a `Vv` structure filled in this way.

## Changing an API

When changing an existing API, any new commands should be placed at
the end of the structure, allowing older compatible versions to still
access older commands. Any larger changes should be batched for the next
major version of vV, as dictated by Semver.

If updating an API makes it become dependant, or otherwise requires the
addition of a new include, it should be added. If the update removes a
dependency, or the need for an include, it should not be removed (rationale 2).

### Rationale

1. There have been many arguments in the past about the presence or absence
   of the struct identifier. Personally, I would prefer to leave it off.
   To make vV compatible, the typedef'd name is the same as the struct name.
   This way, either way will work equally well on the application's end.

2. It is not uncommon for a piece of application code to include as few
   headers as possible. Removing includes creates strange compile-time errors
   for applications not anticipating these issues. To aid in ease of use on
   that front, includes are not allowed to be removed. Thus, choose wisely
   when adding integrations to an API.

### API map
Put here because it doesn't really fit anywhere else yet.
        API map, with layer groupings:
        [Layer contents](Layer shorthand)

                         [Vk]
                   _______|________
                  |                |
        [VkB,VkM,VkP](VkCore)     [Wi]
