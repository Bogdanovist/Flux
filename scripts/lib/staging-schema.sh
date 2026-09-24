#!/usr/bin/env bash
# staging-schema.sh — schema validator + content blocklist for lesson
# entries flowing from emission-site skills into learnings/staging.md.
#
# This file is sourced (not executed) by:
#   - skills/learn/               (gates the /learn slash command's
#                                  write of a pending entry)
#   - the weekly curation ritual  (gates whether a pending entry is
#                                  drained into staging.md)
#
# Two functions are exported:
#
#   validate_staging_entry <path>
#     Runs the full schema check followed by the content blocklist.
#     Exit codes:
#       0  PASS
#       1  schema failure  (missing/malformed required field)
#       2  blocklist hit   (banned phrase in proposed-text body)
#     All diagnostic messages go to stderr.
#
#   check_blocklist <path>
#     Runs only the content-blocklist scan on the proposed-text body.
#     Same 0/2 contract as above. Useful when a caller has already
#     validated structure and only needs the content gate.
#
# Required front-matter fields (between two `---` fences):
#   uuid           — RFC 4122 v4 UUID (the de-dup key; auto-generated)
#   timestamp      — ISO 8601 (not currently parsed beyond presence)
#   proposed-text  — block scalar (`|`) followed by indented body. This
#                    is the lesson itself.
#
# Optional advisory fields (accepted but NOT validated — filing a lesson
# must be quick, and the curator clusters by theme and re-homes anyway,
# so these are hints, not gates):
#   target         — a *suggested* destination file. Captured-but-wrong
#                    targets were the dominant filing friction (agents
#                    invented plausible paths that nothing reads), so the
#                    filing validator no longer checks its shape. The
#                    per-repo shape contract still lives in
#                    `target_shape_valid` below, which the curator's
#                    edit-path guard enforces against the destination
#                    the curator actually picks at promote time —
#                    independent of whatever (if anything) the lesson
#                    suggested.
#   scope          — a hint at the patch verb (add | modify | remove);
#                    advisory, not enum-checked.
#   rationale      — single-line free text; the "why".
#
# Body blocklist (case-insensitive, word-boundary):
#
#   Operational footguns — advice that would weaken the
#   verification discipline if it ever reached an evergreen rules
#   file:
#     --no-verify, force push, skip tests, ignore failing tests,
#     always override, disable tests
#
#   Prompt-injection patterns — phrasings whose only purpose is to
#   redirect a downstream agent that loads the rules file:
#     ignore (prior|previous|above|all|earlier|the) instructions
#     disregard (prior|previous|above|all|earlier|the) instructions
#     forget (prior|previous|above|all|earlier|the) instructions
#     </system>, <system>, </instructions>, <instructions>
#
#   Patterns are phrase-level (not bare verbs) so that legitimate
#   discipline-strengthening lessons like "Never ignore type
#   errors" or "Disable assertions in hot loops only with review"
#   are not falsely rejected.

# Guard against double-sourcing wiping caller state.
if [ "${_STAGING_SCHEMA_SOURCED:-}" = "1" ]; then
  return 0 2>/dev/null || true
fi
_STAGING_SCHEMA_SOURCED=1

# Banned phrases. Each is matched with grep -iE against the extracted
# proposed-text body. Operational-footgun patterns use -w (word
# boundary); prompt-injection patterns use phrase-style matching where
# word-boundary doesn't compose with `</...>` punctuation. Order is
# documentation-only.
_STAGING_BLOCKLIST_PATTERNS=(
  '\-\-no-verify'
  'force push'
  'skip tests'
  'ignore failing tests'
  'always override'
  'disable tests'
  'ignore (prior|previous|above|all|earlier|the) instructions?'
  'disregard (prior|previous|above|all|earlier|the) instructions?'
  'forget (prior|previous|above|all|earlier|the) instructions?'
  '</?system>'
  '</?instructions>'
)

# Root holding the project checkouts a lesson can be routed into. A
# repo is curatable when it has a checkout here, which is also the only
# state in which the curator can read the text it proposes to change.
_STAGING_SRC_ROOT="${FLUX_SRC_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"

# Emit a message to stderr prefixed with the function-under-test name
# so failures in test harnesses are easy to trace.
_schema_err() {
  printf 'staging-schema: %s\n' "$*" >&2
}

# Public: validate a (repo, rest-of-path) tuple against the per-repo
# target-shape contract. Used by assert-curator-edit-allowed.sh for the
# curator's edit-path guard — it gates the destination the curator
# actually picks at promote time. (It is intentionally NOT called by the
# lesson-filing validator: a captured `target:` is an advisory hint, not
# a gate.) Returns 0 on shape PASS, 1 on shape FAIL (with message on
# stderr). An unknown repo always FAILs.
#
# Adding a shape: edit the case statement here only.
target_shape_valid() {
  local repo="$1" rest="$2"
  case "$repo" in
    flux)
      if ! printf '%s' "$rest" | grep -Eq '^(AGENTS\.md|CLAUDE\.md|\.claude/.+\.md|agents/[^/]+\.md|skills/[^/]+/SKILL\.md|model-profiles\.toml)$'; then
        _schema_err "target shape invalid for flux (expect AGENTS.md, CLAUDE.md, .claude/<path>.md, agents/<name>.md, skills/<skill>/SKILL.md, or model-profiles.toml): ${repo}/${rest}"
        return 1
      fi
      ;;
    *)
      if [ ! -d "${_STAGING_SRC_ROOT}/${repo}" ]; then
        _schema_err "target names a repo with no checkout under ${_STAGING_SRC_ROOT}: ${repo}"
        return 1
      fi
      if ! printf '%s' "$rest" | grep -Eq '^(AGENTS\.md|CLAUDE\.md|\.claude/.+\.md)$'; then
        _schema_err "target shape invalid for ${repo} (expect AGENTS.md, CLAUDE.md, or .claude/<path>.md): ${repo}/${rest}"
        return 1
      fi
      ;;
  esac
  return 0
}

# Return 0 if the front-matter contains a top-level key matching the
# regex /^<key>:/. Caller passes the entry path and the key name.
_has_top_level_key() {
  local path="$1" key="$2"
  grep -Eq "^${key}:" "$path"
}

# Extract the value following `^<key>:` (stripped of surrounding
# whitespace). Prints empty string if key absent.
_get_value() {
  local path="$1" key="$2"
  # awk because sed handling of trailing CR varies between BSD/GNU.
  awk -v k="$key" '
    $0 ~ "^" k ":" {
      sub("^" k ":[[:space:]]*", "");
      sub("[[:space:]]+$", "");
      print;
      exit;
    }
  ' "$path"
}

# Extract the indented body following `proposed-text: |`. Returns
# empty string if the block is missing or empty. The block ends at
# the first non-indented, non-blank line OR at the closing `---`.
_get_proposed_text_body() {
  local path="$1"
  awk '
    /^proposed-text:[[:space:]]*\|[[:space:]]*$/ { in_block = 1; next }
    in_block {
      # Closing front-matter fence ends the block.
      if ($0 == "---") { exit }
      # A line that is neither blank nor indented ends the block.
      if ($0 !~ /^[[:space:]]+/ && $0 !~ /^[[:space:]]*$/) { exit }
      # Strip leading indentation for matching purposes.
      sub(/^[[:space:]]+/, "");
      print;
    }
  ' "$path"
}

# Validate that the front-matter declares every required key with a
# non-empty value and that uuid is RFC 4122 v4 shaped.
# Returns 0 on success, 1 on any failure (with message on stderr).
_validate_schema() {
  local path="$1"

  if [ ! -s "$path" ]; then
    _schema_err "entry is empty or missing: $path"
    return 1
  fi

  # Front-matter must start with `---` on line 1.
  if [ "$(head -n 1 "$path")" != "---" ]; then
    _schema_err "missing opening front-matter fence (---)"
    return 1
  fi

  local key
  for key in uuid timestamp; do
    if ! _has_top_level_key "$path" "$key"; then
      _schema_err "missing required field: $key"
      return 1
    fi
    local val
    val="$(_get_value "$path" "$key")"
    if [ -z "$val" ]; then
      _schema_err "field $key is present but empty"
      return 1
    fi
  done

  # proposed-text uses a block scalar, so the value-on-same-line check
  # above doesn't apply; check the indented body instead.
  if ! grep -Eq '^proposed-text:[[:space:]]*\|[[:space:]]*$' "$path"; then
    _schema_err "missing required field: proposed-text (must use '|' block scalar)"
    return 1
  fi
  local body
  body="$(_get_proposed_text_body "$path")"
  if [ -z "$body" ]; then
    _schema_err "field proposed-text is present but body is empty"
    return 1
  fi

  # scope, target, and rationale are advisory hints — accepted but not
  # validated, so hand-filing a lesson stays quick and a captured-but-
  # wrong target never blocks the entry. The curator re-homes by theme
  # regardless, and its edit-path guard re-checks the destination it
  # actually picks via target_shape_valid().

  # UUID v4 shape: 8-4-4-4-12 lowercase hex, version nibble = 4,
  # variant nibble in {8,9,a,b}.
  local uuid
  uuid="$(_get_value "$path" "uuid")"
  if ! printf '%s' "$uuid" | grep -Eq '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'; then
    _schema_err "field uuid is not a valid RFC 4122 v4 UUID: $uuid"
    return 1
  fi

  return 0
}

# Public: run only the body blocklist. Exit 0 PASS, 2 hit.
check_blocklist() {
  local path="$1"
  local body
  body="$(_get_proposed_text_body "$path")"
  if [ -z "$body" ]; then
    # No body means no blocklist surface — defer to the schema layer
    # to fail the entry instead of double-reporting here.
    return 0
  fi
  local pattern
  for pattern in "${_STAGING_BLOCKLIST_PATTERNS[@]}"; do
    if printf '%s\n' "$body" | grep -iEqw -- "$pattern"; then
      _schema_err "blocklist hit in proposed-text body: $pattern"
      return 2
    fi
  done
  return 0
}

# Public: full gate — schema, then blocklist. Distinct exit codes so
# the drain hook can route rejected entries to the .rejected/ tree
# with a reason header that names which gate fired.
validate_staging_entry() {
  local path="$1"
  if ! _validate_schema "$path"; then
    return 1
  fi
  if ! check_blocklist "$path"; then
    return 2
  fi
  return 0
}
