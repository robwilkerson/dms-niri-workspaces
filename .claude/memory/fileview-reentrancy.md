---
name: fileview-reentrancy
description: Reassigning a Quickshell FileView's path from inside its own onLoaded handler silently drops the next read.
metadata:
  type: project
---

Never reassign `FileView.path` from inside that same FileView's `onLoaded` or
`onLoadFailed` handler. The new load is dropped: no read happens, no signal
fires, and no error is logged anywhere. Defer with `Qt.callLater(fn)` so each
read starts on a fresh event-loop turn.

This is what `services/NiriConfigService.qml` does when walking niri's config
and its `include` chain with a single reader.

**Why:** The failure is completely silent. `NiriConfigService` read
`config.kdl` correctly, queued all six plain `include` targets, assigned
`reader.path` to the first — and nothing further ran. The settings pane showed
"No named workspaces found in niri's config" with `lastError` empty, which
reads as "your config has no workspaces" rather than "the reader stopped".
Nothing appeared in `journalctl`.

**How to apply:** When a single `FileView` walks a queue of files, the handler
must schedule the next read rather than start it:

```qml
onLoaded: {
    root._parse(reader.text() || "", reader.path);
    Qt.callLater(root._readNext);   // NOT root._readNext()
}
```

Related trap in the same function: clearing `path` to `""` to force a re-read of
the *same* file fires `loadFailed` synchronously, which re-enters the queue
walker and drains it out of order. Use `reader.reload()` for that case instead.

Debugging note: plugin `console.log` output did not reach `journalctl` in this
setup, and opening the settings window logged nothing at all. Rendering a
diagnostic string into the pane itself was what actually localized this — worth
reaching for early rather than after several restart cycles.
