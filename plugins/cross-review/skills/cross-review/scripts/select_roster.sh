#!/usr/bin/env bash
# select_roster.sh — pick this round's reviewer roster.
#
# Contract (2026-07-01, per Gabriel):
#   - codex and kimi are FIXED BASELINES — always on when installed.
#   - Every round has AT LEAST 3 reviewers.
#   - The rest rotate: a weighted random draw over the available pool
#     (agy Gemini laps + the OpenRouter fleet), so we're not paying for every
#     provider on every run but every provider keeps earning leaderboard data.
#
# Weighting (exploit + explore + speed, bandit-style):
#   weight = max(score, 15) * (1 + 0.5/sqrt(attempts+1)) / (1 + p50/240) / (1 + avg_cost/0.50) * draw_boost
#     - score comes from leaderboard.sh (rookies get an optimistic 50, so new
#       models are drawn early and earn real data)
#     - the sqrt term is an exploration bonus that decays as a reviewer
#       accumulates runs
#     - the floor (15) keeps a slumping reviewer from starving forever
#     - the p50 divisor makes latency shape WHO IS DRAWN, never how findings
#       are scored — quality weighting at synthesis is latency-free (Gabriel's
#       speed-without-quality-loss constraint, 2026-07-01)
#   If a reviewer's LATEST attempt in the window was a quota failure, its
#   weight is multiplied by 0.1 — quota outages last ~2 days, so keep it
#   mostly benched but give it an occasional probe so recovery is noticed.
#
# Usage:
#   select_roster.sh [--extras <n>] [--seed <n>] [--json] [--fast]
#     --extras <n>  rotation picks beyond the baselines (default 2; auto-raised
#                   to keep the roster at ≥3 if a baseline is missing)
#     --seed <n>    deterministic draw (tests); default seeds from $RANDOM
#     --json        emit the full decision record as JSON on stdout instead of
#                   the comma list (comma list then goes to stderr). Adds a
#                   `candidates` array (one object per pool member considered:
#                   reviewer, score, attempts, latest_status, p50_duration_s,
#                   cost_usd, draw_boost, weight, selected) and a
#                   `policy_version` string (bump only if the weight formula
#                   below changes) — a durable record of what this round's
#                   draw actually saw, previously only printed to stderr and
#                   discarded. NOTE: a candidate's logged `weight` is its raw
#                   draw weight, NOT its true unconditional selection
#                   probability — this is sampling WITHOUT replacement, so
#                   each pick renormalizes over the shrinking remaining total.
#                   weight + seed + policy_version are enough to reconstruct
#                   the draw later (replay the same weighted-sampling logic
#                   over the logged weights), but don't treat weight/total as
#                   a marginal probability, and don't rely on bit-exact
#                   cross-host seed replay — awk's rand()/srand() are libc/
#                   implementation-defined beyond POSIX minimums (BSD awk on
#                   macOS vs gawk/mawk elsewhere are not guaranteed to agree).
#     --fast        drop pool candidates whose recent p50 exceeds 180s
#                   (rookies pass — unknown speed is worth one probe). For
#                   quick loops and incremental re-review passes.
#
# stdout: comma-separated roster, e.g. "codex,kimi,gemini-pro,minimax"
# stderr: the decision detail (weights, exclusions) for the log.

set -uo pipefail

extras=2
seed=""
emit_json=0
fast_max=0

need_val() {
  if [[ "$2" -lt 2 ]]; then
    echo "missing value for $1" >&2
    exit 2
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --extras) need_val "$1" "$#"; extras="$2"; shift 2 ;;
    --seed)   need_val "$1" "$#"; seed="$2";   shift 2 ;;
    --json)   emit_json=1; shift ;;
    --fast)   fast_max=180; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "select_roster: jq required" >&2; exit 1; }
[[ -z "$seed" ]] && seed=$(( (RANDOM << 15) | RANDOM ))

script_dir="$(cd "$(dirname "$0")" && pwd)"

if [[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  PATH="$HOME/.local/bin:$PATH"
fi

has_openrouter() {
  command -v curl >/dev/null 2>&1 || return 1
  [[ -n "${OPENROUTER_API_KEY:-}" || -s "$HOME/.config/openrouter/key" ]]
}

has_moonshot() {
  command -v curl >/dev/null 2>&1 || return 1
  [[ -n "${MOONSHOT_API_KEY:-}" || -s "$HOME/.config/moonshot/key" ]]
}

# --- availability ------------------------------------------------------------
BASELINES=()
missing_baselines=()
if command -v codex >/dev/null 2>&1; then BASELINES+=(codex); else missing_baselines+=(codex); fi
if command -v kimi  >/dev/null 2>&1; then BASELINES+=(kimi);  else missing_baselines+=(kimi);  fi

POOL=()
if command -v agy >/dev/null 2>&1; then
  POOL+=(antigravity)
  # The Pro-availability probe (`agy models`) can hang for MINUTES on a cold
  # start when the Google quota is exhausted (agy retries its network
  # handshake). An availability check must never cost that, so: 6h TTL cache,
  # 15s hard timeout on refresh, and on probe failure assume Pro exists (agy
  # is installed; the silent-Flash-fallback rename risk is rare and already
  # documented in run_reviewers.sh).
  cache_dir="$HOME/.cross-review/cache"
  models_cache="$cache_dir/agy_models.txt"
  mkdir -p "$cache_dir"
  if [[ ! -s "$models_cache" || -n "$(find "$models_cache" -mmin +360 2>/dev/null)" ]]; then
    # PID-suffixed temp: concurrent selector runs (splitstream rounds) would
    # interleave writes into a shared .tmp before the atomic mv (kimi finding,
    # PR #18 pass 1).
    models_tmp="$models_cache.tmp.$$"
    TIMEOUT_BIN=""
    command -v timeout  >/dev/null 2>&1 && TIMEOUT_BIN="timeout"
    [[ -z "$TIMEOUT_BIN" ]] && command -v gtimeout >/dev/null 2>&1 && TIMEOUT_BIN="gtimeout"
    if [[ -z "$TIMEOUT_BIN" ]]; then
      # Background/cron PATHs often lack homebrew — probe standard locations.
      for _tb in /opt/homebrew/bin/gtimeout /usr/local/bin/gtimeout; do
        if [[ -x "$_tb" ]]; then TIMEOUT_BIN="$_tb"; break; fi
      done
    fi
    if [[ -n "$TIMEOUT_BIN" ]]; then
      # -k 5: agy ignores SIGTERM while stuck in its quota-retry network loop
      # (observed 2026-07-01: a plain 15s timeout never fired and the probe
      # hung for minutes) — escalate to SIGKILL 5s after TERM.
      "$TIMEOUT_BIN" -k 5 15 agy models >"$models_tmp" 2>/dev/null && mv "$models_tmp" "$models_cache" || rm -f "$models_tmp"
    fi
    # No timeout binary anywhere → do NOT probe unbounded (an unhealthy agy
    # can hang for minutes and block every review at roster selection —
    # codex P2, PR #18 pass 2). Fall through to the assume-Pro path below.
  fi
  if [[ -s "$models_cache" ]]; then
    # Slug or display name — see detect_reviewers.sh (agy 1.1.10 switched).
    grep -Eqi 'gemini[ ._-]?3\.1[ ._-]?pro' "$models_cache" && POOL+=(gemini-pro)
  else
    echo "  note: agy models probe unavailable — assuming gemini-pro exists" >&2
    POOL+=(gemini-pro)
  fi
fi
if has_openrouter; then
  POOL+=(glm deepseek mimo minimax qwen devstral laguna kat north nemotron spark seed grok)
fi
# kimi27 (k2.7-code) rides the DIRECT Moonshot API — a deliberate rotation
# seat (2026-07-03, per Gabriel), not an OpenRouter fallback for the kimi
# baseline. Its profile carries a draw_boost so it is drawn frequently while
# it earns leaderboard data.
# kimi3 (K3 flagship, released 2026-07-16) is the same direct-Moonshot seat
# pattern, added 2026-07-18 — shares has_moonshot's gate and billing rail.
if has_moonshot; then
  POOL+=(kimi27 kimi3)
fi

if [[ ${#BASELINES[@]} -eq 0 && ${#POOL[@]} -eq 0 ]]; then
  echo "select_roster: no reviewers available at all" >&2
  exit 1
fi

# ≥3 total: raise the draw count when a baseline is missing.
need=$(( 3 - ${#BASELINES[@]} ))
[[ "$extras" -lt "$need" ]] && extras="$need"
[[ "$extras" -gt ${#POOL[@]} ]] && extras=${#POOL[@]}

# --- weights from the leaderboard ---------------------------------------------
# lines: "<name> <score> <attempts> <latest_status> <p50> <avg_cost_usd> <draw_boost>"
lb_json="$(bash "$script_dir/leaderboard.sh" --mode json 2>/dev/null || echo '[]')"

# Per-reviewer draw_boost from reviewer_profiles.json (default 1): a manual
# multiplier on the draw weight only — synthesis weighting is untouched. Used
# to make a deliberately-seated reviewer (kimi27, 2026-07-03) come up
# frequently while it earns leaderboard data; retire boosts once real scores
# accumulate.
profile_file="$script_dir/../references/reviewer_profiles.json"
draw_boost_of() {
  [[ -f "$profile_file" ]] || { echo 1; return; }
  jq -r --arg r "$1" '.[$r].draw_boost // 1' "$profile_file" 2>/dev/null || echo 1
}

weight_lines=""
for r in "${POOL[@]}"; do
  line="$(printf '%s' "$lb_json" | jq -r --arg r "$r" --arg boost "$(draw_boost_of "$r")" '
    (map(select(.reviewer == $r)) | first) as $s
    | if $s == null then "\($r) 50 0 never_run 0 0 \($boost)"
      else "\($r) \($s.score) \($s.attempts) \($s.latest_status) \($s.p50_duration_s // 0) \($s.avg_cost_usd // 0) \($boost)"
      end
  ')"
  weight_lines="$weight_lines$line"$'\n'
done

# COST_PIVOT_USD tunes the cost divisor (weight /= 1 + avg_cost/pivot).
# Guard the knob: zero, negative, or non-numeric would make awk divide by
# zero (or invert the penalty) and could draw an empty pool — coerce any
# invalid value back to the 0.50 default (codex, PR #28 pass 2).
# Strict decimal shape FIRST: awk -v treats "0.0.1" as a STRING, and
# `p > 0` string-compares to true while the later numeric coercion yields
# zero — divide-by-zero (codex, PR #28 pass 3; falsified kimi's contrary
# assumption by smoke test). `p + 0` forces numeric for the positivity check.
cost_pivot="${COST_PIVOT_USD:-0.50}"
if ! [[ "$cost_pivot" =~ ^[0-9]+(\.[0-9]+)?$ ]] || ! awk -v p="$cost_pivot" 'BEGIN{exit !(p + 0 > 0)}'; then
  cost_pivot="0.50"
fi

# --- weighted sample without replacement (awk: proper float math, seedable) ---
draw_picks() {
  # $1 = fastmax (0 disables the speed filter)
  # $2 = optional path to write one JSON line per considered candidate
  #      (truncated fresh on every call, including a zero-candidate call, so
  #      a later --fast-fallback redraw's file always reflects the draw that
  #      actually produced $selected — never a stale earlier attempt's).
  printf '%s' "$weight_lines" | awk -v k="$extras" -v seed="$seed" -v fastmax="$1" -v costpivot="$cost_pivot" -v cand_out="${2:-}" '
  BEGIN { srand(seed) }
  NF >= 4 {
    p50 = (NF >= 5 ? $5 + 0 : 0)
    if (fastmax > 0 && p50 > fastmax) {
      printf "  candidate %-12s SKIPPED (--fast: p50 %ss > %ss)\n", $1, p50, fastmax > "/dev/stderr"
      next
    }
    n++
    name[n] = $1
    score = $2 + 0
    attempts = $3 + 0
    latest = $4
    cost = (NF >= 6 ? $6 + 0 : 0)
    boost = (NF >= 7 ? $7 + 0 : 1)
    if (boost <= 0) boost = 1
    # exploit * explore / latency / cost * boost — latency and COST shape the
    # draw, never the synthesis-time weighting of findings. The cost divisor is
    # the fugu lesson made structural (PR #20: $4.74/call, 94.9% of a week'"'"'s OR
    # spend): a $0.50-per-run reviewer draws at half weight, fugu-priced ones
    # at ~1/10 — expensive-but-good still gets sampled, runaway spend cannot
    # dominate the roster. Free/first-party lanes have cost 0 (no divisor).
    # draw_boost (reviewer_profiles.json, default 1) is a manual seat-priority
    # multiplier — kimi27 (2026-07-03, per Gabriel) rides it while earning
    # leaderboard data; it scales the DRAW only, never synthesis weighting.
    w = (score > 15 ? score : 15) * (1 + 0.5 / sqrt(attempts + 1)) / (1 + p50 / 240) / (1 + cost / costpivot) * boost
    if (latest == "quota") w *= 0.1
    weight[n] = w
    total += w
    # Snapshot everything needed for the candidates JSON before the pick loop
    # mutates weight[] to zero out chosen candidates (without-replacement).
    oname[n] = $1; oscore[n] = score; oattempts[n] = attempts; olatest[n] = latest
    op50[n] = p50; ocost[n] = cost; oboost[n] = boost; origw[n] = w
    printf "  candidate %-12s score=%-4s attempts=%-3s latest=%-10s p50=%-5ss cost=$%-7.4f boost=%s weight=%.1f\n", $1, $2, $3, $4, p50, cost, boost, w > "/dev/stderr"
  }
  END {
    if (cand_out != "") printf "" > cand_out   # truncate/create even if n==0
    for (pick = 0; pick < k && total > 0.0001; pick++) {
      r = rand() * total
      acc = 0
      for (i = 1; i <= n; i++) {
        if (weight[i] <= 0) continue
        acc += weight[i]
        if (r <= acc) {
          print name[i]
          picked[i] = 1
          total -= weight[i]
          weight[i] = 0
          break
        }
      }
    }
    if (cand_out != "") {
      for (i = 1; i <= n; i++) {
        sel = (i in picked) ? "true" : "false"
        printf "{\"reviewer\":\"%s\",\"score\":%s,\"attempts\":%s,\"latest_status\":\"%s\",\"p50_duration_s\":%s,\"cost_usd\":%s,\"draw_boost\":%s,\"weight\":%.4f,\"selected\":%s}\n", \
          oname[i], oscore[i], oattempts[i], olatest[i], op50[i], ocost[i], oboost[i], origw[i], sel > cand_out
      }
    }
  }
'
}

# cand_tmp only exists in --json mode — the candidates array is a --json-only
# concern, no reason to pay a mktemp on every plain-stdout invocation.
cand_tmp=""
if [[ "$emit_json" -eq 1 ]]; then
  cand_tmp="$(mktemp)"
  trap 'rm -f "$cand_tmp"' EXIT
fi

selected="$(draw_picks "$fast_max" "$cand_tmp")"
# --fast can filter the pool below what the roster needs (kimi+deepseek
# convergent, PR #18 pass 3; partial-filter case codex P2, pass 4): the floor
# check counts what was actually drawn, not just emptiness — with a missing
# baseline, a partially-filtered draw can be non-empty yet still leave the
# roster under 3. A slow rotation pick beats a missing one.
if [[ "$fast_max" -gt 0 ]]; then
  sel_n="$(printf '%s\n' "$selected" | grep -c '^.' || true)"
  if (( ${#BASELINES[@]} + sel_n < 3 )); then
    echo "  note: --fast left the roster below the 3-reviewer floor (${#BASELINES[@]} baselines + $sel_n picks) — redrawing without the speed filter" >&2
    selected="$(draw_picks 0 "$cand_tmp")"
  fi
fi

# --- assemble ------------------------------------------------------------------
roster=""
for b in ${BASELINES[@]+"${BASELINES[@]}"}; do roster="$roster,$b"; done
while IFS= read -r s; do [[ -n "$s" ]] && roster="$roster,$s"; done <<<"$selected"
roster="${roster#,}"

n_total=$(printf '%s' "$roster" | awk -F',' '{print NF}')
{
  [[ ${#missing_baselines[@]} -gt 0 ]] && echo "  WARN: baseline(s) not installed: ${missing_baselines[*]} — raised rotation draw to keep roster ≥3"
  echo "  roster ($n_total reviewers, seed=$seed): $roster"
} >&2

if [[ "$n_total" -lt 3 ]]; then
  echo "  WARN: only $n_total reviewer(s) available — below the 3-reviewer floor; proceeding with what exists" >&2
fi

if [[ "$emit_json" -eq 1 ]]; then
  sel_json="$(printf '%s\n' "$selected" | jq -R 'select(length > 0)' | jq -s .)"
  base_json="$(printf '%s\n' ${BASELINES[@]+"${BASELINES[@]}"} | jq -R 'select(length > 0)' | jq -s .)"
  cand_json="[]"
  if [[ -n "$cand_tmp" && -s "$cand_tmp" ]]; then
    cand_json="$(jq -s . "$cand_tmp" 2>/dev/null || echo '[]')"
  fi
  jq -nc --arg roster "$roster" --arg seed "$seed" \
     --argjson baselines "$base_json" --argjson selected "$sel_json" \
     --argjson candidates "$cand_json" \
     '{roster: $roster, baselines: $baselines, selected: $selected, seed: ($seed | tonumber),
       candidates: $candidates, policy_version: "weighted-draw-v1"}'
  echo "$roster" >&2
else
  echo "$roster"
fi
