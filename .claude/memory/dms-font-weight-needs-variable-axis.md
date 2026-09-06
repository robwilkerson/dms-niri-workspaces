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
every plugin. A `font.weight` above Normal with no matching axis is not merely
ineffective, it is misleading: it reads as intent that the rendering never
honored. This repo carried four such declarations (two section headers and a
group title in the settings pane, one group header in the popout); all were
deleted rather than repaired, because the unbolded look was the one actually
shipped and preferred. Add the axis only where bold is genuinely wanted.

Numeric axis values follow Qt 6's 100-900 weight scale, so `Font.Normal` is 400
and `Font.DemiBold` is 600 and the enum can be passed straight through.
