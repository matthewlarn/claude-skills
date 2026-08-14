#!/usr/bin/env bash
# append_runlog.sh — emit a single structured JSONL entry summarizing a
# cross-review pass to ~/.claude/skills/cross-review/runlog.jsonl.
#
# Called from SKILL.md step 9.5 (after the report-back block, before worktree
# teardown). The SKILL flow already knows the verdict, top finding, and pass
# number — the wrapper-produced meta.json files supply per-reviewer telemetry.
#
# Usage:
#   append_runlog.sh \
#     --run-dir <path>             # produced by worktree.sh start; contains
#                                  # codex.meta.json, antigravity.meta.json,
#                                  # gemini-pro.meta.json, kimi.meta.json, etc.
#     --project <name>
#     --base <branch>
#     --pr <number|->              # use - for no PR (branch-only run)
#     --pass <n>
#     --verdict <CLEAN|FIXES_APPLIED|NEEDS_DECISION|BLOCKED>
#     --convergent <n>
#     --top "<file:line — title [severity][sources]>"
#     [--diff-files <n>]
#     [--diff-lines <n>]
#     [--notes "<one-liner>"]
#     [--findings <findings.verified.json>]
#       When given, each reviewer entry is enriched with findings_total /
#       findings_convergent / findings_dropped, computed from the findings'
#       `sources` arrays and `factcheck` verdicts. "Convergent" = the finding's
#       sources span MORE THAN ONE provider (per the provider map below) — the
#       cross-provider precision proxy leaderboard.sh scores on. Pass the most
#       verified findings file you have (post-anchor, post-factcheck).
#     [--run-id <id>]
#       Joins this runlog entry to any finding_events.jsonl events from the
#       same pass (run_id = basename of the run-dir; see worktree.sh). Omit
#       and the entry has no `run_id` key at all — not even null — so old
#       tooling reading past entries sees nothing new.
#     [--roster-decision <json-file>]
#       select_roster.sh --json output for this pass's draw, attached
#       verbatim as `roster_decision`. Never blocks the append: a
#       missing/unreadable file just warns to stderr and omits the key.
#
# Both --run-id and --roster-decision are purely additive telemetry — leave
# either off and this entry is byte-identical to what today's callers already
# produce. Neither is read by leaderboard.sh or select_roster.sh yet.
# Schema is documented in plans/the-miss-on-pr-eager-pond.md (Phase 2).
# Additive — old hand-curated entries in the runlog remain valid.

set -uo pipefail

run_dir=""
project=""
base=""
pr=""
pass=""
verdict=""
convergent="0"
top=""
diff_files=""
diff_lines=""
notes=""
findings_file=""
run_id=""
roster_decision_file=""

need_val() {
  if [[ "$2" -lt 2 ]]; then
    echo "missing value for $1" >&2
    exit 2
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir)    need_val "$1" "$#"; run_dir="$2";    shift 2 ;;
    --project)    need_val "$1" "$#"; project="$2";    shift 2 ;;
    --base)       need_val "$1" "$#"; base="$2";       shift 2 ;;
    --pr)         need_val "$1" "$#"; pr="$2";         shift 2 ;;
    --pass)       need_val "$1" "$#"; pass="$2";       shift 2 ;;
    --verdict)    need_val "$1" "$#"; verdict="$2";    shift 2 ;;
    --convergent) need_val "$1" "$#"; convergent="$2"; shift 2 ;;
    --top)        need_val "$1" "$#"; top="$2";        shift 2 ;;
    --diff-files) need_val "$1" "$#"; diff_files="$2"; shift 2 ;;
    --diff-lines) need_val "$1" "$#"; diff_lines="$2"; shift 2 ;;
    --notes)      need_val "$1" "$#"; notes="$2";      shift 2 ;;
    --findings)   need_val "$1" "$#"; findings_file="$2"; shift 2 ;;
    --run-id)     need_val "$1" "$#"; run_id="$2";     shift 2 ;;
    --roster-decision) need_val "$1" "$#"; roster_decision_file="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

for required in run_dir project base pr pass verdict; do
  if [[ -z "${!required}" ]]; then
    echo "usage: $0 --run-dir <p> --project <n> --base <b> --pr <num|-> --pass <n> --verdict <v> [--convergent <n>] [--top <s>] [--diff-files <n>] [--diff-lines <n>] [--notes <s>] [--findings <json>] [--run-id <id>] [--roster-decision <json>]" >&2
    exit 2
  fi
done

if ! command -v jq >/dev/null 2>&1; then
  echo "append_runlog: jq required (brew install jq)" >&2
  exit 1
fi

# Evidence gate (binding, not advisory): a finding dropped at triage MUST
# carry its falsification evidence in factcheck.reason — the smoke test run,
# the call-site citation, the man-page semantics. A reasonless drop is how a
# real finding dies silently and how the leaderboard's survival signal rots.
# This rejects the append outright rather than trusting the orchestrator to
# remember the discipline (see feedback_convergent_not_correct: claims get
# falsified AND confirmed by 5-second smoke tests — record which happened).
if [[ -n "$findings_file" && -f "$findings_file" ]]; then
  # Fail-closed on BOTH lanes (codex+deepseek convergent P2, PR #25 pass 1):
  # a non-string reason (malformed LLM output: object/array) counts as
  # reasonless rather than crashing gsub, and a jq failure (malformed JSON)
  # rejects the append instead of silently bypassing the gate.
  if ! reasonless="$(jq -r '[(.findings // [])[]
      | select((.factcheck.verdict // "") == "drop")
      | select(((.factcheck.reason // "")
          | if type == "string" then gsub("\\s"; "") else "" end) == "")
      | (.id // .file // "?")] | join(", ")' "$findings_file" 2>/dev/null)"; then
    # Diagnostic from a separate jq syntax check — mixing stderr into the
    # capture could false-trip the gate on benign warnings (deepseek,
    # PR #25 pass 2).
    echo "append_runlog: could not validate --findings file: $(jq -e . "$findings_file" 2>&1 >/dev/null | head -2)" >&2
    exit 2
  fi
  if [[ -n "$reasonless" ]]; then
    echo "append_runlog: dropped finding(s) without recorded evidence: $reasonless" >&2
    echo "  record WHY each was falsified in factcheck.reason (smoke test output, call-site citation), then re-run" >&2
    exit 2
  fi
fi

# --roster-decision is fail-open (unlike the evidence gate above): losing
# roster telemetry must never block a runlog append. Invalid/missing file ->
# warn and proceed with the key omitted entirely.
roster_decision_json="null"
if [[ -n "$roster_decision_file" ]]; then
  if [[ -f "$roster_decision_file" ]] && rd="$(jq -c . "$roster_decision_file" 2>/dev/null)"; then
    roster_decision_json="$rd"
  else
    echo "append_runlog: --roster-decision file unreadable or invalid JSON: $roster_decision_file (omitting roster_decision)" >&2
  fi
fi

# CROSS_REVIEW_RUNLOG override exists for the fixture tests — production
# callers never set it.
runlog="${CROSS_REVIEW_RUNLOG:-$(cd "$(dirname "$0")/.." && pwd)/runlog.jsonl}"

# Build per-reviewer payload from each meta.json the wrapper wrote. Reviewers
# whose meta is absent are reported as "skipped" so the runlog entry is honest
# about coverage.
reviewer_obj() {
  local name="$1"
  # The wrapper writes meta to $run_dir/raw/<reviewer>.meta.json (step 3 of
  # SKILL.md passes --out "$run_dir/raw"), but earlier docs incorrectly
  # told callers to pass --run-dir "$run_dir" here, which silently
  # classified every reviewer as "skipped" and lost all telemetry.
  # Caught by codex on pass-3 self-review of PR #10. Try $run_dir/raw
  # first (the canonical location), fall back to $run_dir for callers
  # who already point directly at the raw dir.
  local meta=""
  if [[ -f "$run_dir/raw/$name.meta.json" ]]; then
    meta="$run_dir/raw/$name.meta.json"
  elif [[ -f "$run_dir/$name.meta.json" ]]; then
    meta="$run_dir/$name.meta.json"
  else
    echo '{"status":"skipped"}'
    return
  fi
  # Pass through the meta fields verbatim. The wrapper guarantees:
  # exit_code, duration_s, timed_out, output_bytes, attempt, timeout_budget_s
  # (and reviewer-specific extras like truncated for kimi).
  #
  # Status precedence: timed_out FIRST so that timeouts which exit 0 (some
  # `timeout` implementations do depending on signal handling) don't get
  # misclassified as "ok". "quota" next: the agy laps stamp
  # failure_kind=quota_exhausted when the shared Gemini Individual quota is
  # the cause — that's a wait-for-reset condition, not a timeout/auth issue,
  # and the analyzer warns on it differently. "permission_denied" likewise
  # gets its own status: a headless soft-denied tool confirmation is a
  # prompt-shape bug in this repo, NOT a dead/ineligible seat, and must not
  # be read as a reason to retire the reviewer. || fallback handles malformed
  # meta.json (OOM, kill mid-write, garbage); we prefer "failed" telemetry
  # over silently dropping the entire pass when the final --argjson rejects
  # empty input.
  jq -c '. + {status: (if .timed_out == true then "timed_out"
                       elif .failure_kind == "quota_exhausted" then "quota"
                       elif .failure_kind == "headless_permission_denied" then "permission_denied"
                       elif .failure_kind == "degenerate_output" then "degenerate"
                       elif .failure_kind == "no_verdict_output" then "no_verdict"
                       elif .exit_code == 0 and (.output_bytes // 0) > 0 then "ok"
                       elif .exit_code == 0 then "empty"
                       else "failed" end)}' "$meta" 2>/dev/null \
    || echo '{"status":"failed","reason":"meta_unparseable"}'
}

# enrich_with_findings <reviewer> <reviewer_json> — add findings_total /
# findings_convergent / findings_dropped from the --findings file. Convergence
# is judged per PROVIDER (an antigravity+gemini-pro-only finding is one
# provider agreeing with itself — not convergent). No-op without --findings,
# for skipped reviewers, or on unreadable findings JSON.
enrich_with_findings() {
  local name="$1" rjson="$2"
  if [[ -z "$findings_file" || ! -f "$findings_file" ]]; then
    printf '%s' "$rjson"
    return
  fi
  if [[ "$(printf '%s' "$rjson" | jq -r '.status // empty')" == "skipped" ]]; then
    printf '%s' "$rjson"
    return
  fi
  local counts
  counts="$(jq -c --arg r "$name" '
    ({"codex":"openai","antigravity":"google","gemini-pro":"google",
      "kimi":"moonshot","glm":"zhipu","deepseek":"deepseek","mimo":"xiaomi",
      "minimax":"minimax","qwen":"alibaba","devstral":"mistral",
      "laguna":"poolside","kat":"kuaishou","north":"cohere","nemotron":"nvidia",
      "spark":"meta","seed":"bytedance","grok":"xai",
      "kimi27":"moonshot","kimi3":"moonshot"}) as $prov
    | [(.findings // [])[] | select((.sources // []) | index($r))] as $mine
    | { findings_total: ($mine | length),
        findings_convergent: ($mine | map(select(
            ((.sources // []) | map($prov[.] // .) | unique | length) > 1)) | length),
        findings_dropped: ($mine | map(select(.factcheck.verdict == "drop")) | length) }
  ' "$findings_file" 2>/dev/null)"
  if [[ -n "$counts" ]]; then
    printf '%s' "$rjson" | jq -c --argjson c "$counts" '. + $c' 2>/dev/null || printf '%s' "$rjson"
  else
    printf '%s' "$rjson"
  fi
}

codex_json=$(enrich_with_findings codex "$(reviewer_obj codex)")
antigravity_json=$(enrich_with_findings antigravity "$(reviewer_obj antigravity)")
gemini_pro_json=$(enrich_with_findings gemini-pro "$(reviewer_obj gemini-pro)")
kimi_json=$(enrich_with_findings kimi "$(reviewer_obj kimi)")
glm_json=$(enrich_with_findings glm "$(reviewer_obj glm)")
deepseek_json=$(enrich_with_findings deepseek "$(reviewer_obj deepseek)")
mimo_json=$(enrich_with_findings mimo "$(reviewer_obj mimo)")
minimax_json=$(enrich_with_findings minimax "$(reviewer_obj minimax)")
qwen_json=$(enrich_with_findings qwen "$(reviewer_obj qwen)")
devstral_json=$(enrich_with_findings devstral "$(reviewer_obj devstral)")
laguna_json=$(enrich_with_findings laguna "$(reviewer_obj laguna)")
kat_json=$(enrich_with_findings kat "$(reviewer_obj kat)")
north_json=$(enrich_with_findings north "$(reviewer_obj north)")
nemotron_json=$(enrich_with_findings nemotron "$(reviewer_obj nemotron)")
spark_json=$(enrich_with_findings spark "$(reviewer_obj spark)")
seed_json=$(enrich_with_findings seed "$(reviewer_obj seed)")
grok_json=$(enrich_with_findings grok "$(reviewer_obj grok)")
kimi27_json=$(enrich_with_findings kimi27 "$(reviewer_obj kimi27)")
kimi3_json=$(enrich_with_findings kimi3 "$(reviewer_obj kimi3)")

ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

entry=$(jq -nc \
  --arg ts "$ts" \
  --arg project "$project" \
  --arg base "$base" \
  --arg pr "$pr" \
  --argjson pass "$pass" \
  --arg verdict "$verdict" \
  --argjson convergent "$convergent" \
  --arg top "$top" \
  --arg notes "$notes" \
  --arg diff_files "${diff_files:-}" \
  --arg diff_lines "${diff_lines:-}" \
  --argjson codex "$codex_json" \
  --argjson antigravity "$antigravity_json" \
  --argjson gemini_pro "$gemini_pro_json" \
  --argjson kimi "$kimi_json" \
  --argjson glm "$glm_json" \
  --argjson deepseek "$deepseek_json" \
  --argjson mimo "$mimo_json" \
  --argjson minimax "$minimax_json" \
  --argjson qwen "$qwen_json" \
  --argjson devstral "$devstral_json" \
  --argjson laguna "$laguna_json" \
  --argjson kat "$kat_json" \
  --argjson north "$north_json" \
  --argjson nemotron "$nemotron_json" \
  --argjson spark "$spark_json" \
  --argjson seed "$seed_json" \
  --argjson grok "$grok_json" \
  --argjson kimi27 "$kimi27_json" \
  --argjson kimi3 "$kimi3_json" \
  --arg run_id "$run_id" \
  --argjson roster_decision "$roster_decision_json" \
  '{
    ts: $ts,
    project: $project,
    base: $base,
    pr: (if $pr == "-" then null else ($pr | tonumber? // $pr) end),
    pass: $pass,
    diff_size: (if $diff_files == "" and $diff_lines == "" then null
                else {files: ($diff_files | tonumber? // null),
                      lines: ($diff_lines | tonumber? // null)} end),
    reviewers: {codex: $codex, antigravity: $antigravity, "gemini-pro": $gemini_pro, kimi: $kimi, glm: $glm,
                deepseek: $deepseek, mimo: $mimo, minimax: $minimax, qwen: $qwen,
                devstral: $devstral, laguna: $laguna, kat: $kat, north: $north, nemotron: $nemotron,
                spark: $spark, seed: $seed, grok: $grok,
                kimi27: $kimi27, kimi3: $kimi3},
    convergent_count: $convergent,
    verdict: $verdict,
    top_finding: (if $top == "" then null else $top end),
    notes: (if $notes == "" then null else $notes end)
  }
  + (if $run_id == "" then {} else {run_id: $run_id} end)
  + (if $roster_decision == null then {} else {roster_decision: $roster_decision} end)')

# JSONL — one line, append-only. Wrap in flock to make it splitstream-safe:
# POSIX guarantees write() atomicity below PIPE_BUF (4KB Linux, 512B macOS).
# Our entries are ~500-800B and growing; on macOS they're already at the
# atomicity boundary, and concurrent splitstream rounds writing simultaneously
# could interleave. flock costs ~5 lines and removes the risk.
# `flock` is GNU/Linux native; macOS Homebrew users get it via `brew install
# util-linux` (or use `shlock`/`lockfile`). Fall back to bare append if flock
# is missing — preserves correctness on platforms without it.
if command -v flock >/dev/null 2>&1; then
  (
    flock -x 200
    printf '%s\n' "$entry" >>"$runlog"
  ) 200>"$runlog.lock"
else
  printf '%s\n' "$entry" >>"$runlog"
fi
echo "appended runlog entry: ts=$ts pr=$pr pass=$pass verdict=$verdict" >&2
