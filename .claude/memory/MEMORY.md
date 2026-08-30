# Project Memory

Shared, committed knowledge for this repo. One line per memory.

- [FileView re-entrancy](fileview-reentrancy.md) — reassigning `FileView.path` inside its own `onLoaded` silently drops the read; defer with `Qt.callLater`.
- [niri include semantics](niri-include-semantics.md) — `optional=true` excuses a missing file and nothing else; how to probe the failure paths without breaking the compositor.
- [What DMS gives a plugin popout](dms-plugin-popout-behavior.md) — Escape and CLI toggling come free, the popout seizes the keyboard while open, and `widget status` is broken upstream.
