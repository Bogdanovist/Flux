# projects/

One directory per piece of work that runs longer than a session:
`projects/<slug>/plan.md`, plus whatever the work accumulates — decision and
fact records, review notes, handoffs.

`open-project` creates the directory and writes the header contract.
`close-project` works the promotion gate at the end and archives the directory
under `projects/archive/<slug>/`.

Every edit to a doc here commits straight to `main`, so the plan your other
machines read is the plan you are working from. A doc that has stopped moving
is what `context-sweep` looks at when it judges a project dormant.
