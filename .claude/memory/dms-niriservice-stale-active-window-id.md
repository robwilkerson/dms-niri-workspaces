# `NiriService.allWorkspaces[].active_window_id` Is Frozen Through DMS 1.6.1

Each workspace object DMS's `NiriService` exposes carries an `active_window_id`.
On DMS releases through v1.6.1 it is correct at startup and then frozen for the
life of the shell. Only a window's `is_focused` flag tracks focus live. Fixed
upstream on 2026-09-17 via
[DankMaterialShell#3462](https://github.com/AvengeMedia/DankMaterialShell/issues/3462),
which links the commit and its backport to the 1.6 line, so the first 1.6.x
patch after that date carries it; distro packages lag.

**Cause.** `NiriService` stores workspaces in a plain object keyed by id and
rebuilds it on every focus event with `for (const id in root.workspaces)`.
Those keys are strings. Both `handleWindowFocusChanged` and
`handleWorkspaceActiveWindowChanged` pick the workspace to replace with
`id === data.workspace_id`, comparing that string against niri's numeric id, so
the updated copy is never written back. `handleWorkspacesChanged` then
preserves the old value over the fresh one niri sent. Nothing in DMS itself
reads the field except as a fallback behind `is_focused`, which is why it went
unnoticed. The report above was framed functionally without the mechanism; the
maintainer fixed it the same day with an `updateWorkspace` helper and found
the same latent bug in `handleWorkspaceUrgencyChanged`, so `is_urgent` was
frozen too.

**Symptom in this plugin.** `wsColumns` once let a match on `active_window_id`
compete with `is_focused`, last one in column order winning. A workspace whose
snapshotted window later got pushed to a trailing column showed a highlight
stuck on that column. It surfaced only where a long-lived window predated the
shell and newer windows were moved in front of it (#7).

**Rule.** For the focused workspace, trust `is_focused` and nothing else. Use
`active_window_id` only for unfocused workspaces, where no window is focused
and it is the sole signal available. Keep this ordering even after the upstream
fix ships: installed DMS versions trail releases by weeks, and the ordering is
correct on both sides of the fix. Expect unfocused popout rows to be stale on
DMS ≤ 1.6.1 and live afterward.

**Diagnosing similar reports.** `niri msg --json event-stream` while switching
focus shows whether niri emitted the event; if it did and the shell state is
wrong, the fault is in `NiriService`'s handler, not the compositor. The live
source DMS is running sits under `$XDG_RUNTIME_DIR/danklinux-shell/*/Services/`.

Related: [[dms-upgrade-path]] for checking the running version before filing
upstream.
