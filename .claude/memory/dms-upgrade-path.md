# The Installed DMS Version Lags Upstream, and Why That Matters

DMS is not installed by whatever manages this plugin. It arrives as a distro
package (`rpm -qf /usr/share/quickshell/dms/DMSShellIPC.qml` names it), which
means the version you are testing against is set by a packaging pipeline, not
by upstream's release cadence.

Consequence: **never write an upstream bug report from the installed source
alone.** Check the installed version first, then compare against the current
tag and default branch on GitHub before describing a symptom.

```
dms --version                                   # what you are actually running
gh release list --repo AvengeMedia/DankMaterialShell --limit 5
gh api "repos/AvengeMedia/DankMaterialShell/contents/<path>?ref=<tag>" \
    --jq '.content' | base64 -d
```

Quote the URL in zsh — the `?ref=` makes it a glob otherwise, and `gh` fails
with a confusing "no matches found."

This is not hypothetical. The `widget status` bug in
[[dms-plugin-popout-behavior]] was very nearly reported with a symptom upstream
had already fixed; the installed build predated the fix by weeks, and only
diffing against the release tag caught it.

Upstream restructured its QML tree under `quickshell/` in 1.6.0, so paths read
off an older installed copy will not resolve against a current tag either.
