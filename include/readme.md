## Terminology and Overall Structure

The vV API is broken up into many smaller pieces, which can (and often
do) build on each other. Each of these pieces is called simply an *API*,
which consists of the functions defined by the API (called *commands*)
along with the opaque and *transparent* types used by the commands.

No API will define any symbols in the symbol table for vV. Instead, each
API can have multiple *implementations*, which are functions that allow
applications access to the commands defined by the API. Implementations
may depend on other APIs, which are in turn obtained by calling
implementations, and so on and so forth.

This API-implementation distinction allows the application to choose how
what would be considered internal pieces of vV work, to the point of
allowing external re-implementation of core pieces. This is intended to
allow for another level of customization to the engine.

## Header Conventions

Every API should be defined in a single header in this directory or a
subdirectory, which is entirely under a proper define fence. The name of
the constant used should be `H_vivacious_<path>`, where `<path>` is the
header's filepath without extension from this directory with "_" as the
delimiter.

E.g. The header `foo/bar/test.h` would use `H_vivacious_foo_bar_test`.

## Guidelines for API structure.

Every API in vV has a single `Vv<api>` structure type that acts as the
interface that applications use. This structure should only contain
function pointers (commands) and const pointers to other structures with
identical restrictions.

Any structures that are defined by an API should be typedef'd in such a
way as to allow the struct identifier to be dropped (rationale 1).
Any opaque types that are defined by an API should be handled similarly,
i.e. a handle type will be "created" by `typedef struct <name> <name>;`.

Sometimes APIs will have *integrations* with one another, which are
commands which operate on types the API has not defined. A API which
requires types from a second API is said to *depend* on that API. If the
dependant requires transparent types, then the dependant's header should
additionally include the dependee's header. If the dependant only requires
opaque types, then the integrations should simply include the struct
identifier with the type in question.

Every integration needs to have a way to access the dependee API. This can
be done with a "setter" on an opaque type, or with a `struct Vv<api>*`
parameter on the command itself.

Examples:
1. An API has a command `FishSauce(VvFish, struct VvSauce*)`, where `VvSauce`
   is a handle defined by another API.

## Exceptions (mostly caused by external library support)

Some APIs in vV include outside headers, and supply the library's
functions as commands in the API. This creates types that are not
defined with vV protocols, which can create issues particularly with
integrations. The rule for dealing with most such problems is this:
**The type in question should be referenced as the most compatible base type.**
For instance, this means that the "handle" types defined by Vulkan would
be referenced as `void*`, and in OpenGL would be `uint32_t` or `short`.
Most external types used in integrations may be opaque by nature, which
would mean heavy use of `void*`.

## Implementations

The header defining an API also should define prototypes for the
implementations of the API. These functions should be named following the
convention `vVload<api>_<imp>`, where `<imp>` is a unique identifier for
the implementation. The arguments to this function are dependant on the
implementation, but the function should return a `const Vv<api>*`.

## Maintenance

Sometimes the APIs require updating. Any new commands should be placed at
the end of the structure, allowing older compatible versions to still
access older commands. Any larger changes should be batched for the next
major version of vV, as dictated by Semver.

If updating an API makes it become dependant, or otherwise requires the
addition of a new include, it should be added. If the update removes a
dependancy, or the need for an include, it should not be removed
(rationale 2).

Updates to an implementation can be done in two ways. One way is a new
implementation is added, and the older one can be depreciated, which
requires a minor version increment for vV. The other way is to change
the signature of the implementation, which requires a major version
increment. Which is chosen will most likely be based on other developments.

### Rationale

1. There have been many arguments in the past about the presence or absence
   of the struct identifier. Personally, I would perfer to leave it off.
   To make vV compatible, the typedef'd name is the same as the struct name.
   This way, either way will work equally well on the application's end.

2. It is not uncommon for a piece of application code to include as few
   headers as possible. Removing includes creates strange compile-time errors
   for applications not anticipating these issues. To aid in ease of use on
   that front, includes are not allowed to be removed. Thus, choose wisely
   when adding integrations to an API.
