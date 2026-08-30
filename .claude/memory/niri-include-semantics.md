# niri `include` Semantics

niri's config supports `include "path"` and a node-property form,
`include optional=true "path"`. A parser that matches only `include\s+"` will
silently skip every optional include and everything declared inside it. This
repo hit exactly that: three `optional=true` lines in the maintainer's own
config were never scanned, invisible only because none of them declared
workspaces.

**`optional=true` excuses a file that is absent, and nothing more.** A path
that exists but cannot be read is still a hard config error. Verified against
niri directly: `mkdir`ing a directory at an optional include path makes niri
refuse the whole config with `failed to read included config ...: Is a
directory (os error 21)`, while a simply-missing one logs
`optional include not found` and loads fine.

That distinction maps onto `FileViewError`: suppress `FileNotFound` for
optional paths, report `PermissionDenied` and `NotAFile`.

## Testing the Failure Paths Safely

`mkdir`ing a directory at an *optional* include path is the safe probe — it
exercises the not-excused branch, niri keeps its last good config, and `rmdir`
reverts it with no edit to `config.kdl`.

Do **not** test by adding a missing *non-optional* include. niri rejects the
entire config and falls back to its built-in default, which spawns waybar and
never starts DMS, so DMS never regenerates the `dms/*.kdl` fragments the config
includes. `~/.config/niri/config.kdl` carries a comment documenting this as a
self-perpetuating break.

See [[fileview-reentrancy]] for the other trap in this scan loop.
