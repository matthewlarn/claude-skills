#!/usr/bin/env bash
# analyze_runlog.sh — read runlog.jsonl and emit a per-reviewer reliability
# report plus tuning suggestions. Read by:
#   - SKILL.md step 1.5 (pre-run check, --recent <n>) — surfaces warnings
#     when a reviewer's recent timeout rate or empty-output rate is high.
#   - /cross-review --self-check (--mode report) — full health snapshot,
#     written for humans to scan and humans/Claude to use as input to
#     editing reviewer_profiles.json.
#
# Never edits reviewer_profiles.json itself — surfaces suggestions only.
# The intentional manual-confirm step is the same pattern splitstream uses
# for its pre-flight table.
#
# Usage:
#   analyze_runlog.sh [--recent <n>] [--mode warn|report] [--quiet]
#
#   --recent <n>      window (default 20). Older entries ignored.
#   --mode warn       emit one-line warnings when a reviewer is degraded
#                     (timeout rate >30% OR empty-output rate >40% OR
#                     reliability <60% over the window). Default.
#   --mode report     emit the full report (reliability %, p50/p95 duration,
#                     timeout rate, empty rate, suggested timeout edits).
#   --quiet           silence informational lines; warnings/report still print.
#
# Reads only the structured Phase-2 entries (those with a `reviewers` field).
# Hand-curated legacy entries are silently skipped — they don't have the
# fields needed for telemetry math.

set -uo pipefail

recent=20
mode="warn"
quiet=0

need_val() {
  # set -u + missing flag value crashes with raw "$2: unbound variable" instead
  # of a usage hint. Check argc before consuming the next positional.
  local flag="$1"
  local argc="$2"
  if [[ "$argc" -lt 2 ]]; then
    echo "missing value for $flag" >&2
    exit 2
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --recent) need_val --recent "$#"; recent="$2"; shift 2 ;;
    --mode)   need_val --mode   "$#"; mode="$2";   shift 2 ;;
    --quiet)  quiet=1;     shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "analyze_runlog: jq required (brew install jq)" >&2
  exit 1
fi

skill_dir="$(cd "$(dirname "$0")/.." && pwd)"
runlog="${CROSS_REVIEW_RUNLOG:-$skill_dir/runlog.jsonl}"
profile_file="$skill_dir/references/reviewer_profiles.json"

if [[ ! -f "$runlog" ]]; then
  [[ "$quiet" -eq 0 ]] && echo "no runlog at $runlog" >&2
  exit 0
fi

# Filter to structured entries (have .reviewers), keep last $recent.
# Legacy hand-curated entries don't have .reviewers and are skipped.
structured=$(jq -c 'select(.reviewers != null)' "$runlog" 2>/dev/null | tail -n "$recent")
n_entries=$(printf '%s\n' "$structured" | grep -c '^.' || true)

if [[ "$n_entries" -eq 0 ]]; then
  [[ "$quiet" -eq 0 ]] && echo "analyze_runlog: no structured entries yet (need at least 1 Phase-2 run)" >&2
  exit 0
fi

# Per-reviewer aggregation.
# For each reviewer in {codex, antigravity, gemini-pro, kimi}, compute:
#   total: number of times the reviewer was attempted (status != "skipped")
#   ok: status == "ok"
#   timed_out: status == "timed_out"
#   empty: status == "empty" (ran rc=0 but produced 0 bytes)
#   failed: status == "failed"
#   p50_duration, p95_duration, current_timeout
analyze_reviewer() {
  local r="$1"
  printf '%s\n' "$structured" | jq -s --arg r "$r" '
    map(.reviewers[$r] // {status:"skipped"}) as $rs
    | ($rs | map(select(.status != "skipped"))) as $attempts
    | ($attempts | length) as $total
    | ($attempts | map(select(.status == "ok"))        | length) as $ok
    | ($attempts | map(select(.status == "timed_out")) | length) as $to
    | ($attempts | map(select(.status == "empty"))     | length) as $empty
    | ($attempts | map(select(.status == "failed"))    | length) as $failed
    | ($attempts | map(select(.status == "quota"))     | length) as $quota
    # Sleep-suspect filter (2026-07-03): when the machine sleeps mid-run,
    # gtimeout/curl timers freeze but the wall-clock duration_s keeps counting,
    # so a sample can log far past its ENFORCED budget (codex: 1024s vs 300s,
    # rc=0). Such samples carry no signal about the reviewer — learning from
    # them made the analyzer suggest bumping every timeout. Anything >60s over
    # budget is suspect (TERM/KILL lag is ≤10s; curl fires at max-time exactly).
    # Budget 0/missing = legacy entry, kept.
    | ($attempts | map(select(((.timeout_budget_s // 0) == 0)
                              or ((.duration_s // 0) <= ((.timeout_budget_s // 0) + 60))))) as $clean
    | (($attempts | length) - ($clean | length)) as $suspect
    | ($clean | length) as $cn
    | ($clean | map(select(.status == "timed_out")) | length) as $clean_to
    | ($clean | map(.duration_s // 0) | sort) as $durs
    | ($durs | length) as $dn
    | (if $dn == 0 then 0 else $durs[($dn / 2 | floor)] end) as $p50
    | (if $dn == 0 then 0 else $durs[($dn * 0.95 | floor) | (if . >= $dn then $dn - 1 else . end)] end) as $p95
    | ($attempts | map(.timeout_budget_s // 0) | max // 0) as $cur_to
    | {
        reviewer: $r,
        total: $total,
        ok: $ok,
        timed_out: $to,
        empty: $empty,
        failed: $failed,
        quota: $quota,
        sleep_suspect: $suspect,
        to_suspect: ($to - $clean_to),
        reliability: (if $total == 0 then null else (($ok * 100) / $total | floor) end),
        timeout_rate: (if $total == 0 then null else (($to * 100) / $total | floor) end),
        clean_timeout_rate: (if $cn == 0 then null else (($clean_to * 100) / $cn | floor) end),
        empty_rate:   (if $total == 0 then null else (($empty * 100) / $total | floor) end),
        p50_duration_s: $p50,
        p95_duration_s: $p95,
        current_timeout_budget_s: $cur_to
      }
  '
}

# Reviewer fleet. antigravity + gemini-pro both ride the agy CLI (Gemini Flash
# and Pro laps respectively); codex, kimi, and the OpenRouter pool (glm,
# deepseek, mimo, minimax, qwen, devstral, laguna, kat, north, nemotron,
# spark, seed, grok) are independent providers.
# Keep in sync with run_reviewers.sh's dispatch and leaderboard.sh. Bash 3.2
# (macOS /bin/bash) has no associative arrays — use a parallel indexed array.
REVIEWERS=(codex antigravity gemini-pro kimi glm deepseek mimo minimax qwen devstral laguna kat north nemotron spark seed grok kimi27 kimi3)
reviewer_stats=()
for _r in "${REVIEWERS[@]}"; do
  reviewer_stats+=("$(analyze_reviewer "$_r")")
done

# Suggest timeout bump if p95 is within 10% of current budget OR timeout rate >20%.
# Both signals use the sleep-clean sample set: p50/p95 are already clean-only,
# and clean_timeout_rate excludes sleep-killed timeouts — a round the machine
# slept through must not drive tuning (see the sleep-suspect filter above).
suggest_timeout_bump() {
  local stats="$1"
  echo "$stats" | jq -r '
    if .total == 0 or .current_timeout_budget_s == 0 then empty
    elif .clean_timeout_rate == null then
      (if .sleep_suspect > 0 then
        "  NOTE: \(.reviewer): all \(.sleep_suspect) sample(s) in the window are sleep-suspect (wall clock overran the enforced budget) — no tuning signal; re-evaluate after clean rounds"
      else empty end)
    elif .clean_timeout_rate >= 20 then
      "  SUGGEST: bump \(.reviewer).timeout_s from \(.current_timeout_budget_s) → \(.current_timeout_budget_s + 200) (timeout rate \(.clean_timeout_rate)% over window, sleep-suspect samples excluded)"
    elif (.p95_duration_s * 10) >= (.current_timeout_budget_s * 9) then
      "  SUGGEST: bump \(.reviewer).timeout_s from \(.current_timeout_budget_s) → \(.current_timeout_budget_s + 100) (p95 \(.p95_duration_s)s within 10% of budget)"
    else empty end
  '
}

# Warning thresholds. Quota outranks the generic warnings: it has a specific
# remedy (wait for the reset / rely on the OpenRouter fallback), and its
# failures would otherwise masquerade as a reliability problem worth "tuning".
emit_warning() {
  local stats="$1"
  # NOTE: `.reviewer as $rv` is load-bearing. The old code wrote
  # `["codex",…] | index(.reviewer)` — after the pipe `.` is the array
  # literal, so jq crashed ("Cannot index array with string") for exactly the
  # reviewers degraded enough to reach that branch, and warn mode reported
  # "all reviewers nominal" over a 50%-timeout window (caught 2026-07-03).
  echo "$stats" | jq -r '
    .reviewer as $rv
    | (if (.to_suspect // 0) > 0 then
         " [\(.to_suspect) of \(.timed_out) timeouts are sleep-suspect — wall clock overran the enforced budget, machine likely slept mid-run; discount before tuning]"
       else "" end) as $sleep_note
    | if .total < 3 then empty   # not enough data
    elif (.quota // 0) > 0 then
      "  WARN: \($rv) hit the shared Gemini Individual quota in \(.quota) of last \(.total) runs — not a timeout/auth issue; the lap drops out until the quota resets (ETA in the latest run agy.quota_exhausted / .agy.log). No fallback by policy; roster rotation covers the gap"
    # Gate the timeout WARN on the sleep-CLEAN rate, matching
    # suggest_timeout_bump: a window whose timeouts are all sleep-killed must
    # not demand action (minimax finding, PR #27 pass 1). When the raw rate is
    # high but the clean rate is not, emit an informational NOTE instead so
    # the degradation is visible without pretending it needs tuning.
    # (No apostrophes in these comments — they live inside a bash single-quoted
    # jq program and would terminate it.)
    elif (.clean_timeout_rate // 0) > 30 then
      (if (["codex","antigravity","gemini-pro","kimi","glm"] | index($rv)) != null
       then "  WARN: \($rv) timed out \(.clean_timeout_rate)% of last \(.total) runs (p95 \(.p95_duration_s)s, budget \(.current_timeout_budget_s)s) — consider --timeout-\($rv) \(.current_timeout_budget_s + 200)\($sleep_note)"
       # Only 5 reviewers have per-reviewer CLI flags; suggesting a nonexistent
       # --timeout-<r> made the next run exit 2 (fugu finding, PR #18 pass 1).
       else "  WARN: \($rv) timed out \(.clean_timeout_rate)% of last \(.total) runs (p95 \(.p95_duration_s)s, budget \(.current_timeout_budget_s)s) — bump its timeout_s in reviewer_profiles.json (or pass global --timeout for a one-off)\($sleep_note)"
       end)
    elif .timeout_rate > 30 and (.to_suspect // 0) > 0 then
      "  NOTE: \($rv) raw timeout rate \(.timeout_rate)% over last \(.total) runs is sleep-contaminated (clean rate \(.clean_timeout_rate // 0)%) — no tuning action; re-evaluate after clean rounds"
    elif .empty_rate > 40 then
      "  WARN: \($rv) empty-output rate \(.empty_rate)% over last \(.total) runs — not a timeout fix. Read failure_kind in meta.json before acting: quota_exhausted → wait for reset; headless_permission_denied → prompt-shape bug in this repo, the seat is healthy, do NOT retire it; empty_output → re-run `agy login`"
    elif .reliability != null and .reliability < 60 then
      "  WARN: \($rv) reliability \(.reliability)% over last \(.total) runs (ok=\(.ok), timeout=\(.timed_out), empty=\(.empty), failed=\(.failed), quota=\(.quota // 0))\($sleep_note)"
    else empty end
  '
}

case "$mode" in
  warn)
    out=$(for stats in "${reviewer_stats[@]}"; do emit_warning "$stats"; done)
    if [[ -n "$out" ]]; then
      echo "── cross-review pre-run check (last $n_entries runs) ──"
      echo "$out"
      echo "──"
    elif [[ "$quiet" -eq 0 ]]; then
      echo "cross-review pre-run check: all reviewers nominal over last $n_entries runs" >&2
    fi
    ;;
  report)
    echo "── cross-review reviewer health (last $n_entries runs) ──"
    for stats in "${reviewer_stats[@]}"; do
      echo "$stats" | jq -r '
        if .total == 0 then "  \(.reviewer): no data in window"
        else
          "  \(.reviewer): reliability=\(.reliability // "—")%  ok=\(.ok)/\(.total)  timed_out=\(.timed_out)  empty=\(.empty)  failed=\(.failed)  quota=\(.quota // 0)  p50=\(.p50_duration_s)s  p95=\(.p95_duration_s)s  budget=\(.current_timeout_budget_s)s\(if (.sleep_suspect // 0) > 0 then "  sleep_suspect=\(.sleep_suspect)" else "" end)"
        end'
    done
    echo ""
    echo "── tuning suggestions ──"
    suggestions=$({
      for stats in "${reviewer_stats[@]}"; do suggest_timeout_bump "$stats"; done
      for stats in "${reviewer_stats[@]}"; do emit_warning "$stats"; done
    } | sort -u)
    if [[ -n "$suggestions" ]]; then
      echo "$suggestions"
      echo ""
      echo "Edit $profile_file to apply (or pass per-run flags via --timeout-<reviewer>)."
    else
      echo "  none — all reviewers within tolerance"
    fi
    echo "──"
    ;;
  *)
    echo "unknown mode: $mode (use warn|report)" >&2
    exit 2
    ;;
esac
