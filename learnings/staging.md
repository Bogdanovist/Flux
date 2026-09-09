# staging.md

Drained, validated lesson entries awaiting curation. `hooks/drain-to-staging.sh`
appends `pending/` here at session end, and `/curate` reads the entries, then
truncates this file back to this header once every entry has a disposition.

Entries appear below, each opening with a `---` fence. The schema they satisfy
is `scripts/lib/staging-schema.sh`.
