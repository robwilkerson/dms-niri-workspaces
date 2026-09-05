# What DMS Gives a Plugin Popout for Free

Verified against the DMS source at `/usr/share/quickshell/dms/`, which on this
box is DMS **1.5.3** (an RPM baked into the bootc image, not a nix package).

**Line numbers below are 1.5.3.** Upstream restructured in 1.6.0: every QML
path moved under `quickshell/` in the repo, so `Modules/Plugins/Foo.qml` is now
`quickshell/Modules/Plugins/Foo.qml` and offsets have drifted by a few dozen
lines. Re-grep before citing a location in an upstream report.

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

## Upstream Bug: `widget status` Misreports Every Plugin

`dms ipc call widget status <pluginId>` never reports a plugin's popout as
visible, in any release checked. The cause is stable across versions; only the
wrong answer has changed.

**Cause.** The object registered with `BarWidgetService` is the plugin's root
component — `WidgetHost.qml` registers it on the strength of `triggerPopout`
alone, without requiring `popoutTarget`. But `PluginComponent` sets
`popoutTarget` only on its child `BasePill`s. The root `Item` declares
`hasPopout` and hosts `PluginPopout { id: pluginPopout }`, yet never exposes
`popoutTarget` itself, so the IPC handler reads `undefined`.

**Fix is one line** on the `PluginComponent` root:
`readonly property var popoutTarget: hasPopout ? pluginPopout : null`

**Symptom by version:**

- **1.5.3** — returns `hidden`. Verified live: popout open on screen, still
  `hidden`, while the built-in `clock` correctly returns `visible`.
- **v1.6.0 and `master` @ `ea0b158e`** — returns `WIDGET_NO_POPOUT: <id>`.
  Verified by source inspection only, not a live run. Upstream #3032 fixed the
  silent `hidden` fall-through but not the missing property, so plugins are now
  wrong in a new way.

`toggle` is unaffected in every version; it routes through
`PluginComponent.triggerPopout()` and never consults `popoutTarget`.

**Reporting status: not yet filed.** Upstream #3032 covers the general
`status` complaint and is closed as completed; a plugin-specific follow-up is
still needed. Check the installed version before filing — a report written
against 1.5.3's `hidden` symptom would send a maintainer chasing something
already fixed. See [[dms-upgrade-path]] for why the installed version lags.
