#!/usr/bin/env bash
# run_reviewers.sh — run codex, antigravity, gemini-pro, kimi, and/or glm in parallel against the current diff.
#
# Gemini-family reviewers (both via Google's `agy` Antigravity CLI as of the
# 2026-06-18 Gemini-CLI consumer sunset):
#   antigravity — `agy --model "Gemini 3.5 Flash (High)"`. Fast lap. Replaces the
#                 retired `gemini` (Gemini CLI Flash) reviewer slot.
#   gemini-pro  — `agy --model "Gemini 3.1 Pro (High)"`. Deep lap, slower. Was
#                 previously the standalone `gemini` CLI on gemini-3.1-pro-preview;
#                 migrated to agy because the gemini CLI stopped serving consumer
#                 requests on 2026-06-18 and agy now hosts Gemini 3.1 Pro + --model.
#   Install agy: `curl -fsSL https://antigravity.google/cli/install.sh | bash`
#                (lands at ~/.local/bin/agy). Auth: `agy login` once interactively.
#
# OpenRouter lane (rotating single-turn reviewers — NO fallbacks):
#   glm (Zhipu), deepseek (DeepSeek), mimo (Xiaomi), minimax (MiniMax),
#   qwen (Alibaba), devstral (Mistral), laguna (Poolside), kat (Kuaishou),
#   north (Cohere, free), nemotron (NVIDIA, free), spark (Meta),
#   seed (ByteDance), grok (xAI).
#   Model IDs are DELIBERATELY not repeated here — see the note above
#   `model_backed_reviewers` below: they live only in reviewer_profiles.json,
#   because a slug list in a comment rots silently and misleads whoever comes
#   to fix a rename. (It did: this block still named the delisted
#   `mistralai/devstral-2512` and `poolside/laguna-m.1` months after the
#   profile moved off them — caught by kat+grok, cross-review PR #55.)
#   All are single-turn diff-inline reviews (same niche as kimi), each an
#   independent provider vote. Key resolution: $OPENROUTER_API_KEY env var,
#   else ~/.config/openrouter/key. No key → all thirteen are skipped.
#
#   POLICY (2026-07-01, per Gabriel): first-party reviewers (codex, the agy
#   Gemini laps, kimi) do NOT fall back to OpenRouter — when agy hits its
#   shared "Individual quota" (observed: exits 0 with empty stdout in ~5s and
#   only the .agy.log says RESOURCE_EXHAUSTED), the lap fails HONESTLY with
#   failure_kind=quota_exhausted and drops out of the round. Roster rotation
#   (select_roster.sh) compensates by drawing other providers.
#
#   Typical rounds run codex + kimi (fixed baselines) plus 2 rotation picks —
#   see select_roster.sh, which weights picks by the leaderboard.sh score.
#
# GOTCHA: `agy --model` takes the EXACT display-name string `agy models` prints
# (e.g. "Gemini 3.1 Pro (High)"). On an unrecognized string agy does NOT error —
# it silently falls back to its default (Gemini 3.5 Flash). So a typo here turns
# the "deep lap" into a second Flash run with no warning. Keep the model strings
# below in sync with `agy models`.
#
# Usage:
#   run_reviewers.sh --base <branch> --out <dir>
#                    [--reviewers codex,antigravity,gemini-pro,kimi,glm,deepseek,mimo,minimax,qwen,devstral,laguna,kat,north,nemotron,spark,seed,grok]
#                    [--timeout <sec>]
#                    [--timeout-codex <sec>] [--timeout-antigravity <sec>]
#                    [--timeout-gemini-pro <sec>] [--timeout-kimi <sec>]
#                    [--timeout-glm <sec>]
#                    [--snapshot-dir <dir>]
#
# No --reviewers → select_roster.sh chooses the round's roster (codex + kimi
# baselines, ≥3 total, leaderboard-weighted rotation picks). Explicit
# --reviewers bypasses rotation entirely.
#
# Per-reviewer timeouts override the global --timeout. Codex tends to either
# return fast or fail fast; antigravity/gemini-pro/kimi do deep reasoning and
# need more headroom. Default policy: codex=300, antigravity=600, gemini-pro=900,
# kimi=600. The previous 300s blanket cap truncated dense-logic diffs
# (see PR #1985 postmortem).
#
# --snapshot-dir <dir>: for each dispatched reviewer <r> that builds its own
# text prompt (kimi, the OpenRouter pool, and the two agy laps), if
# <dir>/snapshot-<r>.md, .xml, or .txt exists (first match wins, in that
# order), that reviewer's code-context block uses the snapshot file's
# contents INSTEAD OF the raw git diff — no 8000-line cap, passed whole
# (snapshots are already token-budgeted upstream, e.g. by repomix-handoff).
# Reviewers without a matching file keep the raw-diff path unchanged. codex
# is exempt: `codex exec review --base` does its own diffing internally and
# never gets a text-embedded diff to swap out (see the review_prompt note
# above run_codex). agy-lap exception (antigravity/gemini-pro): agy's -p is
# argv-only, so a snapshot whose ASSEMBLED prompt would exceed the 100KB
# argv guard is refused with a stderr WARN and that lap falls back to the
# raw diff — never silently truncated (in practice keep agy snapshots under
# ~90KB; see the size gate in run_agy_reviewer). Omitting --snapshot-dir
# reproduces today's behavior byte-for-byte.
#
# Writes:
#   <out>/codex.stdout         — codex review (stderr merged)
#   <out>/codex.meta.json      — {exit_code, duration_s}
#   <out>/antigravity.stdout   — antigravity (agy / Flash) review output
#   <out>/antigravity.stderr
#   <out>/antigravity.meta.json
#   <out>/gemini-pro.stdout    — gemini-pro (agy / Pro) review output
#   <out>/gemini-pro.stderr
#   <out>/gemini-pro.meta.json
#   <out>/kimi.stdout          — kimi review text (final assistant message)
#   <out>/kimi.stderr
#   <out>/kimi.meta.json
#   <out>/<or>.stdout          — each OpenRouter reviewer (glm, deepseek, mimo,
#   <out>/<or>.stderr            minimax, qwen, devstral, laguna, kat,
#   <out>/<or>.meta.json         north, nemotron, spark, seed,
#                              grok) writes
#                                stdout/stderr/meta plus request.json and
#                                response.json for audit
#   <out>/kimi27.*, kimi3.*    — direct-Moonshot rotation seats (same
#                                request/response/meta shape as the OR pool,
#                                different endpoint — see run_openrouter_reviewer)
#   <out>/agy.quota_exhausted  — sentinel: agy hit the shared Individual quota
#                                this run (contains the reset ETA). Spares
#                                retries and any lap that starts AFTER detection
#                                (~5s in); the concurrent sibling usually burns
#                                its own doomed call first (2s stagger). No
#                                fallback — the lap drops out of the round.
#   <out>/run.meta.json        — overall run metadata (skipped reason, etc.)
#
# meta.json extras: agy laps carry `failure_kind` (quota_exhausted | agy_panic |
# empty_output | null) and `quota_resets_in`; OpenRouter runs carry
# `cli: "openrouter"` and the exact `model` slug.
#
# Exit codes:
#   0 — at least one reviewer succeeded, OR run was skipped intentionally (empty diff)
#   1 — all requested reviewers failed, or none were available
#   2 — usage / argument error

set -uo pipefail

# Background/cron shells often run with a PATH that lacks the user-level bin
# dirs where reviewer CLIs live (kimi → ~/.local/bin; codex/agy → homebrew).
# rc=127 "command not found" then masquerades as reviewer unreliability —
# kimi logged failed=6 of 10 runs before this was caught (2026-07-03; a
# background-dispatched round hit `timeout: failed to run command 'kimi'`).
# Same failure class as the TIMEOUT_BIN homebrew probe further down.
# Iterate in REVERSE precedence order — each dir is prepended, so the last
# one wins the front of PATH. Forward order left ~/.local/bin THIRD when all
# three were missing, letting a stale homebrew kimi/agy shadow the intended
# user-level install (codex P2, PR #27 pass 2; smoke-tested both orders).
for _d in /usr/local/bin /opt/homebrew/bin "$HOME/.local/bin"; do
  [[ -d "$_d" && ":$PATH:" != *":$_d:"* ]] && PATH="$_d:$PATH"
done
export PATH

base=""
out=""
# Empty default: no per-reviewer snapshots. When set via --snapshot-dir, a
# reviewer whose slug has a matching $snapshot_dir/snapshot-<r>.{md,xml,txt}
# file gets that file's contents as its code-context block INSTEAD of the
# raw diff (see snapshot_for() below and SKILL.md step 2.5). Reviewers
# without a matching file keep the raw-diff path unchanged.
snapshot_dir=""
# Empty default: resolved after arg parsing. If --reviewers is not passed,
# select_roster.sh picks the round's roster (codex+kimi baselines + weighted
# rotation picks); if the selector is missing, fall back to the fixed classic
# fleet. Passing --reviewers explicitly always wins.
reviewers=""
# Global timeout default: 600s. Codex tightens to 300s below since it returns
# fast or fails fast. Antigravity/kimi keep 600s, gemini-pro gets 900s — the
# dense-logic diff in PR #1985 (postmortem in plans/the-miss-on-pr-eager-pond.md)
# blew through 300s on the prior gemini Flash reviewer, so we keep the bumped
# budget on its agy replacements.
# Track explicitness so CLI flags can override profile values: a user passing
# `--timeout 30` for a smoke run must beat the profile's 600s default.
timeout_s_default=600
timeout_s=""               # set when --timeout is explicitly passed
timeout_codex=""
timeout_antigravity=""
timeout_gemini_pro=""
timeout_kimi=""
timeout_glm=""

# MODEL IDS LIVE IN EXACTLY ONE PLACE: references/reviewer_profiles.json
# `.model`. This script deliberately keeps NO fallback copy. It used to carry a
# literal per reviewer that the profile then overrode — so the literals were
# never actually used, silently rotted, and reading them misled anyone trying to
# fix a model rename here. Both `poolside/laguna-m.1` and
# `mistralai/devstral-2512` were delisted upstream while still named in this
# file (PR #41). A missing `.model` now skips that reviewer loudly; a stale one
# is worse than none, because agy silently serves its default on an unknown
# string and OpenRouter answers 404 mid-round.
#
# The names below are the API-lane reviewers whose model comes from the profile.
# Resolution happens after profile_get is defined, further down.
model_backed_reviewers=(antigravity gemini-pro glm deepseek mimo minimax qwen
                        devstral laguna kat north nemotron spark seed grok
                        kimi27 kimi3)

# Antigravity installs `agy` to $HOME/.local/bin. That directory isn't always
# on $PATH for non-interactive shells (notably bash invocations from other
# tools). Surface it ourselves so `command -v agy` and a bare `agy` both
# resolve without requiring the user to edit their shell rc.
if [[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  PATH="$HOME/.local/bin:$PATH"
fi

need_val() {
  local flag="$1"
  local argc="$2"
  if [[ "$argc" -lt 2 ]]; then
    echo "missing value for $flag" >&2
    exit 2
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)               need_val --base               "$#"; base="$2";               shift 2 ;;
    --out)                need_val --out                "$#"; out="$2";                shift 2 ;;
    --reviewers)          need_val --reviewers          "$#"; reviewers="$2";          shift 2 ;;
    --timeout)            need_val --timeout            "$#"; timeout_s="$2";          shift 2 ;;
    --timeout-codex)      need_val --timeout-codex      "$#"; timeout_codex="$2";      shift 2 ;;
    --timeout-antigravity) need_val --timeout-antigravity "$#"; timeout_antigravity="$2"; shift 2 ;;
    --timeout-gemini-pro) need_val --timeout-gemini-pro "$#"; timeout_gemini_pro="$2"; shift 2 ;;
    --timeout-kimi)       need_val --timeout-kimi       "$#"; timeout_kimi="$2";       shift 2 ;;
    --timeout-glm)        need_val --timeout-glm        "$#"; timeout_glm="$2";        shift 2 ;;
    --snapshot-dir)       need_val --snapshot-dir       "$#"; snapshot_dir="$2";       shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$base" || -z "$out" ]]; then
  echo "usage: $0 --base <branch> --out <dir> [--reviewers codex,antigravity,gemini-pro,kimi,glm,deepseek,mimo,minimax,qwen,devstral,laguna,kat,north,nemotron,spark,seed,grok] [--timeout <sec>] [--timeout-codex <sec>] [--timeout-antigravity <sec>] [--timeout-gemini-pro <sec>] [--timeout-kimi <sec>] [--timeout-glm <sec>] [--snapshot-dir <dir>]" >&2
  exit 2
fi

# Roster resolution: no --reviewers → ask select_roster.sh (weighted rotation,
# codex+kimi baselines). The selector prints a comma list on stdout and its
# reasoning on stderr (passed through so the user sees why the roster is what
# it is). Missing/failed selector → classic fixed fleet.
if [[ -z "$reviewers" ]]; then
  selector="$(cd "$(dirname "$0")" && pwd)/select_roster.sh"
  if [[ -x "$selector" ]] && reviewers="$(bash "$selector")" && [[ -n "$reviewers" ]]; then
    echo "roster (select_roster.sh): $reviewers" >&2
  else
    reviewers="codex,antigravity,gemini-pro,kimi,glm"
    echo "roster: selector unavailable — using fixed fallback fleet: $reviewers" >&2
  fi
fi

# Per-reviewer timeout precedence (CLI > config > built-in default):
#   1. --timeout-<reviewer>      (per-reviewer CLI flag, explicit)
#   2. --timeout                 (global CLI flag, explicit)
#   3. references/reviewer_profiles.json `.timeout_s`
#   4. timeout_s_default (with codex tightened to 300s, gemini-pro to 900s)
# This matches standard Unix conventions — explicit CLI always wins. The
# previous order put profile above --timeout, which silently broke
# `--timeout 30` smoke runs (caught by codex review on PR #10).
profile_file="$(cd "$(dirname "$0")/.." && pwd)/references/reviewer_profiles.json"
profile_get() {
  # Usage: profile_get <reviewer> <key>; prints the string value from the
  # profile, or empty string if jq/file/key absent.
  local r="$1" k="$2"
  [[ -f "$profile_file" ]] || { echo ""; return; }
  command -v jq >/dev/null 2>&1 || { echo ""; return; }
  jq -r --arg r "$r" --arg k "$k" '.[$r][$k] // empty' "$profile_file" 2>/dev/null
}
profile_timeout() { profile_get "$1" timeout_s; }

# Resolve every model string from the profile — the single source of truth (see
# the note at the top of this file). A reviewer whose profile has no `.model`
# ends up with an empty variable; run_agy_reviewer/run_openrouter_reviewer then
# refuse to run it and say which file to edit, rather than guessing.
for _r in "${model_backed_reviewers[@]}"; do
  printf -v "${_r//-/_}_model" '%s' "$(profile_get "$_r" model)"
done

codex_profile="$(profile_timeout codex)"
antigravity_profile="$(profile_timeout antigravity)"
gemini_pro_profile="$(profile_timeout gemini-pro)"
kimi_profile="$(profile_timeout kimi)"
glm_profile="$(profile_timeout glm)"
deepseek_profile="$(profile_timeout deepseek)"
mimo_profile="$(profile_timeout mimo)"
minimax_profile="$(profile_timeout minimax)"
qwen_profile="$(profile_timeout qwen)"
devstral_profile="$(profile_timeout devstral)"
laguna_profile="$(profile_timeout laguna)"
kat_profile="$(profile_timeout kat)"
north_profile="$(profile_timeout north)"
nemotron_profile="$(profile_timeout nemotron)"
spark_profile="$(profile_timeout spark)"
seed_profile="$(profile_timeout seed)"
grok_profile="$(profile_timeout grok)"
kimi27_profile="$(profile_timeout kimi27)"
kimi3_profile="$(profile_timeout kimi3)"
codex_timeout="${timeout_codex:-${timeout_s:-${codex_profile:-$(( timeout_s_default < 300 ? timeout_s_default : 300 ))}}}"
antigravity_timeout="${timeout_antigravity:-${timeout_s:-${antigravity_profile:-$timeout_s_default}}}"
# gemini-pro defaults to a longer budget than Flash: Pro's deeper reasoning
# routinely runs 2-3x longer than Flash on the same diff.
gemini_pro_timeout="${timeout_gemini_pro:-${timeout_s:-${gemini_pro_profile:-900}}}"
kimi_timeout="${timeout_kimi:-${timeout_s:-${kimi_profile:-$timeout_s_default}}}"
glm_timeout="${timeout_glm:-${timeout_s:-${glm_profile:-$timeout_s_default}}}"
# The other OpenRouter reviewers share the glm flag-less pattern: global
# --timeout, else profile timeout_s, else the 600s default. Per-reviewer
# tuning belongs in reviewer_profiles.json, not new CLI flags.
deepseek_timeout="${timeout_s:-${deepseek_profile:-$timeout_s_default}}"
mimo_timeout="${timeout_s:-${mimo_profile:-$timeout_s_default}}"
minimax_timeout="${timeout_s:-${minimax_profile:-$timeout_s_default}}"
qwen_timeout="${timeout_s:-${qwen_profile:-$timeout_s_default}}"
devstral_timeout="${timeout_s:-${devstral_profile:-$timeout_s_default}}"
laguna_timeout="${timeout_s:-${laguna_profile:-$timeout_s_default}}"
kat_timeout="${timeout_s:-${kat_profile:-$timeout_s_default}}"
north_timeout="${timeout_s:-${north_profile:-$timeout_s_default}}"
nemotron_timeout="${timeout_s:-${nemotron_profile:-$timeout_s_default}}"
spark_timeout="${timeout_s:-${spark_profile:-$timeout_s_default}}"
seed_timeout="${timeout_s:-${seed_profile:-$timeout_s_default}}"
grok_timeout="${timeout_s:-${grok_profile:-$timeout_s_default}}"
kimi27_timeout="${timeout_s:-${kimi27_profile:-$timeout_s_default}}"
kimi3_timeout="${timeout_s:-${kimi3_profile:-$timeout_s_default}}"

mkdir -p "$out"

# Validate the base ref up front. Without this, `git diff --quiet` below
# would return 128 on a missing ref — which bash treats as non-zero (same as
# "has diff") and the script would spawn reviewers against a broken
# comparison, wasting tokens and inviting hallucinated findings. Fail loud
# so the caller can retry with a valid --base instead of silently wrong.
if ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
  echo "invalid or unknown base ref: $base" >&2
  echo "  hint: try 'git fetch origin' or pass --base <ref> explicitly" >&2
  exit 1
fi

# Empty-diff short-circuit: burning 5 min + tens of thousands of tokens on a
# no-op branch produces nothing real (and sometimes invites hallucinated
# findings). Reviewers also can't diff what they can't see.
# (Base is validated above, so `git diff --quiet` here returns 0 (no diff) or
# 1 (has diff) cleanly, never 128.)
if git diff --quiet "$base"...HEAD; then
  printf '{"skipped": true, "reason": "no_diff_against_base", "base": "%s"}\n' "$base" > "$out/run.meta.json"
  echo "no diff against $base — skipping reviewers" >&2
  exit 0
fi

# Timeout shim: macOS has no `timeout` by default. `gtimeout` ships with
# coreutils (brew install coreutils). Pick whichever is on PATH — and when
# PATH doesn't have it, probe the standard homebrew install locations before
# giving up: background/cron shells often run with a PATH that lacks
# /opt/homebrew/bin, and on 2026-07-01 that silently ran EVERY reviewer
# unbounded (kimi went 42min against a 600s budget; only the never-read
# warning below knew why).
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
else
  for _tb in /opt/homebrew/bin/gtimeout /usr/local/bin/gtimeout /opt/homebrew/bin/timeout /usr/local/bin/timeout; do
    [[ -x "$_tb" ]] && { TIMEOUT_BIN="$_tb"; break; }
  done
fi
# Fixture-test override: force the bash-watchdog fallback path even on
# machines that have coreutils. Production callers never set it.
[[ "${CROSS_REVIEW_FORCE_NO_TIMEOUT_BIN:-}" == "1" ]] && TIMEOUT_BIN=""

if [[ -z "$TIMEOUT_BIN" ]]; then
  echo "warning: neither 'timeout' nor 'gtimeout' is available (checked PATH + homebrew paths) — falling back to a bash watchdog for the ${timeout_s_default}s cutoff. Install coreutils (brew install coreutils) for the real thing." >&2
fi

run_with_timeout() {
  # Usage: run_with_timeout <secs> <cmd...>
  # Runs cmd with timeout if available; otherwise just exec.
  # -k 10: several reviewer CLIs (agy observed; wedged node CLIs generally)
  # ignore SIGTERM — without KILL escalation a wedged reviewer hangs the
  # subshell forever and the round never closes.
  local secs="$1"; shift
  if [[ -n "$TIMEOUT_BIN" ]]; then
    "$TIMEOUT_BIN" -k 10 "$secs" "$@"
    return
  fi
  # No coreutils: bash-watchdog fallback so a reviewer can never run
  # unbounded (issue #7 — a stalled auth prompt in a headless environment
  # used to hang the round forever and burn API budget). TERM at the
  # deadline, KILL 10s later, exit codes mapped to coreutils semantics
  # (124 timeout, 137 KILL escalation) so meta.timed_out and the retry
  # policy behave identically on both paths.
  # Job control (set -m) puts each background job in its own process group so
  # the watchdog can signal the whole reviewer process TREE, not just the
  # top-level PID — GNU timeout signals the child's group the same way, and
  # without this a reviewer's child process would survive the "timeout" and
  # keep burning CPU/API budget (codex P2, PR #21 pass 1).
  local had_m=0; [[ $- == *m* ]] && had_m=1
  set -m
  "$@" &
  local cmd_pid=$!
  ( sleep "$secs" && kill -TERM -- "-$cmd_pid" 2>/dev/null
    sleep 10 && kill -KILL -- "-$cmd_pid" 2>/dev/null ) &
  local wd_pid=$!
  [[ $had_m -eq 0 ]] && set +m
  local rc=0
  wait "$cmd_pid" 2>/dev/null || rc=$?
  if kill -0 "$wd_pid" 2>/dev/null; then
    # Command beat the deadline — group-kill the watchdog so its in-flight
    # `sleep $secs` dies with it instead of lingering (kimi, PR #21 pass 1).
    kill -TERM -- "-$wd_pid" 2>/dev/null || true
    wait "$wd_pid" 2>/dev/null || true
  fi
  # 128+SIGTERM → coreutils timeout exit. 137 (KILL escalation) passes
  # through UNMAPPED on purpose: coreutils `timeout -k` also exits 137 in
  # that case and every meta call-site classifies `124 || 137` as timed_out —
  # a convergent laguna+qwen "map 137→124" finding on pass 1 was falsified
  # against the call sites (see feedback_convergent_not_correct).
  [[ $rc -eq 143 ]] && rc=124
  return "$rc"
}

# retry_reviewer: run a reviewer function once, retry once on nonzero exit
# with a jittered 5-15s backoff. Applied only to antigravity/gemini-pro/kimi,
# which get flaky under concurrent or quick-succession runs (rate limits,
# auth handshake races). Codex has been reliable — don't wrap it.
#
# Timeout (rc=124, the convention used by both `timeout` and `gtimeout`) is
# explicitly NOT retried. A reviewer that just used its full budget of
# reasoning tokens will use the same budget on attempt 2 and time out again,
# which only doubles the cost. PR #1985 postmortem caught this — the cure
# for "needs more time" is a longer per-reviewer timeout, not a retry. True
# transient failures (rc=1, network errors) still retry.
#
# Exports CROSS_REVIEW_ATTEMPT so the reviewer fn can include it in its
# meta output. An exported env var (vs. bash dynamic scoping on a `local`)
# survives callees that declare their own `local attempt`, which is a
# reasonable future refactor that would otherwise silently break the
# retry telemetry.
retry_reviewer() {
  local fn="$1"
  local name="$2"
  export CROSS_REVIEW_ATTEMPT=1
  "$fn"
  local rc=$?
  # rc=3 (agy quota exhausted) is also not retried: the shared Individual
  # quota resets on a ~2-day cadence, so attempt 2 is guaranteed to hit the
  # same wall. No fallback by policy — the lap just drops out of this round.
  if [[ $rc -eq 3 ]]; then
    echo "$name: agy quota exhausted — not retrying, lap drops out of this round (reset ETA: see $out/agy.quota_exhausted)" >&2
    unset CROSS_REVIEW_ATTEMPT
    return "$rc"
  fi
  if [[ $rc -ne 0 && $rc -ne 124 && $rc -ne 137 ]]; then
    local backoff=$((5 + RANDOM % 11))
    echo "$name: attempt 1 failed (rc=$rc), retrying in ${backoff}s" >&2
    sleep "$backoff"
    export CROSS_REVIEW_ATTEMPT=2
    "$fn"
    rc=$?
    if [[ $rc -eq 0 ]]; then
      echo "$name: attempt 2 succeeded" >&2
    elif [[ $rc -eq 124 || $rc -eq 137 ]]; then
      echo "$name: attempt 2 timed out (rc=$rc)" >&2
    else
      echo "$name: attempt 2 also failed (rc=$rc)" >&2
    fi
  elif [[ $rc -eq 124 || $rc -eq 137 ]]; then
    # 137 = timeout's -k SIGKILL after an ignored SIGTERM (codex P2, PR #18
    # pass 3) — same retry semantics as 124: the budget was consumed and a
    # retry would just consume it again.
    echo "$name: attempt 1 timed out (rc=$rc), not retrying — bump the timeout if this recurs" >&2
  fi
  unset CROSS_REVIEW_ATTEMPT
  return "$rc"
}

# Helper: compute output bytes for a reviewer's primary stdout file. Used in
# meta.json so the runlog can distinguish "ran but produced nothing" (silent
# fail) from "ran and produced findings".
output_bytes_of() {
  local f="$1"
  if [[ -f "$f" ]]; then
    wc -c <"$f" | tr -d ' '
  else
    echo 0
  fi
}

# output_degenerate <file> — detect pathological repetition (a model stuck in
# a token loop: glm produced 145KB of "wait wait wait…" with exit 0 on PR #25
# pass 3, and the leaderboard counted it as a reliable run). Detector: gzip
# compression ratio. Calibration against 2026-07-02's real outputs: the
# degenerate file compressed 69:1; every healthy output — including codex's
# 182KB structured session logs — sat at 2:1–3:1. Threshold 15:1 leaves ~5×
# margin on both sides. Only meaningful past 512 bytes (header amortization);
# no gzip on PATH → not degenerate (detector is best-effort, never a gate on
# healthy runs).
output_degenerate() {
  local f="$1" raw comp
  command -v gzip >/dev/null 2>&1 || return 1
  raw=$(output_bytes_of "$f")
  [[ "$raw" -ge 512 ]] || return 1
  comp=$(gzip -c "$f" 2>/dev/null | wc -c | tr -d ' ')
  [[ "${comp:-0}" -gt 0 ]] || return 1
  [[ $(( comp * 15 )) -lt "$raw" ]]
}

# output_no_verdict <file> — detect a preamble-only response: rc=0 with a tiny
# output carrying neither a severity rank nor an explicit clean verdict. kimi
# delivered a 161-byte "I will now review…" preamble on PR #2620 (2026-07-03)
# that logged status ok — synthesis silently lost the vote while the
# leaderboard counted a reliable run. The gzip gate can't catch short
# non-repetitive text, so this is its < 512-byte complement.
# A legitimate clean review is often SHORT but always SAYS so ("no findings",
# "looks correct", severity headings…) — require one marker below 512 bytes;
# at ≥512 bytes assume real prose and stay out of the way. False positives are
# cheap: rc=5 gets one retry_reviewer swing and an honest failure_kind — and
# synthesis reads the raw stdout regardless, so a real finding phrased without
# any marker still reaches triage. The review prompt mandates Critical/High/
# Medium/Low ranking, so compliant reviews always carry a marker; markers are
# English-only, same as the review prompt and the current pool.
output_no_verdict() {
  local f="$1" raw
  raw=$(output_bytes_of "$f")
  [[ "$raw" -gt 0 && "$raw" -lt 512 ]] || return 1
  # A curl-lane JSON reply is an explicit verdict by construction: a parseable
  # object with a top-level findings array says "clean" via [] — 16 bytes,
  # zero marker words. The marker-word regex below is for prose lanes only.
  if jq -e 'type=="object" and has("findings") and (.findings|type=="array")' "$f" >/dev/null 2>&1; then
    return 1
  fi
  # NOTE: no empty alternatives — `(a |b |)` is invalid POSIX ERE and BSD
  # grep silently fails the whole pattern; use `( … )?` optional groups.
  ! grep -qiE 'critical|high|medium|low|no (significant |material )?(issues?|findings?|problems?|concerns?)|looks (good|correct|fine)|lgtm|approved|no regressions|\[P[0-9]\]' "$f"
}

# doc_narrative_risk <name_status_lines> — true when the diff touches
# doc/markdown files, which often narrate PAST bugs in prose (investigation
# docs, postmortems, changelogs). A text-only reviewer (no file-reading
# tools) can mistake a document description of a PRE-FIX bug for a live
# finding: devstral replayed 9 of 12 findings, and deepseek 4 of 5, straight
# from an in-diff investigation doc on PR #350 (2026-07-05) — codex and kimi
# (which roam files) were not fooled, since they could check whether the
# described bugs were actually still present. Detection is by file EXTENSION
# only, not prose content — content-sniffing for bug language needs
# unbounded phrasing coverage and is the same fragile-heuristic trap
# output_no_verdict already warns against; knowing a file CAN narrate
# history is caution enough.
#
# Takes `git diff --name-status` output (one change per line, tab-separated:
# "M\tpath" / "A\tpath" / "R083\told\tnew" for a rename), NOT `--stat` or
# `--name-only`:
#   - `--stat` compresses a rename as "docs/{old.txt => new.md} | 1 +" (the
#     extension check misses it — ".md" is followed by "}", not
#     whitespace/EOL) and is capped at 50 lines by the caller elsewhere for
#     prompt display, which would truncate a doc file past the cutoff on a
#     >50-file diff (codex P2/P3, PR #30 pass 1).
#   - `--name-only` reports ONLY the destination path on a rename — a doc
#     renamed AWAY to a non-doc extension with edits (e.g.
#     investigation.md => notes.txt) drops out of detection entirely, even
#     though the diff hunk still carries every line of the original doc's
#     prose as context/removed lines (codex P2, PR #30 pass 2).
# `--name-status` reports BOTH paths on a rename (tab-separated), uncapped,
# no brace compression — the same extension regex now checks source AND
# destination; a tab is `[[:space:]]` so the mid-line source column still
# matches.
doc_narrative_risk() {
  grep -qiE '\.(md|mdx|markdown|rst|adoc)([[:space:]]|$)' <<<"$1"
}

# doc_narrative_note <name_status_lines> — the caution text to splice into a
# text-only reviewer prompt when doc_narrative_risk fires; empty otherwise.
# Injected only for kimi and the OpenRouter-pool runner (this function is
# NOT called from run_codex/run_agy_reviewer): those reviewers have
# file-reading tools and can verify a claim against the live repo instead of
# trusting prose.
doc_narrative_note() {
  if doc_narrative_risk "$1"; then
    printf '\n\n[NOTE: this diff touches documentation/markdown files. Such files often describe PAST bugs, root causes, or pre-fix behavior in prose - that description is not itself a code change. Do NOT report a finding based on a document narrative of a historical bug unless the actual CODE hunks in the diff below show the described defect PRESENTLY exists. A document stating that a bug used to happen is not evidence it is still happening.]'
  fi
}

# wall_over_budget <duration_s> <budget_s> — "true" when the wall-clock
# duration overran the enforced budget by >60s. That cannot happen when
# enforcement works (TERM/KILL lag ≤10s; curl fires at --max-time exactly)
# UNLESS the machine slept mid-run: gtimeout/curl timers freeze during system
# sleep while date +%s keeps counting (observed 2026-07-03 — codex logged
# 1024s against a 300s budget with rc=0 during pmset Dark Wake churn).
# Stamped into meta.json so analyze_runlog/leaderboard can discount the sample.
wall_over_budget() {
  local dur="$1" budget="$2"
  if [[ "$dur" -gt $(( budget + 60 )) ]]; then echo "true"; else echo "false"; fi
}

# snapshot_for <reviewer-slug> — prints the path to that reviewer's
# repomix-handoff snapshot under $snapshot_dir (checked in .md, .xml, .txt
# order — first match wins) and returns 0, or returns 1 with nothing printed
# when --snapshot-dir wasn't passed or no file matches. Callers (run_kimi,
# run_agy_reviewer, run_openrouter_reviewer) use this to decide whether to
# embed the snapshot instead of the raw diff. codex is deliberately not a
# caller — see the review_prompt note above run_codex for why.
snapshot_for() {
  local r="$1" ext f
  [[ -n "$snapshot_dir" ]] || return 1
  for ext in md xml txt; do
    f="$snapshot_dir/snapshot-$r.$ext"
    if [[ -f "$f" ]]; then
      printf '%s' "$f"
      return 0
    fi
  done
  return 1
}

script_dir="$(cd "$(dirname "$0")" && pwd)"
prompt_file="$script_dir/../references/review_prompt.txt"

# Note: review_prompt is used by antigravity, gemini-pro, AND kimi (all three
# consume the `$review_prompt` variable below — see run_antigravity,
# run_gemini_pro, run_kimi). codex exec review --base <ref> applies codex's
# own built-in review instructions (which already rank findings with
# [P1]/[P2]/[P3] labels — equivalent to High/Medium/Low — and cover
# correctness, security, and semantic drift). Forcing our prompt into codex
# would require dropping --base and reconstructing the diff setup in text,
# which is more complexity for negligible gain.
#
# IMPORTANT: keep references/review_prompt.txt GENERIC. It is read verbatim
# and passed to multiple reviewers; PR-specific text in this file will cause
# every review across every PR to hallucinate the wrong context (this
# happened in the 2026-05-19 round when a stale PR-#2181 Village-rules
# prompt was left in this file — all 6 PRs reviewed in that round saw
# the reviewers confabulate Village-rules findings).
default_prompt="Review the changes on the current branch against '$base'. \
Focus on correctness, security, and whether the change achieves its stated intent. \
Flag concrete issues tied to file paths and line numbers where possible. \
Rank findings as Critical / High / Medium / Low. Skip pure style nits."

if [[ -f "$prompt_file" ]]; then
  review_prompt="$(cat "$prompt_file")"
  review_prompt="${review_prompt//\{\{BASE\}\}/$base}"
else
  review_prompt="$default_prompt"
fi

# json_findings_suffix: schema-mandate text appended ONLY in the curl lane
# (run_openrouter_reviewer — the OpenRouter pool plus direct-Moonshot seats
# like kimi27/kimi3). Those reviewers have no downstream tool loop of their
# own; merge_raw_findings.sh depends on them answering with exactly the
# findings.json shape documented in SKILL.md step 4, so their prompt must
# demand it explicitly. The CLI reviewers (codex, the agy laps, kimi CLI)
# deliberately do NOT get this suffix — they keep free-prose output for the
# existing LLM-driven synthesis step; do not source this file from
# run_codex/run_agy_reviewer/run_kimi.
json_suffix_file="$script_dir/../references/json_findings_suffix.txt"
json_findings_suffix=""
if [[ -f "$json_suffix_file" ]]; then
  json_findings_suffix="$(cat "$json_suffix_file")"
fi

run_codex() {
  local start end rc
  start=$(date +%s)
  # codex exec review runs the built-in review prompt against the branch diff.
  # --full-auto: low-friction sandbox, workspace-write, no approval prompts.
  # IMPORTANT: --base and a positional [PROMPT] are mutually exclusive — if you
  # want a custom prompt, you must drop --base and put the base reference inside
  # the prompt itself.
  # NO --json: the JSONL stream omits the final review summary for `exec review`.
  # Plain-text mode flushes the review after the "codex" marker; we merge
  # stderr→stdout (2>&1) because codex writes progress trace AND the final
  # review to stderr while stdout is empty in this mode.
  #
  # Godot projects: Godot 4.x segfaults at startup (RotatedFileLogger
  # null-deref) when it cannot create user://logs, and codex's workspace-write
  # seatbelt denies ~/Library/Application Support/Godot. Whitelist that root so
  # codex can run `godot --headless` to verify runtime claims instead of
  # guessing (it guessed wrong on chain-racing PR #42). Verified empirically
  # via `codex sandbox macos` 2026-06-10 on codex-cli 0.128.0.
  local -a codex_cfg=()
  if [[ -f project.godot ]]; then
    codex_cfg+=(-c "sandbox_workspace_write.writable_roots=[\"$HOME/Library/Application Support/Godot\"]")
  fi
  run_with_timeout "$codex_timeout" codex exec review \
    --base "$base" \
    --full-auto \
    ${codex_cfg[@]+"${codex_cfg[@]}"} \
    >"$out/codex.stdout" 2>&1
  rc=$?
  end=$(date +%s)
  local timed_out="false"
  [[ $rc -eq 124 || $rc -eq 137 ]] && timed_out="true"  # 137 = timeout -k SIGKILL escalation (codex P2, PR #18 pass 3)
  local bytes
  bytes=$(output_bytes_of "$out/codex.stdout")
  local fk_json="null"
  if [[ $rc -eq 0 && "$bytes" -gt 0 ]] && output_degenerate "$out/codex.stdout"; then
    echo "codex: output is a degenerate repetition loop (gzip ratio >15:1) — classifying as failed" >&2
    fk_json='"degenerate_output"'
    rc=5
  elif [[ $rc -eq 0 && "$bytes" -gt 0 ]] && output_no_verdict "$out/codex.stdout"; then
    echo "codex: output is preamble-only (<512B, no severity or clean-verdict marker) — classifying as failed" >&2
    fk_json='"no_verdict_output"'
    rc=5
  fi
  printf '{"exit_code": %d, "duration_s": %d, "timed_out": %s, "output_bytes": %s, "attempt": 1, "timeout_budget_s": %d, "failure_kind": %s, "wall_over_budget": %s}\n' \
    "$rc" "$((end - start))" "$timed_out" "$bytes" "$codex_timeout" "$fk_json" "$(wall_over_budget "$((end - start))" "$codex_timeout")" >"$out/codex.meta.json"
  # IMPORTANT: return $rc so the caller's `wait "$pid"` sees the real exit code.
  # Previous version ended with `printf` whose success (exit 0) masked every
  # upstream reviewer failure.
  return "$rc"
}

# openrouter_key: resolve the OpenRouter API key. Env var wins; the key file
# (~/.config/openrouter/key, single line, chmod 600) is the persistent home.
# Prints the key and returns 0, or returns 1 when neither source exists —
# callers use it both as a getter and as an availability probe.
openrouter_key() {
  if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
    printf '%s' "$OPENROUTER_API_KEY"
    return 0
  fi
  local f="$HOME/.config/openrouter/key"
  if [[ -s "$f" ]]; then
    tr -d '[:space:]' <"$f"
    return 0
  fi
  return 1
}

# moonshot_key: same getter/probe contract as openrouter_key, for the direct
# Moonshot platform API (the kimi27 rotation seat and the kimi baseline share
# this billing rail). Env var wins; ~/.config/moonshot/key (single line,
# chmod 600) is the persistent home.
moonshot_key() {
  if [[ -n "${MOONSHOT_API_KEY:-}" ]]; then
    printf '%s' "$MOONSHOT_API_KEY"
    return 0
  fi
  local f="$HOME/.config/moonshot/key"
  if [[ -s "$f" ]]; then
    tr -d '[:space:]' <"$f"
    return 0
  fi
  return 1
}

# run_openrouter_reviewer: single-turn, diff-inline review via the OpenRouter
# chat-completions API. No agentic tools — the diff IS the input (same niche
# and prompt shape as run_kimi, and the same stdin/argv reasoning: the prompt
# body goes through a temp file + jq --rawfile, never argv). This is the shared
# runner for the whole OpenRouter rotation pool (glm, deepseek, mimo, minimax,
# qwen, devstral, laguna, kat, north, nemotron, spark, seed, grok) — each an
# independent provider
# vote. It is NOT a fallback lane for the
# first-party reviewers (policy: no OR fallbacks for codex/gemini/kimi).
# Args:
#   $1 slug           (glm | deepseek | mimo | minimax | qwen | devstral |
#                      laguna | kat | north | nemotron | spark | seed | grok | kimi27 | kimi3)
#   $2 model          (model id, e.g. z-ai/glm-5.2 or kimi-k2.7-code)
#   $3 timeout_budget (seconds)
#   $4 endpoint       (optional; default OpenRouter chat-completions. kimi27/
#                      kimi3 pass the direct Moonshot endpoint — the API is
#                      OpenAI-compatible, so the whole body is shared)
#   $5 cli label      (optional; default "openrouter" — selects the key
#                      source and is recorded verbatim in meta.json)
run_openrouter_reviewer() {
  local slug="$1" model="$2" timeout_budget="$3"
  local endpoint="${4:-https://openrouter.ai/api/v1/chat/completions}"
  local cli="${5:-openrouter}"
  # Model strings come only from reviewer_profiles.json; an empty one means the
  # profile is missing `.model`. Fail loudly here instead of POSTing "" and
  # reading a 404 as reviewer unreliability.
  if [[ -z "$model" ]]; then
    echo "$slug: no model configured — add \"model\" to references/reviewer_profiles.json (this script keeps no fallback copy)" >&2
    printf '{"exit_code": 2, "duration_s": 0, "timed_out": false, "output_bytes": 0, "attempt": %d, "timeout_budget_s": %d, "model": "", "cli": "%s", "failure_kind": "no_model_configured"}\n' \
      "${CROSS_REVIEW_ATTEMPT:-1}" "$timeout_budget" "$cli" >"$out/${slug}.meta.json"
    return 2
  fi
  local key
  if [[ "$cli" == "moonshot" ]]; then
    if ! key="$(moonshot_key)"; then
      echo "$slug: no Moonshot key (set MOONSHOT_API_KEY or ~/.config/moonshot/key)" >&2
      return 5
    fi
  elif ! key="$(openrouter_key)"; then
    echo "$slug: no OpenRouter key (set OPENROUTER_API_KEY or ~/.config/openrouter/key)" >&2
    return 5
  fi
  local start end rc
  start=$(date +%s)
  local diff_summary diff_full total_lines truncation_note truncated
  diff_summary="$(git diff --stat "$base"...HEAD 2>/dev/null | head -50 || true)"
  # Same line-based cap as run_kimi, for the same reasons (UTF-8 safety,
  # context budget). GLM 5.2 and the OpenRouter Gemini models all take 200k+
  # tokens; 8000 diff lines stays well inside that.
  local diff_line_cap=8000
  local snapshot_path="" using_snapshot=false
  if snapshot_path="$(snapshot_for "$slug")"; then
    using_snapshot=true
  fi
  if [[ "$using_snapshot" == true ]]; then
    # Pre-built by repomix-handoff and already token-budgeted upstream — skip
    # the line cap and truncation note, pass it whole (SKILL.md step 2.5).
    diff_full="$(cat "$snapshot_path" 2>/dev/null || true)"
    total_lines=0
    truncated=false
    truncation_note=""
  else
    diff_full="$(git diff "$base"...HEAD 2>/dev/null | head -n "$diff_line_cap" || true)"
    total_lines="$(git diff "$base"...HEAD 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${total_lines:-0}" -gt "$diff_line_cap" ]]; then
      truncated=true
      truncation_note="

[WARNING: diff truncated to first $diff_line_cap of $total_lines lines. Your review will be INCOMPLETE — the tail of the patch is not shown. Note this limitation in your findings.]"
    else
      truncated=false
      truncation_note=""
    fi
  fi
  local context_label context_tag_open context_tag_close context_intro
  if [[ "$using_snapshot" == true ]]; then
    # Defuse a literal closing tag inside untrusted snapshot content (same
    # prompt-injection guard as the raw-diff </diff> defuse below).
    diff_full="${diff_full//<\/snapshot>/< \/snapshot>}"
    context_label="Code context snapshot (from $(basename "$snapshot_path"), pre-built by repomix-handoff):"
    context_tag_open="<snapshot>"
    context_tag_close="</snapshot>"
    context_intro="Base your review ONLY on the code context snapshot below."
  else
    # Defuse a literal </diff> inside untrusted patch content (same
    # prompt-injection guard as run_kimi).
    diff_full="${diff_full//<\/diff>/< \/diff>}"
    context_label="Full diff:"
    context_tag_open="<diff>"
    context_tag_close="</diff>"
    context_intro="Base your review ONLY on the diff below."
  fi
  local doc_note doc_file_list
  # Uncapped, rename-clean, and source-path-preserving by construction — see
  # doc_narrative_risk's comment for why --name-status, not the capped/
  # brace-compressing --stat display used for the prompt body, nor
  # --name-only (which drops a rename's source path).
  doc_file_list="$(git diff --name-status "$base"...HEAD 2>/dev/null || true)"
  doc_note="$(doc_narrative_note "$doc_file_list")"
  local full_prompt
  full_prompt="$review_prompt

You have no file-reading or shell tools. ${context_intro}${truncation_note}${doc_note}

Changed files (diff --stat against $base):
$diff_summary

$context_label
$context_tag_open
$diff_full
$context_tag_close

$json_findings_suffix"

  local body_file="$out/${slug}.request.json" prompt_tmp
  prompt_tmp="$(mktemp)"
  printf '%s' "$full_prompt" >"$prompt_tmp"
  # usage:{include:true} is an OPENROUTER extension (per-call cost for the
  # findings-per-dollar leaderboard). Moonshot tolerates it today (live-probed
  # 2026-07-03: normal completion + token usage returned) but it buys nothing
  # there and a stricter OpenAI-compatible endpoint could reject it — build
  # the body per cli, same hygiene as the X-Title gate below (codex P2,
  # PR #29 pass 1; the "fails when selected" wording was falsified by the
  # live probe, the cross-provider-leakage hygiene stands).
  #
  # response_format:{type:"json_object"} forces machine-parseable output on
  # BOTH branches (OpenRouter's own extension, and Moonshot's identical
  # OpenAI-compatible field) — merge_raw_findings.sh depends on this lane
  # answering in the findings.json shape rather than free prose. This does
  # NOT touch the CLI reviewers (codex/agy/kimi CLI), which have no
  # request-body concept at all.
  if [[ "$cli" == "openrouter" ]]; then
    jq -n --rawfile p "$prompt_tmp" --arg m "$model" \
      '{model: $m, messages: [{role: "user", content: $p}], stream: false,
        usage: {include: true}, response_format: {type: "json_object"}}' >"$body_file"
  else
    jq -n --rawfile p "$prompt_tmp" --arg m "$model" \
      '{model: $m, messages: [{role: "user", content: $p}], stream: false,
        response_format: {type: "json_object"}}' >"$body_file"
  fi
  rm -f "$prompt_tmp"

  local resp_file="$out/${slug}.response.json"
  # The Authorization header reaches curl on STDIN — never argv, never disk.
  #
  # Not argv: that is world-visible via `ps` for the duration of the call, same
  # rationale as the kimi stdin-prompt rule (kimi finding, PR #18 pass 1).
  #
  # Not disk: it previously went through a 0600 `--config` file removed right
  # after curl returned, which covers every path except the one that matters.
  # When the lap is KILLED mid-call the `rm` never runs, and a live bearer
  # token stays in the run dir indefinitely. Found 2026-08-10 after a failed
  # kimi3 lap left one behind; 14 had accumulated across historical run dirs.
  # Cleaning up more carefully was the smaller fix — writing the secret to a
  # temp file at all is the failure mode, so stdin removes it outright.
  # X-Title is OpenRouter-specific attribution metadata — don't send it to
  # other OpenAI-compatible endpoints (kimi27 Low, its first sampled finding).
  local -a title_header=()
  [[ "$cli" == "openrouter" ]] && title_header=(-H "X-Title: cross-review")
  printf 'header = "Authorization: Bearer %s"\n' "$key" \
  | curl -sS --max-time "$timeout_budget" \
    --config - \
    -H "Content-Type: application/json" \
    ${title_header[@]+"${title_header[@]}"} \
    -d @"$body_file" \
    "$endpoint" \
    >"$resp_file" 2>"$out/${slug}.stderr"
  rc=$?
  # curl exits 28 on --max-time; normalize to 124 so meta.timed_out and the
  # retry policy treat it exactly like a coreutils timeout.
  [[ $rc -eq 28 ]] && rc=124
  if [[ $rc -eq 0 ]]; then
    local api_error
    api_error="$(jq -r '.error.message // empty' "$resp_file" 2>/dev/null)"
    if [[ -n "$api_error" ]]; then
      echo "$slug: $cli API error: $api_error" >>"$out/${slug}.stderr"
      rc=1
    else
      jq -r '.choices[0].message.content // empty' "$resp_file" >"$out/${slug}.stdout" 2>>"$out/${slug}.stderr" || rc=1
    fi
  fi
  end=$(date +%s)
  local timed_out="false"
  [[ $rc -eq 124 || $rc -eq 137 ]] && timed_out="true"  # 137 = timeout -k SIGKILL escalation (codex P2, PR #18 pass 3)
  local bytes
  bytes=$(output_bytes_of "$out/${slug}.stdout")
  # rc=0 with empty content is still a failure (filtered/refused/odd response)
  # — rc=5 keeps it out of any_ok and lets retry_reviewer take one more swing.
  [[ $rc -eq 0 && "$bytes" -eq 0 ]] && rc=5
  local fk_json="null"
  if [[ $rc -eq 0 && "$bytes" -gt 0 ]] && output_degenerate "$out/${slug}.stdout"; then
    echo "$slug: output is a degenerate repetition loop (gzip ratio >15:1) — classifying as failed" >&2
    fk_json='"degenerate_output"'
    rc=5
  elif [[ $rc -eq 0 && "$bytes" -gt 0 ]] && output_no_verdict "$out/${slug}.stdout"; then
    echo "$slug: output is preamble-only (<512B, no severity or clean-verdict marker) — classifying as failed" >&2
    fk_json='"no_verdict_output"'
    rc=5
  fi
  # Cost accounting (fugu lesson, PR #20): usage:{include:true} makes OR
  # return authoritative per-call cost; recording it in meta → runlog lets
  # the leaderboard weight findings-per-dollar, so a 100x-priced reviewer
  # is visible in telemetry instead of only on a billing dashboard. Null
  # (older entries, failed calls, providers that omit usage) degrades to 0.
  local cost_json="null" tokp_json="null" tokc_json="null"
  if [[ -s "$resp_file" ]]; then
    # jq type check instead of a permissive bash regex (nemotron, PR #28
    # pass 1): anything non-numeric — strings, objects, corrupt provider
    # output — degrades to null. Field is `.usage.cost` per a REAL captured
    # response (fugu, runs/…-pr18…/raw/fugu.response.json), not total_cost.
    cost_json="$(jq -r '.usage.cost | if type=="number" then tostring else "null" end' "$resp_file" 2>/dev/null || echo null)"
    tokp_json="$(jq -r '.usage.prompt_tokens | if type=="number" then tostring else "null" end' "$resp_file" 2>/dev/null || echo null)"
    tokc_json="$(jq -r '.usage.completion_tokens | if type=="number" then tostring else "null" end' "$resp_file" 2>/dev/null || echo null)"
  fi
  # A retried attempt overwrites meta — but attempt 1's spend was real money
  # (a charged response classified degenerate/no-verdict still billed).
  # Accumulate across attempts so the leaderboard sees true per-run cost
  # (codex P2, PR #28 pass 1).
  if [[ "${CROSS_REVIEW_ATTEMPT:-1}" -gt 1 && -f "$out/${slug}.meta.json" ]]; then
    local prior_cost
    prior_cost="$(jq -r '.cost_usd | if type=="number" then tostring else "0" end' "$out/${slug}.meta.json" 2>/dev/null || echo 0)"
    if [[ "$prior_cost" != "0" ]]; then
      if [[ "$cost_json" == "null" ]]; then
        cost_json="$prior_cost"
      else
        cost_json="$(awk -v a="$cost_json" -v b="$prior_cost" 'BEGIN{printf "%.6f", a + b}')"
      fi
    fi
  fi
  printf '{"exit_code": %d, "duration_s": %d, "timed_out": %s, "output_bytes": %s, "truncated": %s, "total_diff_lines": %d, "attempt": %d, "timeout_budget_s": %d, "model": "%s", "cli": "%s", "failure_kind": %s, "wall_over_budget": %s, "cost_usd": %s, "tokens_prompt": %s, "tokens_completion": %s}\n' \
    "$rc" "$((end - start))" "$timed_out" "$bytes" "$truncated" "${total_lines:-0}" "${CROSS_REVIEW_ATTEMPT:-1}" "$timeout_budget" "$model" "$cli" "$fk_json" "$(wall_over_budget "$((end - start))" "$timeout_budget")" "$cost_json" "$tokp_json" "$tokc_json" >"$out/${slug}.meta.json"
  return "$rc"
}

# agy_soft_denied <agy_log> <stderr_file> — true when agy produced nothing
# because headless print mode auto-denied a tool confirmation it could not
# prompt for (agy >=1.1.3). Matched on ASCII-only substrings: agy's stderr
# renders an em-dash mid-sentence, so anchoring on the punctuation would be
# encoding-fragile. Either channel alone is sufficient — which one carries the
# message varies by agy build.
agy_soft_denied() {
  local log="$1" err="$2"
  [[ -f "$log" ]] && grep -q 'soft-denying tool confirmation' "$log" 2>/dev/null && return 0
  [[ -f "$err" ]] && grep -q 'permission that headless mode cannot prompt for' "$err" 2>/dev/null && return 0
  [[ -f "$log" ]] && grep -q 'permission that headless mode cannot prompt for' "$log" 2>/dev/null && return 0
  return 1
}

# NOTE ON THE STRING MATCHERS BELOW: agy_soft_denied/agy_print_timeout key off
# agy's human-readable output, verified against agy 1.1.8-1.1.10. A future
# wording change does not break the run — it degrades that failure back to the
# generic empty_output/failed bucket, which reads as "re-auth" when the truth is
# something else. If a lap starts failing with a null failure_kind, diff agy's
# current stderr against these strings before believing the bucket (kimi Low,
# PR #41 pass 1).
# agy_print_timeout <stderr_file> — true when agy gave up waiting for the model
# and exited on its OWN --print-timeout rather than being killed by the wrapper.
# Signature (verified 2026-08-03, agy 1.1.8): rc=1, 0 bytes stdout, stderr is
# exactly `Error: timeout waiting for response`, and coreutils `timeout` never
# fires (so rc is 1, not 124, and the old code left failure_kind=null). This is
# the gemini-pro "attempt 1 empty, attempt 2 fine" flake: Gemini 3.1 Pro at High
# effort routinely needs 300-400s on a 100KB prompt, so a budget whose internal
# timeout lands near that mark loses the race intermittently. The remedy is a
# bigger --timeout-gemini-pro, NOT re-auth — which is exactly what the
# empty_output bucket would have told the operator to do.
agy_print_timeout() {
  local err="$1"
  [[ -f "$err" ]] && grep -q 'timeout waiting for response' "$err" 2>/dev/null && return 0
  return 1
}

# run_agy_reviewer: shared body for the two Gemini-family laps. Both run on the
# `agy` (Antigravity) CLI; they differ only in slug, --model, and timeout.
# POLICY: no OpenRouter fallback for first-party laps — on quota/panic the lap
# fails honestly and roster rotation covers the gap on subsequent runs. Args:
#   $1 slug   (antigravity | gemini-pro)
#   $2 model  (exact `agy models` display name)
#   $3 timeout_budget (seconds)
run_agy_reviewer() {
  local slug="$1" model="$2" timeout_budget="$3"

  if [[ -z "$model" ]]; then
    echo "$slug: no model configured — add \"model\" to references/reviewer_profiles.json (this script keeps no fallback copy)" >&2
    printf '{"exit_code": 2, "duration_s": 0, "timed_out": false, "output_bytes": 0, "attempt": %d, "timeout_budget_s": %d, "model": "", "cli": "%s", "failure_kind": "no_model_configured"}\n' \
      "${CROSS_REVIEW_ATTEMPT:-1}" "$timeout_budget" "agy" >"$out/${slug}.meta.json"
    return 2
  fi

  # Quota sentinel: the two laps share one Google "Individual quota" (resets on
  # a ~2-day cadence — it will NOT recover within this run). If the sibling lap
  # or an earlier attempt already hit the wall, don't burn another agy call.
  if [[ -f "$out/agy.quota_exhausted" ]]; then
    echo "$slug: agy quota already exhausted this run ($(cat "$out/agy.quota_exhausted" 2>/dev/null)) — skipping agy" >&2
    printf '{"exit_code": 3, "duration_s": 0, "timed_out": false, "output_bytes": 0, "attempt": %d, "timeout_budget_s": %d, "model": "%s", "cli": "agy", "failure_kind": "quota_exhausted", "agy_call_skipped": true}\n' \
      "${CROSS_REVIEW_ATTEMPT:-1}" "$timeout_budget" "$model" >"$out/${slug}.meta.json"
    return 3
  fi
  # Real flag surface (from `agy --help`, agy 1.0.9):
  #   -p / --print / --prompt        : non-interactive single-shot mode.
  #   --model <name>                 : exact display name from `agy models`.
  #                                    Unknown name => SILENT fallback to default
  #                                    (Flash). agy can't be made to error, so the
  #                                    profile/script strings must stay correct.
  #   --print-timeout <dur>          : in-CLI timeout (default 5m), Go duration
  #                                    syntax. Set just under the wrapper timeout
  #                                    so agy exits cleanly rather than being
  #                                    hard-killed mid-write (losing partial out).
  #   --sandbox                      : terminal restrictions enabled (closest
  #                                    thing to read-only; restricts the shell
  #                                    tool sandbox). We also prompt-instruct
  #                                    "no edits" as a backstop.
  #   --dangerously-skip-permissions : NOT used — a reviewer that auto-approves
  #                                    writes defeats the point.
  #   --log-file <path>              : pin agy's own log next to our outputs.
  # Auth: one-time `agy login` (or any interactive `agy -p`) in a TTY; OAuth
  # state persists. Empty stdout usually means auth expired — re-auth, don't
  # bump the timeout.
  local start end rc
  start=$(date +%s)
  # --add-dir (below): agy's sandbox starts the model in its OWN scratch dir
  # (~/.gemini/antigravity-cli/scratch), NOT the repo. Without the repo in the
  # workspace the model can't see any file and goes hunting with `find` /
  # `git rev-parse` — a "command" permission request that headless mode
  # soft-denies, killing the whole run at 0 bytes (2026-07-31 repro; see
  # docs/investigation-agy-empty-output.md). Handing it the repo root removes
  # the reason to shell out at all.
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  local diff_summary diff_full
  diff_summary="$(git diff --stat "$base"...HEAD 2>/dev/null | head -50 || true)"
  local snapshot_path="" using_snapshot=false
  if snapshot_path="$(snapshot_for "$slug")"; then
    using_snapshot=true
  fi
  # Context block uses the same XML-ish <snapshot>/<diff> tag scheme as
  # run_kimi and run_openrouter_reviewer, with the closing-tag defuse: a
  # markdown fence closes early when the embedded content itself contains a
  # triple-backtick line — which diffs and snapshots legitimately do — and an
  # early-closed fence doubles as a prompt-injection surface (cross-review
  # 2026-08-03, kimi+nemotron convergent Medium).
  #
  # The while-loop is the agy-only snapshot size gate. agy's -p is argv-only
  # (no stdin or prompt-file mode — references/cli_flags.md; stdin must stay
  # closed or agy blocks), and the argv guard below truncates the assembled
  # prompt at 100KB. Silently truncating a snapshot would break
  # --snapshot-dir's "passed whole" contract (cross-review 2026-08-03, codex
  # High), so the gate measures the FULL assembled prompt — not the snapshot
  # file against an assumed scaffolding headroom, which both refuses
  # snapshots that actually fit and admits ones the guard then silently
  # truncates (pass-2, codex P1) — and on overflow refuses the snapshot
  # LOUDLY, then loops once more to rebuild on the raw-diff path, whose
  # truncation behavior is pre-existing and documented. Runs at most twice.
  local context_label context_tag_open context_tag_close context_intro
  local full_prompt prompt_bytes
  while :; do
  if [[ "$using_snapshot" == true ]]; then
    diff_full="$(cat "$snapshot_path" 2>/dev/null || true)"
    # Defuse a literal closing tag inside untrusted snapshot content — same
    # guard as run_kimi/run_openrouter_reviewer.
    diff_full="${diff_full//<\/snapshot>/< \/snapshot>}"
    context_label="Code context snapshot (from $(basename "$snapshot_path"), pre-built by repomix-handoff):"
    context_tag_open="<snapshot>"
    context_tag_close="</snapshot>"
    context_intro="A pre-built code context snapshot is included above (already token-budgeted upstream)."
  else
    # Embed the actual diff instead of just making the model go fetch it: agy
    # 1.1.3+ soft-denies Bash/RunCommand tool confirmations in headless print
    # mode (see docs/investigation-agy-empty-output.md) — a reviewer told to
    # "use your file-reading tools to inspect the actual changes" reaches for
    # `git diff` via Bash, gets silently denied, and the conversation ends with
    # zero output (rc=0, 0 bytes — classified downstream as empty_output/rc=5).
    # We already have full shell permission here, so fetch the diff ourselves
    # and hand it over as text. This doesn't require guessing agy's
    # permissions.allow syntax and doesn't touch its global settings.json.
    # unified=50 keeps real context without ballooning the argv-guard below;
    # a reviewer that still wants more (a file's surrounding code, imports)
    # can use its native Read/Glob tools — those are a different permission
    # category than "command" and aren't gated the same way in headless mode.
    diff_full="$(git diff --unified=50 "$base"...HEAD 2>/dev/null || true)"
    # Defuse a literal </diff> inside untrusted patch content — same guard as
    # run_kimi/run_openrouter_reviewer.
    diff_full="${diff_full//<\/diff>/< \/diff>}"
    context_label="Full diff (unified context, against $base):"
    context_tag_open="<diff>"
    context_tag_close="</diff>"
    context_intro="The full diff is included above."
  fi
  full_prompt="$review_prompt

Changed files (diff --stat against $base):
$diff_summary

$context_label
$context_tag_open
$diff_full
$context_tag_close

$context_intro HARD CONSTRAINT: you are running headless with no interactive permission prompt, so ANY shell/terminal command you attempt that is not pre-approved is auto-denied and immediately terminates your run with zero output — the whole review is lost. Do NOT run git, jq, printf, echo, or any other shell command, not even to orient yourself or to validate your own output, and do NOT go looking for the repository — it is already mounted in your workspace at $repo_root. If you need broader context (surrounding code, imports, related logic outside the diff hunks), use your file-reading tools (read/view/search-file) only — those are a different permission category and are not gated this way. Do NOT edit, write, or commit any files — this is a read-only review. Return your findings as prose, organized by severity."

  # ${#var} counts CHARACTERS under a UTF-8 locale, but argv limits are BYTE
  # limits — multibyte-heavy content undercounts by up to 4× (cross-review
  # pass-3, codex P1). Both this gate and the argv guard below measure bytes.
  prompt_bytes="$(printf %s "$full_prompt" | wc -c | tr -d ' ')"
  if [[ "$using_snapshot" == true && "${prompt_bytes:-0}" -gt 100000 ]]; then
    echo "$slug: snapshot $(basename "$snapshot_path") makes the assembled prompt ${prompt_bytes} bytes — exceeds the 100KB argv guard (agy -p is argv-only; MAX_ARG_STRLEN), falling back to the raw diff" >&2
    using_snapshot=false
    continue
  fi
  break
  done

  # argv guard (issue #7): Linux caps a single argv element at ~128KB
  # (MAX_ARG_STRLEN). Embedding the full diff (not just --stat) makes this
  # guard load-bearing rather than defensive-only on large diffs — it still
  # truncates loudly instead of dying opaquely on E2BIG.
  if [[ "${prompt_bytes:-0}" -gt 100000 ]]; then
    echo "$slug: prompt is ${prompt_bytes} bytes — truncating to 100KB to stay under the argv limit (trim references/review_prompt.txt)" >&2
    full_prompt="$(printf %s "$full_prompt" | head -c 100000)

[NOTE: prompt truncated at 100KB by the argv-size guard — the tail of the instructions above may be missing; the cut may split a multibyte character.]"
  fi

  # In-CLI timeout runs 15s UNDER the wrapper budget so agy exits cleanly and
  # flushes partial output instead of being hard-killed by coreutils `timeout`
  # at the same instant. (The old code set them EQUAL — a race the comment
  # above claimed was already avoided.)
  local agy_internal_timeout
  if [[ "$timeout_budget" -gt 30 ]]; then
    agy_internal_timeout="$((timeout_budget - 15))s"
  else
    agy_internal_timeout="${timeout_budget}s"
  fi

  # Per-attempt artifacts: retry_reviewer re-runs this function in place, so a
  # single canonical path means attempt 2 overwrites the only evidence of why
  # attempt 1 failed. Write the agy log to an attempt-stamped path and copy
  # stdout/stderr/log alongside it, then mirror the log to the canonical name
  # the classifier below greps.
  local attempt_n="${CROSS_REVIEW_ATTEMPT:-1}"
  local agy_log_path="$out/${slug}.attempt${attempt_n}.agy.log"
  run_with_timeout "$timeout_budget" agy \
    --model "$model" \
    --sandbox \
    --add-dir "$repo_root" \
    --print-timeout "$agy_internal_timeout" \
    --log-file "$agy_log_path" \
    -p "$full_prompt" \
    >"$out/${slug}.stdout" 2>"$out/${slug}.stderr" </dev/null
  rc=$?
  cp -f "$agy_log_path" "$out/${slug}.agy.log" 2>/dev/null || true
  cp -f "$out/${slug}.stdout" "$out/${slug}.attempt${attempt_n}.stdout" 2>/dev/null || true
  cp -f "$out/${slug}.stderr" "$out/${slug}.attempt${attempt_n}.stderr" 2>/dev/null || true
  end=$(date +%s)
  local timed_out="false"
  [[ $rc -eq 124 || $rc -eq 137 ]] && timed_out="true"  # 137 = timeout -k SIGKILL escalation (codex P2, PR #18 pass 3)
  local bytes
  bytes=$(output_bytes_of "$out/${slug}.stdout")

  # Silent-fallback guard. `agy --model` does NOT error on a string it does not
  # recognise — it quietly serves the default (Flash), so a renamed model would
  # turn the deep Pro lap into a second Flash lap with nobody the wiser and the
  # round would lose the provider diversity it is paying for. agy 1.1.10 already
  # renamed the `agy models` listing out from under the detection grep, so this
  # is a live risk, not a hypothetical. Read back what agy actually resolved;
  # only warn when the log names a DIFFERENT model, so a future log-format
  # change degrades to silence rather than false alarms.
  local resolved_model=""
  if [[ -f "$agy_log_path" ]]; then
    resolved_model="$(grep -o 'Resolving model .*' "$agy_log_path" 2>/dev/null | tail -1 | sed 's/^Resolving model //')"
    if [[ -n "$resolved_model" && "$resolved_model" != "$model" ]]; then
      echo "WARN: $slug asked agy for \"$model\" but agy resolved \"$resolved_model\" — agy silently falls back to its default on an unrecognised model string. Check \`agy models\` and update the model strings in run_reviewers.sh." >&2
    fi
  fi

  # Classify the failure from agy's own log. On the observed failure modes
  # (2026-07-01) stdout AND stderr are both empty — the .agy.log is the only
  # place agy says what actually happened:
  #   quota_exhausted — "RESOURCE_EXHAUSTED (code 429): Individual quota
  #                     reached ... Resets in Nh" AND agy exits 0 with empty
  #                     stdout in ~5s. Without this check the run counted as
  #                     "ok" and synthesis silently lost the Gemini vote.
  #                     (Quota lines can also appear in the log of a run that
  #                     still produced output — intermittent 429s — so quota
  #                     only classifies when the run produced nothing.)
  #   agy_panic       — Go SIGSEGV in agy's RunCommandHandler (upstream bug,
  #                     seen on agy ≤1.0.15); exit 2, ~20-45s, empty output.
  #                     Flaky, so the agy retry is still worth one attempt.
  #   headless_permission_denied
  #                   — rc=0, 0 bytes, and agy's own log/stderr names the
  #                     cause: a Bash/RunCommand tool confirmation was
  #                     soft-denied because headless print mode can't prompt
  #                     (agy ≥1.1.3). stderr: `jetski: no output produced — a
  #                     tool required the "command" permission that headless
  #                     mode cannot prompt for`; log:
  #                     `Print mode: soft-denying tool confirmation`. See
  #                     docs/investigation-agy-empty-output.md. The PreToolUse
  #                     gate installed before dispatch exists precisely so this
  #                     can never fire — if it does, the gate failed to install
  #                     (check the WARN about `command(echo)` in
  #                     ~/.gemini/antigravity-cli/settings.json) rather than
  #                     re-running `agy login`. Split out from empty_output
  #                     (2026-07-20) because the two have opposite remedies
  #                     and conflating them got the Gemini seats written off
  #                     as dead when they were merely gagged.
  #   print_timeout   — rc=1, 0 bytes, stderr `Error: timeout waiting for
  #                     response`. agy's OWN --print-timeout expired, so
  #                     coreutils `timeout` never fired and rc is 1 rather than
  #                     124. Remedy is a bigger budget, not re-auth; meta marks
  #                     timed_out=true so the runlog's timeout-rate warning
  #                     picks it up.
  #   empty_output    — rc=0, 0 bytes, no quota line, no permission line.
  #                     THIS is the one that usually means expired `agy
  #                     login` auth. Re-auth before suspecting anything else.
  local failure_kind="" quota_resets_in=""
  local agy_log="$out/${slug}.agy.log"
  if [[ $rc -eq 0 && "$bytes" -eq 0 || $rc -ne 0 ]]; then
    # Quota is checked on ANY failure, not just empty output: a nonzero-exit
    # run with partial output whose real cause is quota must still classify
    # and write the sentinel (nemotron finding, PR #18 pass 1). Successful
    # runs (rc=0, bytes>0) never reach this block, so stray intermittent 429
    # lines in a good run's log can't misclassify it.
    if [[ -f "$agy_log" ]] && grep -q 'Individual quota reached' "$agy_log" 2>/dev/null; then
      failure_kind="quota_exhausted"
      quota_resets_in="$(grep -o 'Resets in [0-9hms]*' "$agy_log" 2>/dev/null | tail -1 | sed 's/Resets in //')"
      printf 'resets in %s (observed by %s at %s)\n' "${quota_resets_in:-unknown}" "$slug" "$(date '+%Y-%m-%dT%H:%M:%S')" >"$out/agy.quota_exhausted"
      rc=3
    elif [[ $rc -ne 0 && -f "$agy_log" ]] && grep -q 'panic: runtime error' "$agy_log" 2>/dev/null; then
      failure_kind="agy_panic"
    elif [[ "$bytes" -eq 0 ]] && agy_print_timeout "$out/${slug}.stderr"; then
      # agy hit its own --print-timeout. Report it as a timeout (it is one) so
      # the runlog's timeout-rate warning fires and the operator raises the
      # budget, instead of chasing an auth problem that does not exist.
      failure_kind="print_timeout"
      timed_out="true"
      echo "$slug: agy gave up at its internal print-timeout (${agy_internal_timeout}) with no output — raise --timeout-${slug} if this recurs (Gemini 3.1 Pro at High effort often needs 300-400s)" >&2
    elif [[ $rc -eq 0 && "$bytes" -eq 0 ]] && agy_soft_denied "$agy_log" "$out/${slug}.stderr"; then
      # Gagged, not dead: the seat is authed and in quota, but a tool call it
      # made couldn't be confirmed in headless mode. Distinct remedy from
      # empty_output — see the classification comment above.
      failure_kind="headless_permission_denied"
      rc=5
    elif [[ $rc -eq 0 && "$bytes" -eq 0 ]]; then
      failure_kind="empty_output"
      rc=5
    fi
  elif output_degenerate "$out/${slug}.stdout"; then
    # rc=0 with content that is a repetition loop — same class as glm's
    # PR #25 pass-3 output; do not let it count as a reliable run.
    echo "$slug: output is a degenerate repetition loop (gzip ratio >15:1) — classifying as failed" >&2
    failure_kind="degenerate_output"
    rc=5
  elif output_no_verdict "$out/${slug}.stdout"; then
    # rc=0 with a tiny preamble and no verdict — kimi's PR #2620 class.
    echo "$slug: output is preamble-only (<512B, no severity or clean-verdict marker) — classifying as failed" >&2
    failure_kind="no_verdict_output"
    rc=5
  fi
  local fk_json="null" qr_json="null" rm_json="null"
  [[ -n "$resolved_model" ]] && rm_json="\"$resolved_model\""
  [[ -n "$failure_kind" ]] && fk_json="\"$failure_kind\""
  [[ -n "$quota_resets_in" ]] && qr_json="\"$quota_resets_in\""
  printf '{"exit_code": %d, "duration_s": %d, "timed_out": %s, "output_bytes": %s, "attempt": %d, "timeout_budget_s": %d, "model": "%s", "cli": "agy", "failure_kind": %s, "quota_resets_in": %s, "wall_over_budget": %s, "model_resolved": %s}\n' \
    "$rc" "$((end - start))" "$timed_out" "$bytes" "${CROSS_REVIEW_ATTEMPT:-1}" "$timeout_budget" "$model" "$fk_json" "$qr_json" "$(wall_over_budget "$((end - start))" "$timeout_budget")" "$rm_json" >"$out/${slug}.meta.json"
  cp -f "$out/${slug}.meta.json" "$out/${slug}.attempt${attempt_n}.meta.json" 2>/dev/null || true
  # No fallback: a failed agy lap stays failed (failure_kind says why). Roster
  # rotation compensates across runs; the leaderboard's reliability signal
  # naturally down-weights a quota-dead lap until it recovers.
  return "$rc"
}

run_antigravity() {
  # Fast lap: agy on Gemini 3.5 Flash. Replaces the retired `gemini` CLI slot.
  run_agy_reviewer antigravity "$antigravity_model" "$antigravity_timeout"
}

run_gemini_pro() {
  # Deep lap: agy on Gemini 3.1 Pro. Migrated off the standalone `gemini` CLI in
  # the 2026-06-18 sunset; now shares the agy binary with antigravity.
  run_agy_reviewer gemini-pro "$gemini_pro_model" "$gemini_pro_timeout"
}

# The OpenRouter rotation pool — one thin wrapper per slug so retry_reviewer
# (which takes a function name) can drive each identically.
run_glm()      { run_openrouter_reviewer glm      "$glm_model"      "$glm_timeout"; }
run_deepseek() { run_openrouter_reviewer deepseek "$deepseek_model" "$deepseek_timeout"; }
run_mimo()     { run_openrouter_reviewer mimo     "$mimo_model"     "$mimo_timeout"; }
run_minimax()  { run_openrouter_reviewer minimax  "$minimax_model"  "$minimax_timeout"; }
run_qwen()     { run_openrouter_reviewer qwen     "$qwen_model"     "$qwen_timeout"; }
run_devstral() { run_openrouter_reviewer devstral "$devstral_model" "$devstral_timeout"; }
run_laguna()   { run_openrouter_reviewer laguna   "$laguna_model"   "$laguna_timeout"; }
run_kat()      { run_openrouter_reviewer kat      "$kat_model"      "$kat_timeout"; }
run_north()    { run_openrouter_reviewer north    "$north_model"    "$north_timeout"; }
run_nemotron() { run_openrouter_reviewer nemotron "$nemotron_model" "$nemotron_timeout"; }
run_spark()    { run_openrouter_reviewer spark    "$spark_model"    "$spark_timeout"; }
run_seed()     { run_openrouter_reviewer seed     "$seed_model"     "$seed_timeout"; }
run_grok()     { run_openrouter_reviewer grok     "$grok_model"     "$grok_timeout"; }
# kimi27: same OpenAI-compatible single-turn body, direct Moonshot endpoint +
# key. cli label "moonshot" selects the key source and lands in meta.json.
run_kimi27()   { run_openrouter_reviewer kimi27   "$kimi27_model"   "$kimi27_timeout" \
                   "https://api.moonshot.ai/v1/chat/completions" moonshot; }
# kimi3: same direct-Moonshot lane as kimi27, pointed at the K3 flagship
# (released 2026-07-16; added as a rotation seat 2026-07-18).
run_kimi3()    { run_openrouter_reviewer kimi3    "$kimi3_model"    "$kimi3_timeout" \
                   "https://api.moonshot.ai/v1/chat/completions" moonshot; }

run_kimi() {
  local start end rc
  start=$(date +%s)
  # kimi (Moonshot's Kimi Code CLI) against Moonshot's OpenAI-compatible endpoint.
  #
  # We deliberately run kimi in single-turn, no-tools mode: pipe the full diff
  # inline and instruct the model not to call any tools. Why:
  #   (a) kimi-k2.5's thinking mode + multi-turn tool calls requires threading
  #       `reasoning_content` between turns, and the `openai_legacy` adapter
  #       doesn't preserve it — the second turn fails with "thinking is enabled
  #       but reasoning_content is missing".
  #   (b) Single-turn with thinking-on gives better review quality than
  #       multi-turn with thinking-off.
  #   (c) Code review is fundamentally a single-turn task: the diff IS the
  #       input. codex and antigravity already do the agentic file-roaming;
  #       kimi fills a different niche — deep reasoning on the diff as given.
  #
  # --plan: defense in depth (can't edit files even if it tried).
  # --print: non-interactive. Implies --yolo.
  # --quiet: final assistant message only (drops tool-trace noise).
  # Prompt is piped via stdin, NOT argv. Reasons:
  #   - Linux MAX_ARG_STRLEN is 128KB per argument; argv-based prompts would
  #     crash with E2BIG on any diff larger than that (macOS tolerates ~1MB,
  #     which hid the bug in smoke tests).
  #   - Putting the full diff in argv also exposes it via `ps` to other local
  #     users for the duration of the kimi run — a privacy regression vs.
  #     codex/antigravity which don't have this issue.
  # kimi reads stdin as the prompt when --print is set and no -p is given
  # (confirmed: `echo "..." | kimi --print --quiet` works).
  local diff_summary diff_full diff_line_cap truncation_note truncated
  diff_summary="$(git diff --stat "$base"...HEAD 2>/dev/null | head -50 || true)"
  # Line-based cap (not byte-based). head -c can split mid-codepoint and
  # produce invalid UTF-8; head -n respects line boundaries. 8000 lines keeps
  # us well under k2.5's 256K-token context even for verbose diffs.
  diff_line_cap=8000
  local snapshot_path="" using_snapshot=false
  if snapshot_path="$(snapshot_for kimi)"; then
    using_snapshot=true
  fi
  local total_lines
  if [[ "$using_snapshot" == true ]]; then
    # Pre-built by repomix-handoff and already token-budgeted upstream — skip
    # the line cap and truncation note, pass it whole (SKILL.md step 2.5).
    diff_full="$(cat "$snapshot_path" 2>/dev/null || true)"
    total_lines=0
    truncated=false
    truncation_note=""
  else
    diff_full="$(git diff "$base"...HEAD 2>/dev/null | head -n "$diff_line_cap" || true)"
    total_lines="$(git diff "$base"...HEAD 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${total_lines:-0}" -gt "$diff_line_cap" ]]; then
      truncated=true
      truncation_note="

[WARNING: diff truncated to first $diff_line_cap of $total_lines lines. Your review will be INCOMPLETE — the tail of the patch is not shown. Note this limitation in your findings.]"
    else
      truncated=false
      truncation_note=""
    fi
  fi
  # Wrap the context block in an XML-ish tag rather than a markdown fence.
  # Diffs (and snapshots built from them) can legitimately contain
  # triple-backtick lines (e.g. doc changes that add a fenced code block),
  # which close a markdown fence prematurely and corrupt the prompt.
  # <diff>...</diff> / <snapshot>...</snapshot> has no such collision surface.
  local context_label context_tag_open context_tag_close context_intro
  if [[ "$using_snapshot" == true ]]; then
    # Defuse a literal closing tag inside untrusted snapshot content so it
    # can't close the fence early and inject instructions — same guard as
    # the raw-diff </diff> defuse below (prompt-injection "inj").
    diff_full="${diff_full//<\/snapshot>/< \/snapshot>}"
    context_label="Code context snapshot (from $(basename "$snapshot_path"), pre-built by repomix-handoff):"
    context_tag_open="<snapshot>"
    context_tag_close="</snapshot>"
    context_intro="Base your review ONLY on the code context snapshot below."
  else
    # Defuse a literal </diff> inside untrusted patch content so a malicious
    # diff can't close the fence early and inject instructions.
    diff_full="${diff_full//<\/diff>/< \/diff>}"
    context_label="Full diff:"
    context_tag_open="<diff>"
    context_tag_close="</diff>"
    context_intro="Base your review ONLY on the diff below."
  fi
  local doc_note doc_file_list
  # Uncapped, rename-clean, and source-path-preserving by construction — see
  # doc_narrative_risk's comment for why --name-status, not the capped/
  # brace-compressing --stat display used for the prompt body, nor
  # --name-only (which drops a rename's source path).
  doc_file_list="$(git diff --name-status "$base"...HEAD 2>/dev/null || true)"
  doc_note="$(doc_narrative_note "$doc_file_list")"
  local full_prompt
  full_prompt="$review_prompt

Do NOT use any file-reading or shell tools. ${context_intro}${truncation_note}${doc_note}

Changed files (diff --stat against $base):
$diff_summary

$context_label
$context_tag_open
$diff_full
$context_tag_close

Return your findings as prose, organized by severity (Critical / High / Medium / Low). Reference files and line numbers from the diff headers."

  # kimi-k2.5 thinking mode scales hard with diff size: ~84s p50 on small
  # diffs, but 32-43 min OBSERVED on ~4k-line diffs (2026-07-01, PR #18).
  # Scale the budget rather than truncate the input — quality first; the
  # speed-aware roster draw and incremental re-reviews keep big-diff rounds
  # rare. Empirical rate ≈500s per 1000 diff lines beyond the first 1000.
  local kimi_budget="$kimi_timeout"
  # Scale ONLY when the caller didn't set an explicit cap: --timeout-kimi or
  # --timeout means a smoke run / CI hard cap and must be honored verbatim
  # (codex P2, PR #18 pass 3). Ceiling division per north's pass-3 nit.
  if [[ -z "$timeout_kimi" && -z "$timeout_s" && "${total_lines:-0}" -gt 1000 ]]; then
    kimi_budget=$(( kimi_timeout + 500 * ( (total_lines - 1000 + 999) / 1000 ) ))
    [[ "$kimi_budget" -gt 3000 ]] && kimi_budget=3000
    echo "kimi: ${total_lines}-line diff — budget scaled ${kimi_timeout}s → ${kimi_budget}s" >&2
  fi
  run_with_timeout "$kimi_budget" kimi \
    --plan \
    --print \
    --quiet \
    >"$out/kimi.stdout" 2>"$out/kimi.stderr" <<<"$full_prompt"
  rc=$?
  end=$(date +%s)
  # truncated is reported in metadata so downstream synthesizers don't treat a
  # partial review as complete. Convergent finding from both codex and kimi
  # itself in pass 2 of cross-reviewing this skill.
  local timed_out="false"
  [[ $rc -eq 124 || $rc -eq 137 ]] && timed_out="true"  # 137 = timeout -k SIGKILL escalation (codex P2, PR #18 pass 3)
  local bytes
  bytes=$(output_bytes_of "$out/kimi.stdout")
  local fk_json="null"
  if [[ $rc -eq 0 && "$bytes" -gt 0 ]] && output_degenerate "$out/kimi.stdout"; then
    echo "kimi: output is a degenerate repetition loop (gzip ratio >15:1) — classifying as failed" >&2
    fk_json='"degenerate_output"'
    rc=5
  elif [[ $rc -eq 0 && "$bytes" -gt 0 ]] && output_no_verdict "$out/kimi.stdout"; then
    echo "kimi: output is preamble-only (<512B, no severity or clean-verdict marker) — classifying as failed" >&2
    fk_json='"no_verdict_output"'
    rc=5
  fi
  printf '{"exit_code": %d, "duration_s": %d, "timed_out": %s, "output_bytes": %s, "truncated": %s, "total_diff_lines": %d, "diff_line_cap": %d, "attempt": %d, "timeout_budget_s": %d, "failure_kind": %s, "wall_over_budget": %s}\n' \
    "$rc" "$((end - start))" "$timed_out" "$bytes" "$truncated" "${total_lines:-0}" "$diff_line_cap" "${CROSS_REVIEW_ATTEMPT:-1}" "$kimi_budget" "$fk_json" "$(wall_over_budget "$((end - start))" "$kimi_budget")" \
    >"$out/kimi.meta.json"
  return "$rc"
}

pids=()
ran=()

# Clean up background reviewers on interrupt. Without this, Ctrl+C on the
# orchestrator exits the parent shell but leaves codex/agy/kimi orphaned,
# burning tokens against APIs nobody is reading any more.
cleanup_pids() {
  [[ ${#pids[@]} -gt 0 ]] || return 0
  local p
  for p in "${pids[@]}"; do
    # Kill the subshell's children first (the `timeout`/CLI process); coreutils
    # `timeout` then signals the actual reviewer binary. Killing only the
    # subshell (as before) left codex/agy/kimi reparented and burning tokens on
    # a programmatic SIGTERM (Ctrl+C happened to work via the tty process group).
    pkill -P "$p" 2>/dev/null || true
    kill "$p" 2>/dev/null || true
  done
}

# ---- agy shell gate ---------------------------------------------------------
# agy ≥1.1.3 soft-denies any "command" permission it cannot prompt for in
# headless mode, and ONE soft-denied command ends the conversation at 0 bytes —
# the whole review is lost. Both Gemini laps reliably reach for a shell
# (`git rev-parse`, `find`, `printf | jq`, `git diff > /tmp/x.patch`,
# `bash tests/run_tests.sh` were all observed on 2026-07-31), so a
# settings.json allow-list is whack-a-mole: the first command outside it is
# fatal. Instead we install a PreToolUse hook that answers every `run_command`
# with allow + an overwrite that swaps the command line for a harmless `echo`.
# No permission is ever requested (the run survives) and no reviewer-authored
# command ever executes (the read-only guarantee holds, unlike
# --dangerously-skip-permissions).
#
# agy discovers hooks at <workspace-root>/.agents/hooks.json ONLY — a temp cwd
# is not scanned (verified: "loaded 0 named hooks") — so the file has to live in
# the repo under review for the duration of the laps. It is installed once
# before dispatch (both laps run concurrently and share it) and removed by the
# same trap that reaps the reviewer pids.
agy_gate_repo_root=""
agy_gate_file=""
agy_gate_backup=""
agy_gate_made_dir=""
agy_gate_lockdir=""
agy_gate_holders=""

# The gate file is shared repo state, so install/remove are reference-counted
# under a lock. Without that, two runs against the SAME repo corrupt each other:
# run A installs, run B backs up A's temporary gate as if it were the user's
# file, A exits and restores the real original (killing B's gate mid-review),
# then B exits and restores A's temporary gate PERMANENTLY — leaving a stale
# hook that rewrites every command to `echo` for every agy session in that repo.
# (codex P2, PR #41 pass 1. Ordinary rounds each get their own worktree so the
# repo root differs, but direct invocations and splitstream shards sharing a
# checkout are exposed.) The lock is an atomic mkdir — flock is not portable to
# the macOS default bash. The holders file names the live runs; the last one out
# restores. Both files live beside hooks.json so any holder can finish the job
# if the run that installed died.
_agy_gate_lock() {
  local n=0
  until mkdir "$agy_gate_lockdir" 2>/dev/null; do
    # Reclaim a lock abandoned by a crashed run rather than blocking forever.
    if [[ -n "$(find "$agy_gate_lockdir" -maxdepth 0 -mmin +10 2>/dev/null)" ]]; then
      # Rename, then delete. `mv` of a directory is atomic, so when two runs
      # both see the same stale lock exactly one wins the rename; the loser
      # falls back to waiting instead of deleting a lock the winner has just
      # re-taken (kimi Medium, PR #41 pass 2). Deleting in place would have
      # that second run remove a live lock.
      if mv "$agy_gate_lockdir" "$agy_gate_lockdir.stale.$$" 2>/dev/null; then
        rm -rf "$agy_gate_lockdir.stale.$$" 2>/dev/null || true
      fi
      continue
    fi
    sleep 0.2
    n=$((n + 1))
    [[ $n -gt 150 ]] && return 1   # 30s
  done
  return 0
}

_agy_gate_unlock() { rmdir "$agy_gate_lockdir" 2>/dev/null || true; }

# Drop PIDs whose process is gone — a crashed holder must not pin the gate in
# the repo forever.
_agy_gate_live_holders() {
  local pid
  while read -r pid; do
    [[ -n "$pid" ]] || continue
    kill -0 "$pid" 2>/dev/null && printf '%s\n' "$pid"
  done <"$1" 2>/dev/null
}

# Emit the gate hooks.json. With jq (always, not just when merging — the
# heredoc path used to interpolate $gate into JSON unescaped, so a path with a
# quote or backslash produced invalid JSON and the gate silently failed to
# install: kimi27 Medium, PR #41 pass 1). The heredoc survives only as the
# no-jq fallback, where that limitation is unavoidable and now documented.
_agy_gate_write() {
  local gate="$1" dest="$2" merge_from="${3:-}"
  local rule='{"cross-review-shell-gate": {"PreToolUse": [{"matcher": "run_command", "hooks": [{"type": "command", "command": $cmd, "timeout": 10}]}]}}'
  if command -v jq >/dev/null 2>&1; then
    if [[ -n "$merge_from" && -f "$merge_from" ]]; then
      jq --arg cmd "$gate" ". + $rule" "$merge_from" >"$dest" 2>/dev/null && return 0
      cp "$merge_from" "$dest" 2>/dev/null || true
      return 1
    fi
    jq -n --arg cmd "$gate" "$rule" >"$dest" 2>/dev/null && return 0
    return 1
  fi
  case "$gate" in
    *'"'*|*'\'*)
      echo "WARN: no jq and the gate path contains a quote or backslash ($gate) — cannot emit valid hooks.json; the agy laps will fail with headless_permission_denied. Install jq." >&2
      return 1 ;;
  esac
  cat >"$dest" <<EOF
{
  "cross-review-shell-gate": {
    "PreToolUse": [
      {
        "matcher": "run_command",
        "hooks": [
          { "type": "command", "command": "$gate", "timeout": 10 }
        ]
      }
    ]
  }
}
EOF
}

install_agy_shell_gate() {
  local gate
  gate="$script_dir/agy_shell_gate.sh"
  if [[ ! -x "$gate" ]]; then
    echo "agy shell gate not found/executable at $gate — the agy laps will die on their first tool call" >&2
    return 0
  fi
  # The gate rewrites every command to `echo`, but agy still permission-checks
  # the rewritten line — so `echo` has to be allow-listed or the laps die at 0
  # bytes exactly as before. BOTH rule kinds are required: agy asks for
  # `command(<target>)` for an ordinary shell step and `unsandboxed(<target>)`
  # when the model escalates outside the sandbox. Missing the second one is
  # what produced the "gemini-pro fails, retry sometimes works" flake — the
  # escalation is the model's choice, so it only bites some runs (verified
  # 2026-08-03: stderr `a tool required the "unsandboxed" permission`). Warn
  # loudly rather than editing a global config behind the user's back.
  local agy_settings="$HOME/.gemini/antigravity-cli/settings.json"
  if [[ -f "$agy_settings" ]]; then
    local missing_rules=""
    grep -q 'command(echo)' "$agy_settings" 2>/dev/null || missing_rules="command(echo)"
    if ! grep -q 'unsandboxed(echo)' "$agy_settings" 2>/dev/null; then
      missing_rules="${missing_rules:+$missing_rules, }unsandboxed(echo)"
    fi
    if [[ -n "$missing_rules" ]]; then
      echo "WARN: $agy_settings is missing permissions.allow rule(s): $missing_rules — agy laps will fail with failure_kind=headless_permission_denied. Add: {\"permissions\": {\"allow\": [\"command(echo)\", \"unsandboxed(echo)\"]}}" >&2
    fi
  fi
  agy_gate_repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  local agents_dir="$agy_gate_repo_root/.agents"
  agy_gate_file="$agents_dir/hooks.json"
  if [[ ! -d "$agents_dir" ]]; then
    mkdir -p "$agents_dir" 2>/dev/null || { agy_gate_file=""; return 0; }
    agy_gate_made_dir=1
  fi
  agy_gate_lockdir="$agents_dir/.cross-review-gate.lock"
  agy_gate_holders="$agents_dir/.cross-review-gate.holders"
  agy_gate_backup="$agents_dir/.cross-review-gate.orig"

  if ! _agy_gate_lock; then
    echo "WARN: another cross-review run has held the agy gate lock at $agy_gate_lockdir for 30s — skipping gate install; the agy laps in this round will likely fail with headless_permission_denied" >&2
    agy_gate_file=""
    return 0
  fi

  local live=""
  [[ -f "$agy_gate_holders" ]] && live="$(_agy_gate_live_holders "$agy_gate_holders")"
  if [[ -z "$live" ]]; then
    # First live holder. THE ORDER MATTERS: when every registered holder has
    # crashed, hooks.json is that dead run's GATE and .orig is the user's real
    # file. Treating the on-disk hooks.json as the original there would copy the
    # gate over the only backup, and this run's own cleanup would then restore
    # the gate permanently — reintroducing the exact bug the refcount fixes
    # (codex P1, PR #41 pass 2). An existing .orig always wins.
    # Which file is the user's? Decide from CONTENT, not from the mere presence
    # of a backup: after a crash the user may have repaired hooks.json
    # themselves, and blindly preferring the orphaned .orig would restore the
    # older file over their newer one (codex P1, PR #41 pass 3). The on-disk
    # file is the stale gate only if it still carries our rule.
    local current_is_gate=""
    if [[ -f "$agy_gate_file" ]] && grep -q 'cross-review-shell-gate' "$agy_gate_file" 2>/dev/null; then
      current_is_gate=1
    fi
    if [[ -f "$agy_gate_backup" && ( -n "$current_is_gate" || ! -f "$agy_gate_file" ) ]]; then
      # Crashed holder: hooks.json is its gate (or it removed the file), so
      # .orig is still the user's real content. Keep the backup as-is.
      _agy_gate_write "$gate" "$agy_gate_file" "$agy_gate_backup" || \
        echo "WARN: could not install the agy shell gate at $agy_gate_file — the agy laps will fail with headless_permission_denied" >&2
    elif [[ -f "$agy_gate_file" ]]; then
      # The current file is the user's — including the case where they edited
      # it after a crash left an orphaned .orig behind. It becomes the original.
      cp "$agy_gate_file" "$agy_gate_backup" || { _agy_gate_unlock; agy_gate_file=""; return 0; }
      _agy_gate_write "$gate" "$agy_gate_file" "$agy_gate_backup" || \
        echo "WARN: could not install the agy shell gate at $agy_gate_file — the agy laps will fail with headless_permission_denied" >&2
    else
      # A failed write here is silent otherwise, and an absent gate means every
      # agy lap dies at 0 bytes (deepseek Medium, PR #41 pass 2).
      _agy_gate_write "$gate" "$agy_gate_file" || \
        echo "WARN: could not install the agy shell gate at $agy_gate_file — the agy laps will fail with headless_permission_denied" >&2
    fi
  fi
  printf '%s\n%s\n' "$live" "$$" | grep -v '^$' >"$agy_gate_holders" 2>/dev/null || true
  _agy_gate_unlock
}

remove_agy_shell_gate() {
  [[ -n "$agy_gate_file" ]] || return 0
  local file="$agy_gate_file"
  agy_gate_file=""   # idempotent: a second call is a no-op even if we bail below
  _agy_gate_lock || {
    echo "WARN: could not take the agy gate lock to clean up $file — remove it by hand if it is still there" >&2
    return 0
  }
  local live="" me="$$"
  [[ -f "$agy_gate_holders" ]] && live="$(_agy_gate_live_holders "$agy_gate_holders" | grep -v "^${me}$" || true)"
  if [[ -n "$live" ]]; then
    # Another run is still reviewing — leave its gate alone.
    printf '%s\n' "$live" >"$agy_gate_holders" 2>/dev/null || true
    _agy_gate_unlock
    return 0
  fi
  rm -f "$agy_gate_holders" 2>/dev/null || true
  if [[ -f "$agy_gate_backup" ]]; then
    # A failed restore silently leaves the user's hooks.json replaced by the
    # gate, so fall back to cp and say so rather than swallowing it (kimi Low,
    # PR #41 pass 1).
    if ! mv "$agy_gate_backup" "$file" 2>/dev/null; then
      cp "$agy_gate_backup" "$file" 2>/dev/null && rm -f "$agy_gate_backup" 2>/dev/null || \
        echo "WARN: could not restore your original $file — a copy is at $agy_gate_backup" >&2
    fi
  else
    rm -f "$file" 2>/dev/null || true
    [[ -n "$agy_gate_made_dir" ]] && rmdir "$agy_gate_repo_root/.agents" 2>/dev/null || true
  fi
  _agy_gate_unlock
}

cleanup_run() {
  cleanup_pids
  remove_agy_shell_gate
}
trap cleanup_run EXIT INT TERM

IFS=',' read -ra raw_requested <<<"$reviewers"
# Dedup. Without this, `--reviewers codex,codex` spawns two processes writing
# to the same $out/codex.* files concurrently, producing interleaved garbage.
# Bash 3.2 (macOS default /bin/bash) lacks associative arrays — use a
# delimited string instead.
requested=()
seen=","
for r in "${raw_requested[@]}"; do
  # Strip surrounding whitespace — `--reviewers "codex, antigravity"` with a
  # space after the comma used to produce " antigravity" which failed to
  # match any case.
  r="${r#"${r%%[![:space:]]*}"}"
  r="${r%"${r##*[![:space:]]}"}"
  [[ -z "$r" ]] && continue
  [[ "$seen" == *",$r,"* ]] && continue
  seen="$seen$r,"
  requested+=("$r")
done

# Stagger spawns by 2s. Launching all reviewers at t=0 means concurrent
# auth handshakes and simultaneous first requests against shared upstream
# endpoints, which reliably flakes the Gemini-family and kimi clients.
# A small offset lets each initial handshake settle before the next starts.
# NOTE: antigravity + gemini-pro both hit Google via agy — the stagger matters
# more now that two reviewers share one provider, auth state, and rate limit.
stagger_s=2

# Warn about model slugs that have been delisted upstream before spending a
# round on them. Advisory and cached (24h) — a dead slug otherwise shows up as a
# 1-second 404 that reads like reviewer flakiness rather than stale config.
for r in "${requested[@]}"; do
  case "$r" in
    glm|deepseek|mimo|minimax|qwen|devstral|laguna|kat|north|nemotron|spark|seed|grok)
      bash "$script_dir/validate_or_models.sh" --no-fetch 2>&1 >/dev/null | head -5 >&2 || true
      break ;;
  esac
done

# Install the PreToolUse gate before dispatch if either Gemini lap is in the
# roster — both laps run concurrently and share the one hooks.json.
for r in "${requested[@]}"; do
  if [[ "$r" == "antigravity" || "$r" == "gemini-pro" ]] && command -v agy >/dev/null 2>&1; then
    install_agy_shell_gate
    break
  fi
done

for r in "${requested[@]}"; do
  case "$r" in
    codex)
      if command -v codex >/dev/null 2>&1; then
        [[ ${#pids[@]} -gt 0 ]] && sleep "$stagger_s"
        run_codex &
        pids+=($!)
        ran+=("codex")
      else
        echo "codex not installed — skipping" >&2
      fi
      ;;
    antigravity)
      if command -v agy >/dev/null 2>&1; then
        [[ ${#pids[@]} -gt 0 ]] && sleep "$stagger_s"
        retry_reviewer run_antigravity antigravity &
        pids+=($!)
        ran+=("antigravity")
      else
        echo "antigravity (agy CLI) not installed — skipping. Install: curl -fsSL https://antigravity.google/cli/install.sh | bash" >&2
      fi
      ;;
    gemini-pro)
      if command -v agy >/dev/null 2>&1; then
        [[ ${#pids[@]} -gt 0 ]] && sleep "$stagger_s"
        retry_reviewer run_gemini_pro gemini-pro &
        pids+=($!)
        ran+=("gemini-pro")
      else
        echo "gemini-pro (agy CLI on Gemini 3.1 Pro) not installed — skipping. Install: curl -fsSL https://antigravity.google/cli/install.sh | bash" >&2
      fi
      ;;
    kimi)
      if command -v kimi >/dev/null 2>&1; then
        [[ ${#pids[@]} -gt 0 ]] && sleep "$stagger_s"
        retry_reviewer run_kimi kimi &
        pids+=($!)
        ran+=("kimi")
      else
        echo "kimi not installed — skipping" >&2
      fi
      ;;
    glm|deepseek|mimo|minimax|qwen|devstral|laguna|kat|north|nemotron|spark|seed|grok)
      if ! command -v curl >/dev/null 2>&1; then
        echo "$r: curl not available — skipping" >&2
      elif openrouter_key >/dev/null 2>&1; then
        [[ ${#pids[@]} -gt 0 ]] && sleep "$stagger_s"
        retry_reviewer "run_$r" "$r" &
        pids+=($!)
        ran+=("$r")
      else
        echo "$r (OpenRouter reviewer) unavailable — set OPENROUTER_API_KEY or put the key in ~/.config/openrouter/key. Skipping." >&2
      fi
      ;;
    kimi27)
      if ! command -v curl >/dev/null 2>&1; then
        echo "$r: curl not available — skipping" >&2
      elif moonshot_key >/dev/null 2>&1; then
        [[ ${#pids[@]} -gt 0 ]] && sleep "$stagger_s"
        retry_reviewer run_kimi27 kimi27 &
        pids+=($!)
        ran+=("kimi27")
      else
        echo "kimi27 (direct-Moonshot reviewer) unavailable — set MOONSHOT_API_KEY or put the key in ~/.config/moonshot/key. Skipping." >&2
      fi
      ;;
    kimi3)
      if ! command -v curl >/dev/null 2>&1; then
        echo "$r: curl not available — skipping" >&2
      elif moonshot_key >/dev/null 2>&1; then
        [[ ${#pids[@]} -gt 0 ]] && sleep "$stagger_s"
        retry_reviewer run_kimi3 kimi3 &
        pids+=($!)
        ran+=("kimi3")
      else
        echo "kimi3 (direct-Moonshot reviewer) unavailable — set MOONSHOT_API_KEY or put the key in ~/.config/moonshot/key. Skipping." >&2
      fi
      ;;
    *)
      echo "unknown reviewer: $r" >&2
      ;;
  esac
done

if [[ ${#pids[@]} -eq 0 ]]; then
  echo "no reviewers available or requested" >&2
  exit 1
fi

# Wait for each; track individual status. Since run_codex/run_antigravity/
# run_gemini_pro/run_kimi all `return "$rc"`, wait sees the real reviewer
# exit code.
any_ok=0
for i in "${!pids[@]}"; do
  pid="${pids[$i]}"
  name="${ran[$i]}"
  if wait "$pid"; then
    any_ok=1
    echo "$name: ok" >&2
  else
    # stderr file location varies per reviewer; codex merges stderr into
    # stdout. Point the user at the right file.
    case "$name" in
      codex)       echo "$name: failed (see $out/codex.stdout and $out/codex.meta.json)" >&2 ;;
      antigravity|gemini-pro)
        # stdout/stderr are usually EMPTY on agy failures — meta.json's
        # failure_kind and the .agy.log tail are where the answer lives.
        echo "$name: failed (check failure_kind in $out/$name.meta.json; agy's own log: $out/$name.agy.log)" >&2 ;;
      kimi)        echo "$name: failed (see $out/kimi.stderr and $out/kimi.meta.json)" >&2 ;;
      glm|deepseek|mimo|minimax|qwen|devstral|laguna|kat|north|nemotron|spark|seed|grok|kimi27|kimi3)
        echo "$name: failed (see $out/$name.stderr, $out/$name.response.json, $out/$name.meta.json)" >&2 ;;
      *)           echo "$name: failed (see $out/$name.* )" >&2 ;;
    esac
  fi
done

[[ "$any_ok" -eq 1 ]] || exit 1
exit 0
