// Reads the workspace names niri declares in its own config.
//
// niri's config is the authority on which workspaces exist and in what order:
// declaration order in `config.kdl` is the persistent stack order. The live
// NiriService list reflects the same set, but the config is where the user
// actually spells them, so it is what the settings pane offers for grouping.
//
// niri models no grouping of its own — the config is a flat list of
// `workspace "Name" {}` nodes — so grouping lives entirely in plugin settings.
// This service only answers "what workspaces exist, in what order".
pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    // Workspace names in declaration order: the main config first, then each
    // include at the point it was included.
    property var workspaceNames: []

    // Empty when the last scan succeeded. Non-empty is not fatal: the widget
    // still works off live NiriService state, it just can't offer the config's
    // list for grouping.
    property string lastError: ""

    readonly property string configDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation)) + "/niri"
    readonly property string mainConfigPath: configDir + "/config.kdl"

    // ── Scan state ──────────────────────────────────────────────────────
    // A single FileView walks a queue rather than instantiating one reader per
    // include. `_seen` guards against an include cycle, which niri tolerates
    // but which would spin forever here.
    property var _pending: []
    property var _seen: ({})
    property var _names: []
    // Paths niri declared `optional=true`, which it is allowed to not find.
    // Keyed by resolved path so the failure handler can tell an absent optional
    // include from a genuinely broken one.
    property var _optional: ({})

    function reload() {
        root._pending = [root.mainConfigPath];
        // Seed with the main config so a config that includes itself by name is
        // caught on the first hop rather than being read a second time.
        root._seen = {};
        root._seen[root.mainConfigPath] = true;
        root._names = [];
        root._optional = {};
        root.lastError = "";
        _readNext();
    }

    function _readNext() {
        if (root._pending.length === 0) {
            root.workspaceNames = root._names;
            return;
        }
        const next = root._pending.shift();
        // Assigning a *different* path loads it. Clearing the path first would
        // be the obvious way to force a re-read of the same one, but an empty
        // path fires loadFailed synchronously, which re-enters this function
        // and drains the queue out of order. reload() re-reads in place.
        if (reader.path === next)
            reader.reload();
        else
            reader.path = next;
    }

    // Collapse `.`, `..`, and doubled slashes so one file has exactly one
    // identity. Without this, `./config.kdl` and `config.kdl` are different
    // keys in _seen and the same file gets read twice.
    function _normalize(path) {
        const parts = path.split("/");
        let out = [];
        for (let i = 0; i < parts.length; i++) {
            const p = parts[i];
            if (p === "." || (p === "" && out.length > 0))
                continue;
            if (p === ".." && out.length > 1) {
                out.pop();
                continue;
            }
            out.push(p);
        }
        return out.join("/") || "/";
    }

    // Resolve an include target against the directory holding the file that
    // declared it. Absolute and ~-prefixed paths are taken as-is.
    function _resolve(target, fromPath) {
        if (target.startsWith("/"))
            return root._normalize(target);
        if (target.startsWith("~/"))
            return root._normalize(Paths.strip(StandardPaths.writableLocation(StandardPaths.HomeLocation)) + target.substring(1));
        const dir = fromPath.substring(0, fromPath.lastIndexOf("/"));
        return root._normalize(dir + "/" + target);
    }

    function _parse(text, fromPath) {
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            // Strip line comments before matching so a commented-out
            // `// workspace "Foo" {}` doesn't register as a real declaration.
            const line = lines[i].replace(/\/\/.*$/, "");

            const ws = line.match(/^\s*workspace\s+(?:"([^"]+)"|(\S+))/);
            if (ws) {
                const name = ws[1] !== undefined ? ws[1] : ws[2];
                if (name && root._names.indexOf(name) < 0)
                    root._names.push(name);
                continue;
            }

            // niri allows node properties before the path, as in
            // `include optional=true "foo.kdl"`. Match them explicitly rather
            // than skipping to the first quote, so a quoted property value
            // can't be mistaken for the include target.
            const inc = line.match(/^\s*include\s+((?:[A-Za-z_-]+=(?:true|false|"[^"]*")\s+)*)"([^"]+)"/);
            if (inc) {
                const path = root._resolve(inc[2], fromPath);
                if (!root._seen[path]) {
                    root._seen[path] = true;
                    if (/\boptional=(?:true|"true")/.test(inc[1]))
                        root._optional[path] = true;
                    root._pending.push(path);
                }
            }
        }
    }

    FileView {
        id: reader

        blockLoading: true
        onLoaded: {
            root._parse(reader.text() || "", reader.path);
            // Reassigning `path` from inside this handler drops the next load
            // silently — the read simply never happens. Defer so each file
            // starts on a fresh event-loop turn.
            Qt.callLater(root._readNext);
        }
        onLoadFailed: error => {
            // Keep scanning — a partial pool beats none — but never report it
            // as complete. `optional=true` excuses a file that isn't there and
            // nothing more: niri still fails on one that exists but can't be
            // read, so only FileNotFound is suppressed here. Anything else is
            // worth naming, and is as likely ours as the user's, since
            // _resolve only approximates niri's include resolution. Naming the
            // path we actually tried is what makes that visible.
            // First failure wins; reload() clears lastError before each scan.
            const excused = root._optional[reader.path] === true
                && error === FileViewError.FileNotFound;
            if (root.lastError === "" && !excused)
                root.lastError = "Could not read " + reader.path
                    + " (" + FileViewError.toString(error) + ")";
            Qt.callLater(root._readNext);
        }
    }

    // Re-scan when the main config changes. Includes are not watched: an edit
    // to one is nearly always accompanied by a niri reload, and the settings
    // pane offers a manual refresh regardless.
    FileView {
        path: root.mainConfigPath
        watchChanges: true
        onFileChanged: root.reload()
    }

    Component.onCompleted: root.reload()
}
