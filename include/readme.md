## Terminology and Overall Structure

The vV API is broken up into many smaller pieces, which can (and often
do) build on each other. Each of these pieces is called simply an *API*,
which consists of the functions defined by the API (called *commands*)
along with the opaque and transparent types used by the commands.

The commands in an API are not part of the symbol table for a vV library.
Instead, each API defines one or more *implementations*, which are filled
const globals of the main API structure (rationale 4).

## Naming scheme

Every symbol in vV must begin with a prefix classifying it uniquely into
the specific API from which it comes. Every API should thus have a
shortened form of the name for the prefix. This is the *shorthand* name
for the API, and should have two forms. The first follows CamelCase rules,
and starts with a capital, we call this `<Sh>`. The second is all lowercase,
we call this `<sh>`. This is to prevent capitalization conflicts with the
vV (or Vv) part of the prefix.

Every type should have the prefix `Vv<Sh>_`, with the exception being
the API structure itself, which should have the form `Vv_<api>`. Every
implementation of the API should have the form `vV<sh>_<imp>` (rationale 3),
where `<imp>` is a unique identifier for the implemention, as seen below.

## Header Conventions

Every API should be defined in a single header in this directory or a
subdirectory, which is entirely under a proper define fence. The name of
the constant used should be `H_vivacious_<path>`, where `<path>` is the
header's filepath without extension from this directory with "_" as the
delimiter.

E.g. The header `foo/bar/test.h` would use `H_vivacious_foo_bar_test`.

## Guidelines for API structure.

Every API in vV has a single `Vv_<api>` structure type that acts as the
interface that applications use. This structure should only contain
function pointers (commands) and const pointers to other structures with
identical restrictions.

Any structures that are defined by an API should be typedef'd in such a
way as to allow the struct identifier to be dropped (rationale 1).
Any opaque types that are defined by an API should be handled similarly,
i.e. a handle type will be "created" by `typedef struct <name> <name>;`.

Sometimes APIs will have *integrations* with one another, which are
commands that operate on types another API has defined. A API which
requires types from a second API is said to *depend* on that API. If the
dependant requires transparent types, then the dependant's header should
additionally include the dependee's header. If the dependant only requires
opaque types, then the integrations should simply include the struct
identifier with the type in question.

Every integration needs to have a way to access the dependee API. This can
be done with a "setter" on an opaque type, or with a `const struct Vv_<api>*`
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

The header which defines an API should also define the globals that form the
vV implementations of the API. These statements will thus be of the form
`extern const Vv_<api> vV<sh>_<imp>;`.

## Maintenance

Sometimes the APIs require updating. Any new commands should be placed at
the end of the structure, allowing older compatible versions to still
access older commands. Any larger changes should be batched for the next
major version of vV, as dictated by Semver.

If updating an API makes it become dependant, or otherwise requires the
addition of a new include, it should be added. If the update removes a
dependancy, or the need for an include, it should not be removed
(rationale 2).

There might be cases where a new implementation for an API is added. As
required by Semver, these should incur minor version updates for vV. There
should be little reason to remove an implementation, but should the need
arise, the operation will require a major version update.

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

3. The reason to use the shorthand in the implementation name is to allow the
   implementation call to rest comfertably on the same line as the return
   variable. For instance, a line of code like
   ```C
   const Vv_MyCoolFish* mcfapi = vV_loadMyCoolFish_EvenCooler();
   ```
   is lengthy and redundant, compared to the very similar
   ```C
   const Vv_MyCoolFish* mcfapi = vVmcf_EvenCooler();
   ```
   which still provides all the information and uniqueness needed, without the
   extra bulk.

4. Earlier versions of this document defined implementations to be functions
   that return const pointers to filled API structures. This was changed to
   provide the same functionality, while removing a pointer dereference.
