---
name: verification-before-completion
description: >
  Evidence-before-claims discipline for implementation completion. Use before
  claiming any work is complete, fixed, or passing. Run verification commands
  and confirm output before making success claims.
---

# Verification before completion

**Never claim something is complete until you have fresh verification evidence.**

Back every claim with evidence you just observed. Evidence from earlier in the
session does not count. Evidence you expect the command to produce does not
count. Use what you just saw.

## The five-step gate

Complete these steps before you make any completion claim.

### Step 1: Identify

What command proves your claim — and what would that command return if the claim were false?

```text
Claim: "Tests pass"
Command: npm test (or project's test command)

Claim: "Build succeeds"
Command: npm run build (or project's build command)

Claim: "Lint is clean"
Command: npm run lint (or project's lint command)

Claim: "Bug is fixed"
Command: The reproduction steps that previously failed
```

If you cannot name the failing result, the check does not discriminate and a clean
output means nothing. Three ways a check comes back clean while the claim is wrong:

**You took the denominator from one side of a partition.** State the figure against the
whole set, and name what you did not examine: "25 entries with `not_null: true` verified;
11 with `not_null: false` not examined". If a check cannot name its exclusions, it is not
a coverage check. Report "25/25, no gaps" from one side and you have written a report
that certifies the failure it was meant to catch.

**Your probe's setup does not represent the real thing.** Report the conditions beside
the figure: the source shape and row count, the bound range against the data's actual
range, and how long the table has existed. Sanity-check the magnitude first. If a cost
implies the query read nothing, and the table holds multiple gigabytes, treat that as a
setup error until you prove otherwise. Two runs that share one flawed setup do not
corroborate each other.

**An affirmative or empty result answered a weaker question than you asked.** A search
that returns nothing proves absence only when the search works and its scope covers where
the thing would be. "Does an alternative exist?" is a different question from "does the
alternative carry what this one lacks?". Follow the lineage, because the existence test
passes on a derived and lossier copy.

### Step 2: Run it

Execute the command freshly. Do not use a cached result, and do not recall an
earlier one.

```text
Run the command NOW.
Wait for it to complete.
Do not proceed until finished.
```

### Step 3: Read the output

Read all of it.

```text
- Exit code (0 = success)
- All output lines, not just the last one
- Any warnings (not just errors)
- Summary statistics if provided
```

### Step 4: Verify

Confirm that the output supports your claim.

```text
Claim: "Tests pass"
Verify: Exit code 0, "X tests passed", no failures

Claim: "Build succeeds"
Verify: Exit code 0, output files created, no errors

Claim: "Bug is fixed"
Verify: Previous failure no longer occurs
```

### Step 5: Claim

Only NOW make your completion claim.

```text
"Tests pass" - after seeing test output showing success
"Build succeeds" - after seeing build complete without errors
"Implementation complete" - after all verifications pass
```

## Rationalization Red Flags

| Thought | Reality |
|---------|---------|
| "It should pass" | Run it and see |
| "I'm confident it works" | Confidence isn't evidence |
| "I already ran it earlier" | Run it again, freshly |
| "The change was small" | Small changes can break things |
| "I'll verify later" | Verify now or don't claim |
| "The agent said it passed" | Verify agent's claims independently |
| "It worked on my machine" | Run it in the target environment |
| "I'm tired of running tests" | Fatigue doesn't excuse skipping verification |

## Integration with Implement Phase

This skill serves as the final gate before completion claims:

```text
Plan step complete? → Run step verification → Claim step done
Phase complete? → Run phase verification → Claim phase done
Implementation complete? → Run all verifications → Claim done
```

**Never mark a step complete without verification evidence.**

## Anti-Patterns

### Partial Verification

**Wrong**: Run only the test file you changed
**Right**: Run full test suite to catch regressions

### Cached Results

**Wrong**: Trust previous run results
**Right**: Run fresh each time before claiming

### Skipping on Confidence

**Wrong**: "I know this works, no need to verify"
**Right**: Verify anyway, confidence isn't evidence

### Trusting Agent Claims

**Wrong**: Agent said tests pass, so they pass
**Right**: Run tests yourself to verify

### Rushing at End

**Wrong**: Skip verification because you're almost done
**Right**: Final verification is most important

## Checklist Before Completion

- [ ] Identified verification command for the claim
- [ ] Ran command freshly (not cached)
- [ ] Read complete output
- [ ] Exit code confirms success
- [ ] Output matches expectations
- [ ] No warnings or errors ignored
- [ ] Evidence supports the specific claim being made
