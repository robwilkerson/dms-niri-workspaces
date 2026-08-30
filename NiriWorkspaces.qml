// Niri Workspaces — a DankMaterialShell dankbar widget.
//
// Bar: the focused workspace's name + a pill segmented to match its niri column
// count (active column full-strength, inactive columns faded). Clicking anywhere
// on the widget opens a grouped dropdown of all named workspaces (same pill
// treatment, current one highlighted) with click-to-switch, plus a "New
// workspace" action that jumps to niri's trailing auto-empty.
//
// Groups come from plugin settings, which own both the group list and its
// members; see NiriWorkspacesSettings.qml. niri has no grouping concept of its
// own, so anything settings does not claim renders as one untitled trailing
// group.
//
// niri-specific: columns come from `layout.pos_in_scrolling_layout` read off
// DMS's NiriService, so this does nothing useful on other compositors.
import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // Distinct niri columns on a workspace, each flagged active if it holds
    // that workspace's focused/active window. Returns [{col, active}], sorted.
    function wsColumns(ws) {
        if (!ws)
            return [];
        const wid = ws.id;
        const activeWinId = ws.active_window_id;
        const wins = NiriService.windows || [];
        let activeCol = -1;
        let cols = [];
        for (let i = 0; i < wins.length; i++) {
            const w = wins[i];
            if (w.workspace_id !== wid)
                continue;
            const pos = w.layout ? w.layout.pos_in_scrolling_layout : null;
            if (!pos || pos.length < 1)
                continue;
            const c = pos[0];
            if (cols.indexOf(c) < 0)
                cols.push(c);
            if ((activeWinId != null && w.id === activeWinId) || w.is_focused)
                activeCol = c;
        }
        cols.sort(function (a, b) { return a - b; });
        let out = [];
        for (let i = 0; i < cols.length; i++)
            out.push({ "col": cols[i], "active": cols[i] === activeCol });
        return out;
    }

    readonly property var focusedWs: {
        const all = NiriService.allWorkspaces || [];
        for (let i = 0; i < all.length; i++)
            if (all[i].is_focused)
                return all[i];
        for (let i = 0; i < all.length; i++)
            if (String(all[i].id) === String(NiriService.focusedWorkspaceId))
                return all[i];
        return null;
    }

    readonly property string wsName: {
        if (!focusedWs)
            return "";
        return (focusedWs.name && focusedWs.name.length > 0) ? focusedWs.name : ("" + focusedWs.idx);
    }

    readonly property var columnList: wsColumns(focusedWs)

    // Named workspaces in niri index order, excluding the transient trailing
    // empty and the currently-focused one (a switcher shouldn't list where you
    // already are).
    readonly property var namedWorkspaces: {
        const all = (NiriService.allWorkspaces || []).slice();
        all.sort(function (a, b) { return (a.idx || 0) - (b.idx || 0); });
        const fid = root.focusedWs ? root.focusedWs.id : null;
        return all.filter(function (w) { return w.name && w.name.length > 0 && w.id !== fid; });
    }

    // ── Group membership (user-defined; see NiriWorkspacesSettings.qml) ──
    // Settings own both the groups and their members. niri has no grouping
    // concept of its own, so there is nothing to fall back to: with no groups
    // configured, every named workspace lands in the ungrouped list below.
    readonly property var groupConfig: {
        const raw = root.pluginData?.groups;
        return Array.isArray(raw) ? raw : [];
    }

    readonly property bool showUngrouped: root.pluginData?.showUngrouped ?? true

    // Carded groups in configured order, each resolved from names to the live
    // workspace objects. A configured name with no live workspace is dropped
    // rather than rendered dead — niri is the authority on what exists.
    readonly property var groupDefs: {
        let out = [];
        for (let i = 0; i < root.groupConfig.length; i++) {
            const g = root.groupConfig[i];
            // plugin settings are user-editable JSON on disk, so a malformed
            // entry must skip rather than take the whole popout down with it.
            if (!g)
                continue;
            const names = Array.isArray(g.workspaces) ? g.workspaces : [];
            const model = names.map(function (n) {
                return root.namedWorkspaces.find(function (w) {
                    return w.name === n;
                });
            }).filter(function (w) {
                return w !== undefined;
            });
            out.push({
                "title": String(g.title || ""),
                "model": model
            });
        }
        return out;
    }

    // Anything no group claimed, rendered as a trailing group of its own.
    readonly property var wsUngrouped: {
        if (!root.showUngrouped)
            return [];
        let claimed = [];
        for (let i = 0; i < root.groupConfig.length; i++) {
            const g = root.groupConfig[i];
            if (g && Array.isArray(g.workspaces))
                claimed = claimed.concat(g.workspaces);
        }
        return root.namedWorkspaces.filter(function (w) {
            return claimed.indexOf(w.name) < 0;
        });
    }

    // What the popout actually renders: the configured groups, then the
    // ungrouped set as an implied group so it reads like the rest. That
    // implied group is titled only when there are real groups to tell it
    // apart from — with none configured it holds every workspace, where an
    // "Ungrouped" header would label the whole list.
    readonly property var renderGroups: {
        if (root.wsUngrouped.length === 0)
            return root.groupDefs;
        return root.groupDefs.concat([{
            "title": root.groupDefs.length > 0 ? "Ungrouped" : "",
            "model": root.wsUngrouped
        }]);
    }

    // niri's trailing auto-created empty workspace (highest-idx unnamed one).
    readonly property var newWorkspaceWs: {
        const all = NiriService.allWorkspaces || [];
        let cand = null;
        for (let i = 0; i < all.length; i++) {
            const w = all[i];
            if (w.name && w.name.length > 0)
                continue;
            if (!cand || (w.idx || 0) > (cand.idx || 0))
                cand = w;
        }
        return cand;
    }

    readonly property real segH: Math.max(8, barThickness * 0.30)
    readonly property real segW: Math.round(segH * 1.5)
    readonly property real segGap: 2

    // ── Bar pill ────────────────────────────────────────────────────────
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            // Name: visual-only, so a click falls through to BasePill's
            // MouseArea (z:-1) and toggles the dropdown.
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.wsName
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                color: Theme.surfaceText
            }

            // Pill: visual-only like the name, so the whole widget is one
            // dropdown trigger with no dead zone.
            Row {
                id: barSegs
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.segGap

                Repeater {
                    model: root.columnList.length > 0 ? root.columnList : [{ "col": 0, "active": false }]

                    delegate: Rectangle {
                        required property int index
                        required property var modelData

                        readonly property int segN: root.columnList.length > 0 ? root.columnList.length : 1
                        readonly property real endR: root.segH / 2

                        width: root.segW
                        height: root.segH
                        color: root.columnList.length === 0
                            ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.3)
                            : (modelData.active ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35))
                        topLeftRadius: index === 0 ? endR : 2
                        bottomLeftRadius: index === 0 ? endR : 2
                        topRightRadius: index === (segN - 1) ? endR : 2
                        bottomRightRadius: index === (segN - 1) ? endR : 2
                    }
                }
            }
        }
    }

    // ── Dropdown ────────────────────────────────────────────────────────
    popoutWidth: 260
    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: "Workspaces"
            showCloseButton: true

            // Groups are defined in the settings pane, so give the dropdown a
            // direct route there. DMS only deep-links as far as the Plugins
            // tab — PluginsTab owns `expandedPluginId` but nothing outside it
            // can set it — so this lands on the list, not on our entry.
            headerActions: Component {
                DankActionButton {
                    iconName: "settings"
                    iconColor: Theme.surfaceVariantText
                    buttonSize: 28
                    tooltipText: "Plugin Settings"
                    tooltipSide: "bottom"
                    onClicked: {
                        root.closePopout();
                        PopoutService.openSettingsWithTab("plugins");
                    }
                }
            }

            // Shared workspace-row delegate, used by every group's Repeater.
            Component {
                id: wsRowComp

                Rectangle {
                    id: wsRow
                    required property var modelData

                    readonly property var rowCols: root.wsColumns(modelData)
                    readonly property var rowSegs: rowCols.length > 0 ? rowCols : [{ "col": 0, "active": false }]

                    width: parent ? parent.width : 0
                    height: root.segH + Theme.spacingM
                    radius: Theme.cornerRadius
                    color: rowMouse.containsMouse
                        ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                        : "transparent"

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            NiriService.switchToWorkspace(wsRow.modelData.id);
                            if (popout.closePopout)
                                popout.closePopout();
                        }
                    }

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.right: rowPill.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: wsRow.modelData.name
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Normal
                        color: Theme.surfaceText
                    }

                    Row {
                        id: rowPill
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.segGap

                        Repeater {
                            model: wsRow.rowSegs

                            delegate: Rectangle {
                                required property int index
                                required property var modelData

                                readonly property int segN: wsRow.rowSegs.length
                                readonly property real endR: root.segH / 2

                                width: root.segW
                                height: root.segH
                                color: wsRow.rowCols.length === 0
                                    ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.3)
                                    : (modelData.active ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35))
                                topLeftRadius: index === 0 ? endR : 2
                                bottomLeftRadius: index === 0 ? endR : 2
                                topRightRadius: index === (segN - 1) ? endR : 2
                                bottomRightRadius: index === (segN - 1) ? endR : 2
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingL

                // Carded groups, in the order the settings pane lists them,
                // with the implied ungrouped group last.
                Repeater {
                    model: root.renderGroups

                    delegate: Column {
                        id: grp
                        required property var modelData

                        width: parent ? parent.width : 0
                        visible: grp.modelData.model.length > 0
                        spacing: Theme.spacingXS

                        Item {
                            width: parent.width
                            visible: grp.modelData.title !== ""
                            height: visible ? grpHdr.implicitHeight : 0

                            StyledText {
                                id: grpHdr
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                text: grp.modelData.title
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                                color: Theme.outline
                            }
                        }

                        Rectangle {
                            width: parent.width
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerHigh
                            height: grpCol.implicitHeight + Theme.spacingXS * 2

                            Column {
                                id: grpCol
                                x: Theme.spacingXS
                                y: Theme.spacingXS
                                width: parent.width - Theme.spacingXS * 2
                                Repeater { model: grp.modelData.model; delegate: wsRowComp }
                            }
                        }
                    }
                }

                // Divider + New workspace action.
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.15
                }

                Rectangle {
                    width: parent.width
                    height: root.segH + Theme.spacingM
                    radius: Theme.cornerRadius
                    visible: root.newWorkspaceWs !== null
                    color: newMouse.containsMouse
                        ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                        : "transparent"

                    MouseArea {
                        id: newMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.newWorkspaceWs)
                                NiriService.switchToWorkspace(root.newWorkspaceWs.id);
                            if (popout.closePopout)
                                popout.closePopout();
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "add"
                            size: Theme.fontSizeLarge
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "New workspace"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                        }
                    }
                }
            }
        }
    }
}
