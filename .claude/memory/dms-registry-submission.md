# Submitting to the DMS Plugin Registry

The registry (`AvengeMedia/dms-plugin-registry`) is an index of *pointers*, not
a mirror. An entry carries a `repo` URL and `dms plugins install <id>` clones
from that repo directly. Default branch is `master`, and PRs must target it.

**Check for an id/name collision before anything else.** Both `id` and `name`
must be unique across the whole registry, and this plugin lost `niriWorkspaces`
/ "Niri Workspaces" to `Embers-of-the-Fire/dank-niri-workspaces`, an unrelated
launcher plugin, which forced a rename late in the process. Cheapest possible
check, and it invalidates a lot of downstream work if skipped:

```
python3 -c "import json,glob; print([json.load(open(f))['id'] for f in glob.glob('plugins/*.json')])" | grep -i <candidate>
```

**Run both validators locally.** They catch everything CI does:

```
uv run --with jinja2 --with requests --with pillow python3 .github/generate.py --validate
```

`generate.py` checks schema, required fields and uniqueness. `validate_links.py`
checks URLs and that `id`/`name` match the live `plugin.json` on the default
branch — it filters by git-changed files, so call `validate_plugin(Path(...))`
directly rather than running its `main()` in a scratch clone.

**Consequences of the fetch-from-live-repo check:** the plugin repo must be
pushed *before* the registry PR, or validation 404s. It also means `screenshot`
has to be an absolute reachable URL (`raw.githubusercontent.com/.../main/...`),
never a repo-relative path, and that swapping that file later updates the
registry's preview card with no second PR.

**Undocumented but accepted:** `requires_dms`. **Documented but not enforced:**
`category` is free-form, not an enum — the live registry carries both `Network`
and `Networking`.

**First-time contributors wait on a human.** `validate-pr.yml` runs on
`pull_request` and lands in `action_required` until a maintainer approves it;
`plugin-preview.yml` runs on `pull_request_target` and executes immediately.
A PR showing only the preview check is normal, not broken.

**Custom registries are the fallback.** DMS 1.6.0 (`apiVersion >= 29`) lets a
user add any git repo with a `plugins/` directory as a source, using the
identical JSON format. If a submission ever stalls, this repo can host its own
registry and the entry is reusable verbatim.
