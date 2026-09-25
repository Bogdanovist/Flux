#!/usr/bin/env bash
# merge-settings.sh — merge Flux's settings into the user's settings file.
#
# Claude Code reads one user-level settings file, settings.json in the config
# dir; a settings.local.json there applies only to sessions started in that
# dir. So the user file is the person's own, and Flux merges into it: the
# tracked settings.json, then this machine's gitignored settings.local.json.
#
# - Hooks, env keys and permission list entries belong to the sources. Each
#   merge removes what the previous merge added, then adds the sources'
#   current set, so an entry dropped from a source leaves the user file too.
#   flux-merged.json, beside the user file, records what the last merge added.
# - The sandbox key belongs to the sources whole, because it is a security
#   boundary that must follow the tracked file both ways. The sources merge
#   in order: objects merge by key, lists join, and a later scalar wins.
# - Every other key, such as model, theme or permissions.defaultMode, is set
#   only where the file has none, because the app writes preferences into
#   the same file.
#
# The user file is written, after a timestamped backup, only when the merge
# changes it; the script then prints "merged". Called by setup.sh and, at
# every session start, by hooks/flux-sync.sh.
#
# Usage: merge-settings.sh <user-settings.json>
# Environment: FLUX_DIR  root of the Flux checkout (default: this script's repo)
#
# Exit codes: 0 merged or unchanged, 1 the user file is a link or not JSON.

set -uo pipefail

FLUX="${FLUX_DIR:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
USER_SETTINGS="${1:?usage: merge-settings.sh <user-settings.json>}"

# A checkout with no tracked settings has nothing to merge.
[ -f "$FLUX/settings.json" ] || exit 0

python3 - "$USER_SETTINGS" "$FLUX/settings.json" "$FLUX/settings.local.json" <<'PY'
import json, os, shutil, sys, time

user_path, *frag_paths = sys.argv[1:]
frags = [json.load(open(p)) for p in frag_paths if os.path.exists(p)]
record_path = os.path.join(os.path.dirname(user_path), "flux-merged.json")

user = {}
if os.path.lexists(user_path):
    if os.path.islink(user_path):
        sys.exit(f"{user_path} is a link into another config repo; remove it by hand first.")
    user = json.load(open(user_path))
before = json.dumps(user, indent=2) + "\n"
if os.path.exists(record_path):
    last = json.load(open(record_path))
else:
    # No record: the file may hold an earlier merge, so whatever the sources
    # list now counts as theirs.
    last = {"hooks": [h["command"] for f in frags for gs in f.get("hooks", {}).values()
                      for g in gs for h in g.get("hooks", [])],
            "env": [k for f in frags for k in f.get("env", {})],
            "permissions": {},
            "sandbox": any("sandbox" in f for f in frags)}
    for f in frags:
        for key, value in f.get("permissions", {}).items():
            if isinstance(value, list):
                last["permissions"].setdefault(key, []).extend(value)

# Remove what the last merge added.
hooks = user.setdefault("hooks", {})
old_hooks = set(last.get("hooks", []))
for groups in hooks.values():
    for g in groups:
        g["hooks"] = [h for h in g.get("hooks", []) if h.get("command") not in old_hooks]
    groups[:] = [g for g in groups if g.get("hooks")]
env = user.setdefault("env", {})
for key in last.get("env", []):
    env.pop(key, None)
perms = user.setdefault("permissions", {})
for key, entries in last.get("permissions", {}).items():
    if isinstance(perms.get(key), list):
        perms[key] = [e for e in perms[key] if e not in entries]
if last.get("sandbox"):
    user.pop("sandbox", None)

def deep_merge(base, extra):
    for key, value in extra.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            deep_merge(base[key], value)
        elif isinstance(value, list) and isinstance(base.get(key), list):
            base[key] += [v for v in value if v not in base[key]]
        else:
            base[key] = json.loads(json.dumps(value))
    return base

# Add the sources' current set, and record it.
record = {"hooks": [], "env": [], "permissions": {},
          "sandbox": any("sandbox" in f for f in frags)}
if record["sandbox"]:
    user["sandbox"] = {}
    for frag in frags:
        deep_merge(user["sandbox"], frag.get("sandbox", {}))
for frag in frags:
    for event, groups in frag.get("hooks", {}).items():
        hooks.setdefault(event, []).extend(groups)
        record["hooks"] += [h["command"] for g in groups for h in g.get("hooks", [])]
    env.update(frag.get("env", {}))
    record["env"] += list(frag.get("env", {}))
    for key, value in frag.get("permissions", {}).items():
        if isinstance(value, list):
            have = perms.setdefault(key, [])
            added = [v for v in value if v not in have]
            have.extend(added)
            record["permissions"].setdefault(key, []).extend(added)
        else:
            perms.setdefault(key, value)
    for key, value in frag.items():
        if key not in ("hooks", "env", "permissions", "sandbox", "$schema"):
            user.setdefault(key, value)
user["hooks"] = {k: v for k, v in hooks.items() if v}

after = json.dumps(user, indent=2) + "\n"
with open(record_path, "w") as f:
    json.dump(record, f, indent=2)
    f.write("\n")
if after == before:
    sys.exit(0)
if os.path.exists(user_path):
    shutil.copy2(user_path, f"{user_path}.bak.{time.strftime('%Y%m%d-%H%M%S')}")
with open(user_path, "w") as f:
    f.write(after)
print("merged")
PY
