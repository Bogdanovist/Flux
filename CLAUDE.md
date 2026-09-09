# Flux

@AGENTS.md

Claude Code reads `CLAUDE.md`, never `AGENTS.md`; this file exists to import
the charter and stays a thin wrapper. Provider-agnostic rules belong in
`AGENTS.md`.

Claude-specific loading notes:

- Auto memory is off. Durable context goes to the stores in `AGENTS.md`
  §Where context lives, under version control.
- `setup.sh` links this file, `AGENTS.md`, `settings.json`, `hooks/` and
  `agents/` into the Claude config dir, and links each `skills/<name>/` into
  its `skills/`. Edit the tracked file, never the installed link.
- Where a recurrence must invoke Claude Code directly, use `claude -p`.
