# Project Memory

Shared, committed knowledge for this repo. One line per memory.

- [FileView re-entrancy](fileview-reentrancy.md) — reassigning `FileView.path` inside its own `onLoaded` silently drops the read; defer with `Qt.callLater`.
- [niri include semantics](niri-include-semantics.md) — `optional=true` excuses a missing file and nothing else; how to probe the failure paths without breaking the compositor.
- [What DMS gives a plugin popout](dms-plugin-popout-behavior.md) — Escape and CLI toggling come free, the popout seizes the keyboard while open, and `widget status` is broken upstream.
- [Installed DMS lags upstream](dms-upgrade-path.md) — DMS ships as a distro package, so check the running version against the release tag before writing any upstream bug report.
- [`font.weight` needs the wght axis](dms-font-weight-needs-variable-axis.md) — Inter is a variable font with one registered instance, so asking for bold silently renders Regular; set `font.variableAxes` too.
- [Registry submission](dms-registry-submission.md) — check id/name uniqueness first, push before opening the PR, and expect `action_required` on a first contribution.
- [`active_window_id` is frozen at startup](dms-niriservice-stale-active-window-id.md) — NiriService's focus handlers compare a string key to a numeric id, so only `is_focused` tracks focus live; never let the two compete.
