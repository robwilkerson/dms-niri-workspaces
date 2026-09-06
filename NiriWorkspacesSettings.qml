// Niri Workspaces — settings panel (Settings → Plugin Management).
//
// Three things happen here: define groups, see the workspaces niri declares,
// and drag a workspace onto a group to assign it. Row order is render order in
// the dropdown; anything left in the pool renders ungrouped at the bottom.
//
// niri models no grouping of its own — its config is a flat list of
// `workspace "Name" {}` nodes — so the assignment lives only in plugin
// settings, keyed "niriWorkspaces" and read back by NiriWorkspaces.qml.
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root

    // PluginSettings declares pluginId `required` and injects nothing, so a
    // settings pane must state it. A wrong literal silently resolves against
    // another plugin's settings with no error anywhere.
    pluginId: "niriWorkspaces"

    StyledText {
        width: parent.width
        text: "Workspace Groups"
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.surfaceText
    }

    Item {
        id: editor

        width: parent.width
        implicitHeight: layout.implicitHeight

        // [{ title: string, workspaces: [string] }] — order is render order.
        property var groups: []

        // PluginSettings calls loadValue() on its children at load and again
        // whenever this plugin's stored data changes, so this is the hook that
        // keeps the pane in sync rather than a Component.onCompleted.
        function loadValue() {
            const raw = root.loadValue("groups", []);
            if (!Array.isArray(raw)) {
                editor.groups = [];
                return;
            }
            // Normalize defensively: this is user-editable JSON on disk.
            editor.groups = raw.map(function (g) {
                return {
                    "title": String((g && g.title) || ""),
                    "workspaces": Array.isArray(g && g.workspaces) ? g.workspaces.slice() : []
                };
            }).filter(function (g) {
                return g.title.length > 0;
            });
        }

        function persist() {
            root.saveValue("groups", editor.groups);
        }

        // Reassigning `groups` wholesale is what makes the bindings below
        // re-evaluate; mutating in place would not notify.
        function _commit(next) {
            editor.groups = next;
            editor.persist();
        }

        readonly property var assignedNames: {
            let out = [];
            for (let i = 0; i < groups.length; i++)
                out = out.concat(groups[i].workspaces);
            return out;
        }

        // The pool: everything niri declares that no group has claimed.
        readonly property var unassignedNames: {
            const declared = NiriConfigService.workspaceNames || [];
            const taken = editor.assignedNames;
            return declared.filter(function (n) {
                return taken.indexOf(n) < 0;
            });
        }

        // A title is the user's only handle on a group, so it has to be
        // non-empty and unique. `exempt` is the group index allowed to keep its
        // current title — a rename checking itself — and is -1 when adding.
        function titleAvailable(exempt, title) {
            const clean = title.trim();
            if (clean.length === 0)
                return false;
            for (let i = 0; i < editor.groups.length; i++)
                if (i !== exempt && editor.groups[i].title === clean)
                    return false;
            return true;
        }

        function addGroup(title) {
            if (!editor.titleAvailable(-1, title))
                return;
            const next = editor.groups.slice();
            next.push({
                "title": title.trim(),
                "workspaces": []
            });
            editor._commit(next);
        }

        // Membership is stored by workspace name rather than by title, so a
        // rename is purely cosmetic and nothing else has to move. Returns
        // whether it took, so the field can stay open on a rejected title.
        function renameGroup(index, title) {
            if (!editor.titleAvailable(index, title))
                return false;
            const next = editor.groups.slice();
            next[index] = {
                "title": title.trim(),
                "workspaces": next[index].workspaces.slice()
            };
            editor._commit(next);
            return true;
        }

        function removeGroup(index) {
            const next = editor.groups.slice();
            next.splice(index, 1);
            editor._commit(next);
        }

        // Reorder is by arrows rather than dragging the card: the card is
        // already a DropArea for workspace chips, so a drag on it would be
        // ambiguous between "move this group" and "assign here".
        function moveGroup(index, delta) {
            const target = index + delta;
            if (target < 0 || target >= editor.groups.length)
                return;
            const next = editor.groups.slice();
            const moved = next.splice(index, 1)[0];
            next.splice(target, 0, moved);
            editor._commit(next);
        }

        // Assigning always unassigns first, so a workspace can live in exactly
        // one group and a drag between groups is a move rather than a copy.
        function assign(name, groupIndex) {
            const next = editor.groups.map(function (g) {
                return {
                    "title": g.title,
                    "workspaces": g.workspaces.filter(function (n) {
                        return n !== name;
                    })
                };
            });
            if (groupIndex >= 0 && groupIndex < next.length)
                next[groupIndex].workspaces.push(name);
            editor._commit(next);
        }

        function unassign(name) {
            editor.assign(name, -1);
        }

        // Reorder within a group: drop a chip onto another chip to land in
        // front of it. Anchored to the target's NAME rather than its index,
        // because removing the dragged chip first shifts every index after it.
        function insertBefore(name, groupIndex, targetName) {
            if (name === targetName)
                return;
            const next = editor.groups.map(function (g) {
                return {
                    "title": g.title,
                    "workspaces": g.workspaces.filter(function (n) {
                        return n !== name;
                    })
                };
            });
            if (groupIndex < 0 || groupIndex >= next.length)
                return;
            const list = next[groupIndex].workspaces;
            const at = list.indexOf(targetName);
            if (at < 0)
                list.push(name);
            else
                list.splice(at, 0, name);
            editor._commit(next);
        }

        // ── Draggable workspace chip ────────────────────────────────────
        // The outer Item is what the layout positions; the inner rect is what
        // moves. Dragging the rect therefore never fights Flow/Column for
        // position, and releasing snaps it home by resetting x/y.
        component WsChip: Item {
            id: slot

            required property string wsName

            // Which group this chip sits in; -1 for the unassigned pool, where
            // order comes from niri's config and is not ours to rearrange.
            required property int groupIndex

            implicitWidth: body.width
            implicitHeight: body.height

            // Declared before the body so the chip draws over it. Drops landing
            // here beat the enclosing group card's DropArea, which is what turns
            // a chip-on-chip drop into a reorder instead of an append.
            DropArea {
                id: chipDrop

                anchors.fill: parent
                enabled: slot.groupIndex >= 0
                onDropped: drop => {
                    editor.insertBefore(drop.source.wsName, slot.groupIndex, slot.wsName);
                    drop.accept(Qt.MoveAction);
                }
            }

            Rectangle {
                id: body

                // Mirrored on the drop side as `drop.source.wsName`.
                readonly property string wsName: slot.wsName

                width: chipLabel.implicitWidth + Theme.spacingM * 2
                height: chipLabel.implicitHeight + Theme.spacingS * 2
                radius: height / 2
                color: dragArea.drag.active ? Theme.primary : Theme.surfaceContainerHigh
                // A left edge marks where the dragged chip will be inserted.
                border.width: chipDrop.containsDrag ? 2 : 1
                border.color: chipDrop.containsDrag ? Theme.primary : Theme.outline
                opacity: dragArea.drag.active ? 0.9 : 1
                // Lift above later siblings while dragging, or the chip slides
                // underneath the group cards it is being dragged toward.
                z: dragArea.drag.active ? 100 : 0

                Drag.active: dragArea.drag.active
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                StyledText {
                    id: chipLabel

                    anchors.centerIn: parent
                    text: slot.wsName
                    font.pixelSize: Theme.fontSizeSmall
                    color: dragArea.drag.active ? Theme.onPrimary : Theme.surfaceText
                }

                MouseArea {
                    id: dragArea

                    anchors.fill: parent
                    cursorShape: dragArea.drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: body
                    onReleased: {
                        body.Drag.drop();
                        // Snap home whether or not a DropArea took it. On a
                        // successful drop the model rebuilds and this chip is
                        // replaced; on a miss, this is what undoes the drag.
                        body.x = 0;
                        body.y = 0;
                    }
                }
            }
        }

        Column {
            id: layout

            width: parent.width
            spacing: Theme.spacingL

            // ── Define groups ───────────────────────────────────────────
            Row {
                width: parent.width
                spacing: Theme.spacingS

                DankTextField {
                    id: newGroupField

                    width: parent.width - addButton.width - Theme.spacingS
                    placeholderText: "New group name"
                }

                DankButton {
                    id: addButton

                    text: "Add"
                    iconName: "add"
                    onClicked: {
                        editor.addGroup(newGroupField.text);
                        newGroupField.text = "";
                    }
                }
            }

            StyledText {
                width: parent.width
                visible: editor.groups.length === 0
                wrapMode: Text.WordWrap
                text: "No groups yet. Add one above, then drag workspaces onto it."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            // ── Groups, each a drop target ──────────────────────────────
            Repeater {
                model: editor.groups

                delegate: Rectangle {
                    id: groupCard

                    required property int index
                    required property var modelData

                    // Renaming happens in place: the title text swaps for a
                    // field rather than opening a dialog over the card.
                    property bool editing: false

                    function beginRename() {
                        titleField.text = groupCard.modelData.title;
                        groupCard.editing = true;
                        titleField.forceActiveFocus();
                        titleField.selectAll();
                    }

                    function commitRename() {
                        if (editor.renameGroup(groupCard.index, titleField.text))
                            groupCard.editing = false;
                    }

                    width: layout.width
                    height: groupCol.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: groupDrop.containsDrag ? Theme.primaryContainer : Theme.surfaceContainerHigh
                    border.width: 1
                    border.color: groupDrop.containsDrag ? Theme.primary : "transparent"

                    DropArea {
                        id: groupDrop

                        anchors.fill: parent
                        onDropped: drop => {
                            editor.assign(drop.source.wsName, groupCard.index);
                            drop.accept(Qt.MoveAction);
                        }
                    }

                    Column {
                        id: groupCol

                        x: Theme.spacingM
                        y: Theme.spacingM
                        width: parent.width - Theme.spacingM * 2
                        spacing: Theme.spacingS

                        Item {
                            width: parent.width
                            // The action buttons are taller than the title text,
                            // and the rename field taller than either, so size to
                            // whichever is showing or the row clips.
                            height: groupCard.editing
                                ? titleField.height
                                : Math.max(groupTitle.implicitHeight, 28)

                            StyledText {
                                id: groupTitle

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !groupCard.editing
                                text: groupCard.modelData.title
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                            }

                            DankTextField {
                                id: titleField

                                anchors.left: parent.left
                                anchors.right: groupActions.left
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                visible: groupCard.editing
                                // A blank or already-taken title is refused on
                                // commit, so say so while it is still being typed.
                                normalBorderColor: valid ? Theme.outlineMedium : Theme.error
                                focusedBorderColor: valid ? Theme.primary : Theme.error

                                readonly property bool valid: editor.titleAvailable(groupCard.index, text)

                                onAccepted: groupCard.commitRename()
                                Keys.onEscapePressed: groupCard.editing = false
                            }

                            Row {
                                id: groupActions

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingXS

                                DankActionButton {
                                    buttonSize: 28
                                    iconName: groupCard.editing ? "check" : "edit"
                                    enabled: !groupCard.editing || titleField.valid
                                    opacity: enabled ? 1 : 0.35
                                    iconColor: Theme.surfaceVariantText
                                    tooltipText: groupCard.editing ? "Save name" : "Rename group"
                                    onClicked: {
                                        if (groupCard.editing)
                                            groupCard.commitRename();
                                        else
                                            groupCard.beginRename();
                                    }
                                }

                                DankActionButton {
                                    buttonSize: 28
                                    iconName: "arrow_upward"
                                    enabled: groupCard.index > 0
                                    opacity: enabled ? 1 : 0.35
                                    iconColor: Theme.surfaceVariantText
                                    tooltipText: "Move up"
                                    onClicked: editor.moveGroup(groupCard.index, -1)
                                }

                                DankActionButton {
                                    buttonSize: 28
                                    iconName: "arrow_downward"
                                    enabled: groupCard.index < editor.groups.length - 1
                                    opacity: enabled ? 1 : 0.35
                                    iconColor: Theme.surfaceVariantText
                                    tooltipText: "Move down"
                                    onClicked: editor.moveGroup(groupCard.index, 1)
                                }

                                DankActionButton {
                                    buttonSize: 28
                                    iconName: "delete"
                                    iconColor: Theme.surfaceVariantText
                                    tooltipText: "Remove group (its workspaces return to the pool)"
                                    onClicked: editor.removeGroup(groupCard.index)
                                }
                            }
                        }

                        StyledText {
                            width: parent.width
                            visible: groupCard.modelData.workspaces.length === 0
                            text: "Drop workspaces here"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        Flow {
                            width: parent.width
                            spacing: Theme.spacingXS

                            Repeater {
                                model: groupCard.modelData.workspaces

                                delegate: WsChip {
                                    required property var modelData

                                    wsName: modelData
                                    groupIndex: groupCard.index
                                }
                            }
                        }
                    }
                }
            }

            // ── The pool of declared workspaces ─────────────────────────
            StyledText {
                width: parent.width
                text: "Workspaces"
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                text: NiriConfigService.lastError !== "" ? NiriConfigService.lastError : "Declared in niri's config. Drag one onto a group above; drop it back here to unassign."
                font.pixelSize: Theme.fontSizeSmall
                color: NiriConfigService.lastError !== "" ? Theme.error : Theme.surfaceVariantText
            }

            Rectangle {
                width: parent.width
                height: poolCol.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: poolDrop.containsDrag ? Theme.primaryContainer : Theme.surfaceContainerHigh
                border.width: 1
                border.color: poolDrop.containsDrag ? Theme.primary : "transparent"

                DropArea {
                    id: poolDrop

                    anchors.fill: parent
                    onDropped: drop => {
                        editor.unassign(drop.source.wsName);
                        drop.accept(Qt.MoveAction);
                    }
                }

                Column {
                    id: poolCol

                    x: Theme.spacingM
                    y: Theme.spacingM
                    width: parent.width - Theme.spacingM * 2
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width
                        visible: editor.unassignedNames.length === 0
                        text: NiriConfigService.workspaceNames.length === 0 ? "No named workspaces found in niri's config." : "Every declared workspace is assigned."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.spacingXS

                        Repeater {
                            model: editor.unassignedNames

                            delegate: WsChip {
                                required property var modelData

                                wsName: modelData
                                groupIndex: -1
                            }
                        }
                    }
                }
            }

            DankButton {
                text: "Rescan niri config"
                iconName: "refresh"
                onClicked: NiriConfigService.reload()
            }
        }
    }

    ToggleSetting {
        settingKey: "showUngrouped"
        label: "Show ungrouped workspaces"
        description: "List named workspaces that no group claims, below the groups"
        defaultValue: true
    }
}
