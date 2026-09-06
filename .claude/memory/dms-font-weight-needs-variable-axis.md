# `font.weight` Alone Does Nothing in a DMS Plugin

Setting `font.weight: Font.DemiBold` (or `Font.Bold`) on a `StyledText` renders
Regular, with no warning and no log line. It looks like the property was
ignored.

**Cause.** `font.weight` selects a *face*; it does not deform one. DMS's sans is
`DankCommon/assets/fonts/inter/InterVariable.ttf`, pulled in by a QML
`FontLoader` in `DankCommon/Common/Fonts.qml`. Qt registers a variable font
loaded that way as a single instance at weight 400, and Inter is not installed
system-wide (`fc-list | grep -i inter` comes back empty), so there is no
heavier face anywhere to match. Qt finds nothing, falls back to Regular, and
says nothing about it.

**Fix.** Drive the `wght` variable axis directly, alongside the weight. Qt 6.7+
is required; the box runs 6.11.

```qml
readonly property int labelWeight: isActive ? Font.DemiBold : Font.Normal
// ...
font.weight: labelWeight
font.variableAxes: ({ "wght": labelWeight })
```

Feed both from one property so the two cannot drift. This is DMS's own idiom:
`DankCommon/Widgets/DankIcon.qml:38` sets `FILL`, `GRAD`, `opsz` and `wght` the
same way to animate Material Symbols.

**Scope.** Anything rendering text through `StyledText`, which is every label in
every plugin. Assume any existing `font.weight` above Normal in this repo is
currently a no-op and needs the axis added before it does what it claims —
the group headers in `NiriWorkspaces.qml` were exactly that.

Numeric axis values follow Qt 6's 100-900 weight scale, so `Font.Normal` is 400
and `Font.DemiBold` is 600 and the enum can be passed straight through.
