# Flux

@AGENTS.md

Claude Code reads `CLAUDE.md`, never `AGENTS.md`; this file exists to import
the charter and stays a thin wrapper. Provider-agnostic rules belong in
`AGENTS.md`.

Claude-specific loading notes:

- Auto memory is off. Durable context goes to the stores in `AGENTS.md`
  §Where context lives, under version control.
- `setup.sh` links this file, `AGENTS.md`, `hooks/` and `agents/` into the
  Claude config dir, and links each `skills/<name>/` into its `skills/`. Edit
  the tracked file, never the installed link.
- The config dir's `settings.json` belongs to the person. `setup.sh` merges
  the tracked `settings.json` and the machine's `settings.local.json` into
  it, so a change to either takes effect after `setup.sh` runs again.
- Where a recurrence must invoke Claude Code directly, use `claude -p`.
