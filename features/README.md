# features/

The durable layer for context that outlives any one project: one directory per
feature that spans repos, carrying `index.md` (what the feature is, in a
glossary a rule can point at) and its `decisions/` and `facts/` records.

Reach for this last. `records` gives the bar: if a rename, a code comment or a
rule in the repo itself can carry the fact, put it there and write nothing
here. A feature record taxes every future pass, because each design that cites
it has to verify it first.
