# Project Memory

Shared, committed knowledge for this repo. One line per memory.

- [FileView re-entrancy](fileview-reentrancy.md) — reassigning `FileView.path` inside its own `onLoaded` silently drops the read; defer with `Qt.callLater`.
