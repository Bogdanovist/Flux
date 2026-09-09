#!/usr/bin/env bash
# git-sync.sh — "is this checkout behind its remote?", answered against the
# remote rather than against a local ref that may be days old.
#
# This file is sourced (not executed) by:
#   - hooks/flux-sync.sh       (SessionStart: fast-forward the checkout
#                                 before the session reads anything from it)
#   - hooks/auto-commit-push.sh  (Stop: push local commits only once their
#                                 standing against origin is known)
#
# The two hooks ask the same question at opposite ends of a session. A
# checkout that answered "behind" to one and "up to date" to the other would
# push precisely the divergence the pair exists to prevent, so the
# definition lives here once instead of twice.
#
# Three functions are exported:
#
#   find_live_agent_sock
#       Echo the path of an SSH agent socket that answers and holds a key.
#       Returns non-zero when none does.
#
#   bounded_fetch <repo> [remote] [secs]
#       Refresh remote-tracking refs, bounded so a hung network cannot stall
#       a session boundary. Returns 0 only on a completed fetch.
#
#       A non-zero return means the caller does NOT know where it stands.
#       Callers must treat that as "cannot verify" and act conservatively —
#       never as "up to date". Skipping the fetch entirely would make the
#       whole check undiscriminating: a checkout weeks adrift reports
#       "not behind" off its own stale origin ref, which is exactly how the
#       divergence goes unnoticed long enough to become expensive.
#
#   ahead_behind <repo>
#       Echo "<ahead> <behind>" for the current branch against its upstream.
#       Returns non-zero when there is no upstream to compare against.
#
# Environment (overridable for testing):
#   FLUX_AGENT_SOCK_GLOB   where to look for a live SSH agent socket
#                            (default /tmp/ssh-*/agent.*). A test seam: without
#                            it the probe reads whatever sockets happen to exist
#                            on the machine running the tests.

# Echo the path of an SSH agent socket that answers and holds an identity.
#
# Sockets belonging to other users on a shared box are not readable, so the
# probe skips them rather than adopting them. An agent that answers but holds no
# key cannot authenticate, so it does not count as live.
find_live_agent_sock() {
  command -v ssh-add >/dev/null 2>&1 || return 1

  local sock
  for sock in ${FLUX_AGENT_SOCK_GLOB:-/tmp/ssh-*/agent.*}; do
    [ -S "$sock" ] || continue
    if SSH_AUTH_SOCK="$sock" ssh-add -l >/dev/null 2>&1; then
      printf '%s\n' "$sock"
      return 0
    fi
  done
  return 1
}

# Adopt a live SSH agent socket when the inherited one is dead.
#
# A forwarded SSH agent is per-SSH-session. A tmux pane or agent session that
# outlives the connection which spawned it keeps exporting a socket path that no
# longer exists, and every fetch then fails with "Permission denied (publickey)"
# — indistinguishable from genuinely missing access. Because both callers fail
# closed on a failed fetch, that one stale variable would otherwise switch the
# whole sync-and-guard mechanism off for the life of the pane, on exactly the
# box it was built for.
#
# Deliberately narrow. It acts only when the inherited socket does not answer,
# and only for a remote that authenticates through the agent at all — so a
# healthy session and an https or local-path remote are untouched.
repair_ssh_agent() {
  local url="$1"

  # Only SSH transports consult the agent.
  case "$url" in
    ssh://*|*@*:*) ;;
    *) return 0 ;;
  esac

  command -v ssh-add >/dev/null 2>&1 || return 0

  # rc 0 means the agent answered AND holds identities. A socket that is merely
  # reachable but empty cannot authenticate, so it is treated as dead too.
  ssh-add -l >/dev/null 2>&1 && return 0

  local sock
  sock=$(find_live_agent_sock) && export SSH_AUTH_SOCK="$sock"
  return 0
}

# Refresh remote-tracking refs for <repo> under a time bound.
bounded_fetch() {
  local repo="$1"
  local remote="${2:-origin}"
  local secs="${3:-10}"

  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1

  local url
  url=$(git -C "$repo" remote get-url "$remote" 2>/dev/null) || return 1
  [ -n "$url" ] || return 1
  repair_ssh_agent "$url"

  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" git -C "$repo" fetch "$remote" --quiet >/dev/null 2>&1
    return $?
  fi
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" git -C "$repo" fetch "$remote" --quiet >/dev/null 2>&1
    return $?
  fi

  # macOS ships no timeout(1). Run the fetch in the background and reap it
  # with a watchdog, so a stalled connection still releases the hook.
  git -C "$repo" fetch "$remote" --quiet >/dev/null 2>&1 &
  local fetch_pid=$!

  # The watchdog gets its own stdio. Callers read this function's output through
  # a pipe or command substitution, and a reader waits for every writer to close
  # the descriptor — not for the process it cares about to exit. A watchdog still
  # holding stdout therefore charges the caller the full timeout for a fetch that
  # returned in seconds, which is the entire cost this bound exists to avoid.
  ( sleep "$secs"; kill -TERM "$fetch_pid" 2>/dev/null ) >/dev/null 2>&1 <&- &
  local watchdog_pid=$!
  disown "$watchdog_pid" 2>/dev/null || true

  local rc=0
  wait "$fetch_pid" 2>/dev/null || rc=$?

  # Reap the sleep as well as the subshell around it. An orphan outlives the call
  # and fires its TERM at a pid the kernel may have reassigned by then.
  pkill -P "$watchdog_pid" 2>/dev/null || true
  kill "$watchdog_pid" 2>/dev/null || true
  return $rc
}

# Echo "<ahead> <behind>" against the current branch's upstream.
ahead_behind() {
  local repo="$1"
  local counts
  # `--left-right --count A...B` prints "<in A not B>\t<in B not A>", so with
  # A=upstream and B=HEAD the left column is behind and the right is ahead.
  counts=$(git -C "$repo" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null) || return 1
  [ -n "$counts" ] || return 1

  local behind ahead
  behind=$(printf '%s' "$counts" | awk '{print $1}')
  ahead=$(printf '%s' "$counts" | awk '{print $2}')
  [ -n "$behind" ] && [ -n "$ahead" ] || return 1

  # Reported ahead-first, in the order the callers say them.
  printf '%s %s\n' "$ahead" "$behind"
}
