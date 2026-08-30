# What DMS Gives a Plugin Popout for Free

Verified against the DMS source at `/usr/share/quickshell/dms/`.

**Escape closes it already.** `Modules/Plugins/PluginPopout.qml` hardcodes a
`Keys.onPressed` handler for Escape. A plugin writes nothing for this.

**The popout takes the keyboard while open.** On niri,
`Common/KeyboardFocus.qml:12-22` resolves to `WlrKeyboardFocus.Exclusive` as
soon as the popout is visible, wired in at
`Widgets/DankPopoutStandalone.qml:673-676` (`CompositorService.qml:26` leaves
`useHyprlandFocusGrab` false on niri, so the exclusive branch runs). The
consequence is easy to miss: while the popout is open the compositor receives
no keystrokes, and every key except Escape is delivered to the popout and
dropped. `PluginPopout` exposes no knob for this — it never forwards the
`customKeyboardFocus` or `contentHandlesKeys` properties the base `DankPopout`
has. A plugin can still add its own `Keys.onPressed` inside `popoutContent`.

**Any popout can be toggled from the CLI.** `Modules/DankBar/WidgetHost.qml:232`
registers every bar widget with `BarWidgetService` keyed by plugin id, so
`dms ipc call widget toggle <pluginId>` works with no plugin-side support —
`BarWidgetService.triggerWidgetPopout()` falls through to
`PluginComponent.triggerPopout()` (`Modules/Plugins/PluginComponent.qml:307`).
This is why a plugin does not need its own hotkey setting; a compositor keybind
spawning that command is enough.

## Upstream Bug, Not Yet Reported

`dms ipc call widget status <pluginId>` always returns `hidden` for plugin
widgets. `DMSShellIPC.qml:1178` reads `widget.popoutTarget?.shouldBeVisible`,
but `PluginComponent` sets `popoutTarget` on its child pills (`:186`, `:246`)
rather than on its own root, which is the object registered with
`BarWidgetService`. Affects every DMS plugin; `toggle` is unaffected.
