---
name: gathering-runtime-evidence-services
description: >
  First-look runtime evidence for live services — recent logs (tail or
  grep, structured-log inspection of one real request), endpoint
  responses with representative payloads, health and metrics endpoints,
  error-rate sanity. Use any time a claim about request flow, error
  shape, latency, or feature-flag state would otherwise rest on
  code-reading alone. Tags evidence `[OBSERVED]`; pairs with
  `followup` when stale routes, broken health checks, or
  noisy log lines surface.
user-invocable: true
---

# Gathering Runtime Evidence — Services

Reading the code tells you which path a request *can* take. The running service tells you which path it *does* take. Before you write or refine a doc that makes claims about request handling, error rates, latency, deployed config or feature-flag state, hit the running service, then tag the result.

This skill exists to stop three failures. You write a fix for code that is not executing the path you think it is. You debug an error class that never appears in the production logs. You assume a middleware runs first when it runs last.

## When to invoke

- A grilling question is "what does the response actually look like?" / "is this error class hitting prod?" / "is this flag on?".
- An architecture or solution-design doc names a service and a behaviour — confirm the behaviour by exercising the service.
- A tracer touches request handling. Read one real request's structured log, and confirm the path you assumed actually executes.
- You are investigating a bug. Look at the real logs and the real response before you form a hypothesis, so that `systematic-debugging` proceeds on evidence and not on imagination.

Skip this skill when you cannot reach the service from the current environment, when the question is purely static, such as whether a function compiles or type-checks, or when the behaviour you are asking about does not exist yet.

## First-look commands

Pick the smallest one that answers the question. All read-only.

| Question | First-look |
|---|---|
| Is the service up; what version is deployed? | `curl -sf {base}/health` (or `/readyz`, `/_status` — whichever the service exposes); `gcloud run revisions list --service {name}`. |
| What does the endpoint actually return for a real payload? | `curl -i -X POST {base}/path -H 'content-type: application/json' -d '{...}'`. Look at status, headers, body. |
| Is this error class hitting prod? | `gcloud logging read 'resource.type="cloud_run_revision" AND severity>=ERROR AND textPayload:"{pattern}"' --limit 50 --freshness 1d` (substitute the equivalent for the platform). |
| What does one real request's structured log look like, end to end? | Find a trace id from a recent error log, then `gcloud logging read 'trace="{trace-id}"' --limit 200 --format=json` and read the full chain. |
| Is feature flag X currently on for cohort Y? | The flag provider's CLI / API, or an admin endpoint if one exists. |
| What's the request rate / error rate right now? | The metrics dashboard (Cloud Monitoring, Datadog, Grafana — paste the URL into the artefact), or a metric endpoint like `/metrics`. |
| Locally — does the service start and respond? | Run it; hit it with `curl`; check the local logs. |

The table's commands are examples from one platform. Substitute the equivalents your service actually runs on — `fly logs`, `docker logs`, `journalctl`, `kubectl logs`, a hosting dashboard's log view — and keep the questions.

## Read-only and safe

- `GET` and idempotent `POST` to health/preview endpoints are fine. Anything that mutates production state (creates resources, sends real notifications, charges a card) is not first-look evidence — confirm with the user before exercising it.
- Use a known test account or sandbox cohort when you have to send a non-trivial request. Never use a real customer identifier unless the user explicitly directs it.
- Log queries are read-only by nature; still keep the `--limit` and `--freshness` tight so you actually look at the result rather than skim 10k lines.

## Tagging the result

Findings from a command actually run in this session are tagged `[OBSERVED]`. Findings inferred from code, config, or a deployment manifest without exercising the service are tagged `[INFERRED]`. Tag inline next to the claim.

When observation contradicts a written claim, fix the claim. Service behaviour is the authority; the code is hypothesis.

## Surfacing incidentals

The logs will routinely surface unrelated noise: a deprecated route still being hit, a structured-log field that has been blank since a refactor, a health check that returns 200 while the service is actually broken. Hand each to `followup` with the relevant log line, response body, or `gcloud` output as evidence. Default `[FLAG-HUMAN]` — production services are exactly the place where "looks wrong" is most often subtle correctness.

## Anti-patterns

| Wrong | Right |
|---|---|
| Reasoning about an error class from the `raise` site without checking logs | Query logs for that error class; observe the actual rate and surrounding context. |
| Sending real notifications / charges from "exploratory" calls | Use sandbox / test cohorts; confirm with the user before touching real-state endpoints. |
| `gcloud logging read` with no freshness or limit, then skim 50k lines | Tight `--limit` and `--freshness`; if you need a wider window, narrow the query instead. |
| Quoting one log line as proof of a class of errors | One line is one event. Aggregate (count, group, time-bucket) before claiming "this is rare / common". |
| Untagged claims mixing observed and inferred behaviour | Tag each claim. Readers cannot otherwise tell which to trust. |
| Pasting a customer email or auth token into the doc | Redact. The doc is checked in. |

## Composition

Composes `followup` when log or response inspection surfaces broken windows. Composed by `solution-design`, `to-tracers`, `implementer`, and `systematic-debugging` whenever request-flow, error-shape, or deployed-state claims need grounding.
