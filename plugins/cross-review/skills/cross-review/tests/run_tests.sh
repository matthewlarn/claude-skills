#!/usr/bin/env bash
# run_tests.sh — offline fixture tests for the cross-review scripts.
#
# NO network, NO reviewer CLIs, NO tokens: reviewer binaries are PATH shims,
# the runlog is a fixture via $CROSS_REVIEW_RUNLOG, and git repos are created
# in a temp dir. Every case pins a behavior a real review round flagged (or
# falsified) on PR #18 — see the [pin: ...] tags.
#
# Run:  bash tests/run_tests.sh          (from the skill root or anywhere)
# Exit: 0 all green, 1 any failure.
#
# Portability: macOS bash 3.2 + ubuntu bash 5; needs jq, git, and a coreutils
# timeout (gtimeout on macOS via brew).

set -uo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
S="$SKILL_DIR/scripts"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

PASS=0
FAIL=0
ok()  { echo "  ok   $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL + 1)); }
# assert <description> <actual> <expected>
assert_eq() {
  if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (got: '$2' want: '$3')"; fi
}
assert_contains() {
  if [[ "$2" == *"$3"* ]]; then ok "$1"; else bad "$1 (no '$3' in output)"; fi
}

# ── PATH shims: fake reviewer binaries so availability checks pass and the
# kimi tests run hermetically. Fake agy prints a models list instantly.
mkdir -p "$T/bin"
printf '#!/bin/sh\ncat >/dev/null 2>&1 || true\nprintf "shim review: no findings\\n"\n' >"$T/bin/kimi"
printf '#!/bin/sh\nprintf "shim\\n"\n' >"$T/bin/codex"
printf '#!/bin/sh\nif [ "$1" = "models" ]; then printf "Gemini 3.5 Flash (High)\\nGemini 3.1 Pro (High)\\n"; fi\n' >"$T/bin/agy"
chmod +x "$T/bin/"*
export PATH="$T/bin:$PATH"
export OPENROUTER_API_KEY="sk-or-test-shim"   # lights the OR pool; never called
export MOONSHOT_API_KEY="sk-ms-test-shim"     # lights the kimi27 seat; never called
# Sandbox HOME: the selector caches `agy models` output under
# $HOME/.cross-review/cache with a 6h TTL — running tests against the real
# HOME would poison real roster draws with the shim's list (codex P2, PR #19).
export HOME="$T/home"
mkdir -p "$HOME"

# ── Fixture runlog ────────────────────────────────────────────────────────────
# codex: 2 ok runs, findings 3+1=4, convergent 1, dropped 0 → score 74
#   (0.45*1.0 + 0.35*0.25 + 0.20*1.0 = 0.7375 → 74); p50 of [100,200] → 200
# kimi: 1 ok, no findings data → telemetry-only: 100*1.0*0.75 = 75
# gemini-pro: ok,failed,failed,quota → reliability 1/4 → 18.75 → 19; quota=1
# nemotron: absent → rookie prior 50
FIXLOG="$T/runlog.jsonl"
cat >"$FIXLOG" <<'EOF'
{"ts":"2026-07-01T01:00:00Z","reviewers":{"codex":{"status":"ok","exit_code":0,"duration_s":100,"output_bytes":10,"timeout_budget_s":300,"findings_total":3,"findings_convergent":1,"findings_dropped":0},"kimi":{"status":"ok","exit_code":0,"duration_s":40,"output_bytes":10,"timeout_budget_s":600},"gemini-pro":{"status":"ok","exit_code":0,"duration_s":50,"output_bytes":10,"timeout_budget_s":900}}}
{"ts":"2026-07-01T02:00:00Z","reviewers":{"codex":{"status":"ok","exit_code":0,"duration_s":200,"output_bytes":10,"timeout_budget_s":300,"findings_total":1,"findings_convergent":0,"findings_dropped":0},"gemini-pro":{"status":"failed","exit_code":2,"duration_s":20,"output_bytes":0,"timeout_budget_s":900}}}
{"ts":"2026-07-01T03:00:00Z","reviewers":{"gemini-pro":{"status":"failed","exit_code":1,"duration_s":30,"output_bytes":0,"timeout_budget_s":900}}}
{"ts":"2026-07-01T04:00:00Z","reviewers":{"gemini-pro":{"status":"quota","exit_code":3,"duration_s":6,"output_bytes":0,"timeout_budget_s":900,"failure_kind":"quota_exhausted"}}}
EOF

echo "── leaderboard.sh (fixture scoring) ──"
LB="$(CROSS_REVIEW_RUNLOG="$FIXLOG" bash "$S/leaderboard.sh" --mode json)"
assert_eq "codex blended score (reliability+signal+survival)" \
  "$(jq -r '.[] | select(.reviewer=="codex") | .score' <<<"$LB")" "74"
assert_eq "codex p50 from sorted durations" \
  "$(jq -r '.[] | select(.reviewer=="codex") | .p50_duration_s' <<<"$LB")" "200"
assert_eq "kimi telemetry-only discount (rel×0.75)" \
  "$(jq -r '.[] | select(.reviewer=="kimi") | .score' <<<"$LB")" "75"
assert_eq "gemini-pro reliability with quota+failed runs" \
  "$(jq -r '.[] | select(.reviewer=="gemini-pro") | .score' <<<"$LB")" "19"
assert_eq "gemini-pro quota count" \
  "$(jq -r '.[] | select(.reviewer=="gemini-pro") | .quota' <<<"$LB")" "1"
assert_eq "never-run reviewer gets rookie prior" \
  "$(jq -r '.[] | select(.reviewer=="nemotron") | .score' <<<"$LB")" "50"
assert_eq "rookie flag set" \
  "$(jq -r '.[] | select(.reviewer=="nemotron") | .rookie' <<<"$LB")" "true"

echo "── leaderboard.sh (zero-findings loophole: decaying telemetry-only prior) ──"
# [pin: 2026-08-03, verified live — kat had 9/9 ok runs, p50 4s, ZERO findings
# data ever, and scored 75 (reliability×0.75), ranking ABOVE kimi (score 65,
# 39 runs, 22 real findings). The flat 0.75 discount was meant as a soft prior
# for UNDER-OBSERVED reviewers to get drawn and earn real data — not a
# permanent haven for sustained non-engagement. A reviewer that reliably
# returns nothing in 4s must not outrank one that actually finds bugs.]
KATLOG="$T/kat-runlog.jsonl"
cat >"$KATLOG" <<'EOF'
{"ts":"2026-07-25T01:00:00Z","reviewers":{"kat":{"status":"ok","exit_code":0,"duration_s":3,"output_bytes":40,"timeout_budget_s":300}}}
{"ts":"2026-07-25T02:00:00Z","reviewers":{"kat":{"status":"ok","exit_code":0,"duration_s":4,"output_bytes":40,"timeout_budget_s":300}}}
{"ts":"2026-07-25T03:00:00Z","reviewers":{"kat":{"status":"ok","exit_code":0,"duration_s":4,"output_bytes":40,"timeout_budget_s":300}}}
{"ts":"2026-07-25T04:00:00Z","reviewers":{"kat":{"status":"ok","exit_code":0,"duration_s":4,"output_bytes":40,"timeout_budget_s":300}}}
{"ts":"2026-07-25T05:00:00Z","reviewers":{"kat":{"status":"ok","exit_code":0,"duration_s":5,"output_bytes":40,"timeout_budget_s":300}}}
{"ts":"2026-07-25T06:00:00Z","reviewers":{"kat":{"status":"ok","exit_code":0,"duration_s":3,"output_bytes":40,"timeout_budget_s":300}}}
{"ts":"2026-07-25T07:00:00Z","reviewers":{"kat":{"status":"ok","exit_code":0,"duration_s":4,"output_bytes":40,"timeout_budget_s":300}}}
{"ts":"2026-07-25T08:00:00Z","reviewers":{"kat":{"status":"ok","exit_code":0,"duration_s":5,"output_bytes":40,"timeout_budget_s":300}}}
{"ts":"2026-07-25T09:00:00Z","reviewers":{"kat":{"status":"ok","exit_code":0,"duration_s":4,"output_bytes":40,"timeout_budget_s":300}}}
EOF
KATLB="$(CROSS_REVIEW_RUNLOG="$KATLOG" bash "$S/leaderboard.sh" --mode json)"
assert_eq "T1 setup: kat-shaped reviewer has 9/9 ok attempts" \
  "$(jq -r '.[] | select(.reviewer=="kat") | .attempts' <<<"$KATLB")" "9"
assert_eq "T1 setup: kat-shaped reviewer p50 matches real shape (4s)" \
  "$(jq -r '.[] | select(.reviewer=="kat") | .p50_duration_s' <<<"$KATLB")" "4"
KATSCORE="$(jq -r '.[] | select(.reviewer=="kat") | .score' <<<"$KATLB")"
if [[ "$KATSCORE" =~ ^-?[0-9]+$ ]] && [[ "$KATSCORE" -lt 50 ]]; then
  ok "T1: >=8 ok runs with zero findings data ever scores below rookie prior 50 (got $KATSCORE)"
else
  bad "T1: >=8 ok runs with zero findings data ever scores below rookie prior 50 (got: '$KATSCORE' want: <50)"
fi

# T2: a genuine under-observed rookie (<=3 ok runs, no findings data) must
# keep the soft prior — new seats earning their first few runs must not be
# nuked by the decay meant for sustained non-engagement.
ROOKIELOG="$T/rookie-runlog.jsonl"
cat >"$ROOKIELOG" <<'EOF'
{"ts":"2026-07-25T01:00:00Z","reviewers":{"spark":{"status":"ok","exit_code":0,"duration_s":30,"output_bytes":40,"timeout_budget_s":300}}}
{"ts":"2026-07-25T02:00:00Z","reviewers":{"spark":{"status":"ok","exit_code":0,"duration_s":32,"output_bytes":40,"timeout_budget_s":300}}}
{"ts":"2026-07-25T03:00:00Z","reviewers":{"spark":{"status":"ok","exit_code":0,"duration_s":31,"output_bytes":40,"timeout_budget_s":300}}}
EOF
ROOKIELB="$(CROSS_REVIEW_RUNLOG="$ROOKIELOG" bash "$S/leaderboard.sh" --mode json)"
assert_eq "T2: under-observed rookie (<=3 ok runs, no findings) keeps rel×0.75" \
  "$(jq -r '.[] | select(.reviewer=="spark") | .score' <<<"$ROOKIELB")" "75"

echo "── append_runlog.sh (status classification + enrichment) ──"
# [pin: fugu pass-1 High FALSIFIED — missing meta must be skipped, not failed]
RUN="$T/run1"; mkdir -p "$RUN/raw"
printf '{"exit_code": 0, "duration_s": 60, "timed_out": false, "output_bytes": 500, "attempt": 1, "timeout_budget_s": 300}\n' >"$RUN/raw/codex.meta.json"
printf '{"exit_code": 3, "duration_s": 6, "timed_out": false, "output_bytes": 0, "attempt": 1, "timeout_budget_s": 600, "model": "Gemini 3.5 Flash (High)", "cli": "agy", "failure_kind": "quota_exhausted", "quota_resets_in": "41h"}\n' >"$RUN/raw/antigravity.meta.json"
cat >"$RUN/findings.json" <<'EOF'
{"findings":[
 {"id":"f1","file":"a.sh","line":1,"claim":"x","sources":["codex","glm"],"factcheck":{"verdict":"keep"}},
 {"id":"f2","file":"a.sh","line":2,"claim":"y","sources":["codex"],"factcheck":{"verdict":"drop","reason":"r"}},
 {"id":"f3","file":"a.sh","line":3,"claim":"z","sources":["antigravity","gemini-pro"],"factcheck":{"verdict":"keep"}}
]}
EOF
TESTLOG="$T/out-runlog.jsonl"
CROSS_REVIEW_RUNLOG="$TESTLOG" bash "$S/append_runlog.sh" \
  --run-dir "$RUN" --project test --base main --pr - --pass 1 \
  --verdict CLEAN --convergent 1 --top "-" --findings "$RUN/findings.json" >/dev/null 2>&1
ENTRY="$(tail -1 "$TESTLOG")"
assert_eq "missing meta → skipped (fugu falsification pinned)" \
  "$(jq -r '.reviewers.kimi.status' <<<"$ENTRY")" "skipped"
assert_eq "quota failure_kind → status quota" \
  "$(jq -r '.reviewers.antigravity.status' <<<"$ENTRY")" "quota"
assert_eq "enrichment: codex findings_total" \
  "$(jq -r '.reviewers.codex.findings_total' <<<"$ENTRY")" "2"
assert_eq "enrichment: cross-provider convergence (codex+glm)" \
  "$(jq -r '.reviewers.codex.findings_convergent' <<<"$ENTRY")" "1"
assert_eq "enrichment: factcheck drop counted" \
  "$(jq -r '.reviewers.codex.findings_dropped' <<<"$ENTRY")" "1"
assert_eq "same-provider agreement NOT convergent (agy laps)" \
  "$(jq -r '.reviewers.antigravity.findings_convergent' <<<"$ENTRY")" "0"

echo "── append_runlog.sh (reasonless-drop evidence gate) ──"
# [pin: falsification evidence is binding — a drop without factcheck.reason
# must reject the append, not silently starve the leaderboard]
cat >"$T/bad-findings.json" <<'EOF'
{"findings":[
 {"id":"g1","file":"a.sh","line":1,"claim":"x","sources":["codex"],"factcheck":{"verdict":"drop","reason":""}},
 {"id":"g2","file":"a.sh","line":2,"claim":"y","sources":["kimi"],"factcheck":{"verdict":"drop"}}
]}
EOF
GATELOG="$T/gate-runlog.jsonl"
CROSS_REVIEW_RUNLOG="$GATELOG" bash "$S/append_runlog.sh" \
  --run-dir "$RUN" --project test --base main --pr - --pass 1 \
  --verdict CLEAN --convergent 0 --top "-" --findings "$T/bad-findings.json" >/dev/null 2>"$T/gate.err"
rc=$?
assert_eq "reasonless drops reject with exit 2" "$rc" "2"
assert_contains "gate names the offending findings" "$(cat "$T/gate.err")" "g1, g2"
[ ! -s "$GATELOG" ] && ok "nothing appended on gate rejection" || bad "runlog written despite gate rejection"
cat >"$T/nonstring-findings.json" <<'EOF'
{"findings":[
 {"id":"g4","file":"a.sh","line":4,"claim":"w","sources":["glm"],"factcheck":{"verdict":"drop","reason":{"oops":"object"}}}
]}
EOF
CROSS_REVIEW_RUNLOG="$GATELOG" bash "$S/append_runlog.sh" \
  --run-dir "$RUN" --project test --base main --pr - --pass 1 \
  --verdict CLEAN --convergent 0 --top "-" --findings "$T/nonstring-findings.json" >/dev/null 2>&1
assert_eq "non-string reason counts as reasonless (exit 2)" "$?" "2"
printf 'not json\n' >"$T/garbage-findings.json"
CROSS_REVIEW_RUNLOG="$GATELOG" bash "$S/append_runlog.sh" \
  --run-dir "$RUN" --project test --base main --pr - --pass 1 \
  --verdict CLEAN --convergent 0 --top "-" --findings "$T/garbage-findings.json" >/dev/null 2>&1
assert_eq "malformed findings JSON rejects (exit 2)" "$?" "2"
cat >"$T/good-findings.json" <<'EOF'
{"findings":[
 {"id":"g3","file":"a.sh","line":3,"claim":"z","sources":["codex"],"factcheck":{"verdict":"drop","reason":"falsified: coreutils timeout -k exits 137; call sites treat 124||137 as timed_out"}}
]}
EOF
CROSS_REVIEW_RUNLOG="$GATELOG" bash "$S/append_runlog.sh" \
  --run-dir "$RUN" --project test --base main --pr - --pass 1 \
  --verdict CLEAN --convergent 0 --top "-" --findings "$T/good-findings.json" >/dev/null 2>&1
assert_eq "evidenced drop appends fine" "$?" "0"
assert_eq "gated entry landed in runlog" "$(wc -l <"$GATELOG" | tr -d ' ')" "1"

echo "── append_runlog.sh (--roster-decision / --run-id) ──"
cat >"$T/roster_decision.json" <<'EOF'
{"roster":"codex,kimi,glm","baselines":["codex","kimi"],"selected":["glm"],"seed":42,"candidates":[{"reviewer":"glm","score":67,"weight":10.5,"selected":true}],"policy_version":"weighted-draw-v1"}
EOF
RDLOG="$T/rd-runlog.jsonl"
CROSS_REVIEW_RUNLOG="$RDLOG" bash "$S/append_runlog.sh" \
  --run-dir "$RUN" --project test --base main --pr - --pass 1 \
  --verdict CLEAN --convergent 0 --top "-" >/dev/null 2>&1
BASELINE_ENTRY="$(jq -Sc 'del(.ts)' "$RDLOG")"
: >"$RDLOG"
CROSS_REVIEW_RUNLOG="$RDLOG" bash "$S/append_runlog.sh" \
  --run-dir "$RUN" --project test --base main --pr - --pass 1 \
  --verdict CLEAN --convergent 0 --top "-" \
  --run-id run-test-xyz --roster-decision "$T/roster_decision.json" >/dev/null 2>&1
WITH_ENTRY="$(tail -1 "$RDLOG")"
assert_eq "run_id attached" "$(jq -r '.run_id' <<<"$WITH_ENTRY")" "run-test-xyz"
assert_eq "roster_decision attached verbatim" \
  "$(jq -Sc '.roster_decision' <<<"$WITH_ENTRY")" "$(jq -Sc . "$T/roster_decision.json")"
assert_eq "omitting both flags reproduces today's entry byte-for-byte" \
  "$BASELINE_ENTRY" "$(jq -Sc 'del(.ts, .run_id, .roster_decision)' <<<"$WITH_ENTRY")"
: >"$RDLOG"
printf 'not json\n' >"$T/bad-roster-decision.json"
CROSS_REVIEW_RUNLOG="$RDLOG" bash "$S/append_runlog.sh" \
  --run-dir "$RUN" --project test --base main --pr - --pass 1 \
  --verdict CLEAN --convergent 0 --top "-" \
  --roster-decision "$T/bad-roster-decision.json" >/dev/null 2>"$T/rd.err"
assert_eq "garbage roster-decision file still appends (exit 0)" "$?" "0"
assert_eq "garbage roster-decision omits the key" "$(jq 'has("roster_decision")' "$RDLOG")" "false"
assert_contains "garbage roster-decision warns to stderr" "$(cat "$T/rd.err")" "unreadable or invalid JSON"

echo "── select_roster.sh (determinism, floor, --fast fallback) ──"
# select_roster.sh doesn't read CROSS_REVIEW_RUNLOG itself — it shells out to
# leaderboard.sh, which inherits the exported var and reads the fixture. The
# --fast test below proves the plumbing: its filter only triggers on the
# fixture's p50 values. (minimax flagged this as broken on PR #19; it isn't.)
R1="$(CROSS_REVIEW_RUNLOG="$FIXLOG" bash "$S/select_roster.sh" --seed 99 2>/dev/null)"
R2="$(CROSS_REVIEW_RUNLOG="$FIXLOG" bash "$S/select_roster.sh" --seed 99 2>/dev/null)"
assert_eq "seeded draw is deterministic" "$R1" "$R2"
assert_contains "baseline codex always on" "$R1" "codex"
assert_contains "baseline kimi always on" "$R1" "kimi"
N_R1="$(awk -F',' '{print NF}' <<<"$R1")"
if [[ "$N_R1" -ge 3 ]]; then ok "roster ≥3 ($N_R1)"; else bad "roster <3 ($R1)"; fi
# [pin: kimi+deepseek pass-3 convergent + codex pass-4 P2 — --fast over-filter
# must redraw unfiltered and keep the floor]
SLOWLOG="$T/slow-runlog.jsonl"
jq -nc '{ts:"2026-07-01T05:00:00Z", reviewers: (
  ["antigravity","gemini-pro","glm","deepseek","mimo","minimax","qwen","devstral","laguna","kat","north","nemotron","spark","seed","grok","kimi27","kimi3"]
  | map({key: ., value: {status:"ok", exit_code:0, duration_s:5000, output_bytes:10, timeout_budget_s:600}}) | from_entries)}' >"$SLOWLOG"
FAST_ERR="$T/fast.err"
RF="$(CROSS_REVIEW_RUNLOG="$SLOWLOG" bash "$S/select_roster.sh" --seed 7 --fast 2>"$FAST_ERR")"
N_RF="$(awk -F',' '{print NF}' <<<"$RF")"
if [[ "$N_RF" -ge 3 ]]; then ok "--fast over-filter keeps ≥3 roster via fallback ($RF)"; else bad "--fast shipped sub-floor roster ($RF)"; fi
assert_contains "--fast fallback announces the redraw" "$(cat "$FAST_ERR")" "redrawing without the speed filter"

echo "── select_roster.sh --json (candidates array, policy_version) ──"
RJ="$(CROSS_REVIEW_RUNLOG="$FIXLOG" bash "$S/select_roster.sh" --seed 99 --json 2>/dev/null)"
assert_eq "roster in --json matches plain-mode roster (same seed+fixture)" \
  "$(jq -r '.roster' <<<"$RJ")" "$R1"
assert_eq "policy_version stamped" "$(jq -r '.policy_version' <<<"$RJ")" "weighted-draw-v1"
N_CAND="$(jq '.candidates | length' <<<"$RJ")"
if [[ "$N_CAND" -gt 0 ]]; then ok "candidates array populated ($N_CAND)"; else bad "candidates array empty"; fi
assert_eq "every candidate has a weight field" \
  "$(jq '[.candidates[] | has("weight")] | all' <<<"$RJ")" "true"
assert_eq "candidates.selected=true count matches .selected array length" \
  "$(jq '[.candidates[] | select(.selected==true)] | length' <<<"$RJ")" \
  "$(jq '.selected | length' <<<"$RJ")"

echo "── run_reviewers.sh kimi budget + rc137 (shim kimi, fixture repo) ──"
REPO="$T/repo"; mkdir -p "$REPO"; cd "$REPO"
git init -q -b main 2>/dev/null || git init -q
seq 1 20 >f.txt; git add .; git -c user.email=t@t -c user.name=t commit -qm init
git checkout -qb feat
seq 1 2600 | sed 's/^/line /' >f.txt; git add .; git -c user.email=t@t -c user.name=t commit -qm big
TOTAL_LINES="$(git diff main...HEAD | wc -l | tr -d ' ')"
# (a) explicit cap honored verbatim [pin: codex pass-3 P2]
bash "$S/run_reviewers.sh" --base main --out "$T/o1" --reviewers kimi --timeout-kimi 60 >/dev/null 2>&1
assert_eq "explicit --timeout-kimi wins over size scaling" \
  "$(jq -r '.timeout_budget_s' "$T/o1/kimi.meta.json")" "60"
# (b) no explicit cap → ceiling-scaled budget [pin: north pass-3 ceil nit]
bash "$S/run_reviewers.sh" --base main --out "$T/o2" --reviewers kimi >/dev/null 2>&1
EXPECT=$(( 600 + 500 * ( (TOTAL_LINES - 1000 + 999) / 1000 ) )); [[ "$EXPECT" -gt 3000 ]] && EXPECT=3000
assert_eq "size-scaled kimi budget (ceil, ${TOTAL_LINES}-line diff)" \
  "$(jq -r '.timeout_budget_s' "$T/o2/kimi.meta.json")" "$EXPECT"
# (c) rc 137 = timed_out, never retried [pin: codex pass-3 P2]
printf '#!/bin/sh\ncat >/dev/null 2>&1 || true\nexit 137\n' >"$T/bin/kimi"
bash "$S/run_reviewers.sh" --base main --out "$T/o3" --reviewers kimi --timeout-kimi 60 >/dev/null 2>&1
assert_eq "rc 137 classified timed_out" "$(jq -r '.timed_out' "$T/o3/kimi.meta.json")" "true"
assert_eq "rc 137 not retried" "$(jq -r '.attempt' "$T/o3/kimi.meta.json")" "1"
printf '#!/bin/sh\ncat >/dev/null 2>&1 || true\nprintf "shim review: no findings\\n"\n' >"$T/bin/kimi"

echo "── degenerate-output detection (glm 'wait'-loop class) ──"
# [pin: PR #25 pass 3 — glm exited 0 with 145KB of repetition; the leaderboard
# counted it as a reliable run. gzip-ratio detector: degenerate ≈69:1 vs
# healthy 2-3:1 (calibrated on 2026-07-02 real outputs); threshold 15:1]
cat >"$T/bin/kimi" <<'SHIM'
#!/bin/sh
cat >/dev/null 2>&1 || true
i=0; while [ $i -lt 3000 ]; do printf 'wait wait wait wait wait wait wait wait '; i=$((i+1)); done
SHIM
chmod +x "$T/bin/kimi"
# NOTE: this suite deliberately runs WITHOUT set -e (naked expected-fail
# calls throughout) — do not flip it on here; a stray `set -e` mid-file
# aborted the suite at the next nonzero exit (caught pre-merge, PR #26).
bash "$S/run_reviewers.sh" --base main --out "$T/o5" --reviewers kimi --timeout-kimi 60 >/dev/null 2>&1 || true
assert_eq "degenerate output stamps failure_kind" \
  "$(jq -r '.failure_kind' "$T/o5/kimi.meta.json")" "degenerate_output"
assert_eq "degenerate output classifies exit 5" \
  "$(jq -r '.exit_code' "$T/o5/kimi.meta.json")" "5"
printf '{"exit_code": 5, "duration_s": 9, "timed_out": false, "output_bytes": 96000, "attempt": 1, "timeout_budget_s": 600, "failure_kind": "degenerate_output"}\n' >"$RUN/raw/glm.meta.json"
DEGLOG="$T/degen-runlog.jsonl"
CROSS_REVIEW_RUNLOG="$DEGLOG" bash "$S/append_runlog.sh" \
  --run-dir "$RUN" --project test --base main --pr - --pass 1 \
  --verdict CLEAN --convergent 0 --top "-" >/dev/null 2>&1
assert_eq "runlog status is degenerate, not ok" \
  "$(tail -1 "$DEGLOG" | jq -r '.reviewers.glm.status')" "degenerate"
rm -f "$RUN/raw/glm.meta.json"
printf '#!/bin/sh\ncat >/dev/null 2>&1 || true\nprintf "shim review: no findings\\n"\n' >"$T/bin/kimi"

echo "── OpenRouter cost accounting (fugu lesson) ──"
# [pin: PR #20 follow-up — usage:{include:true} cost lands in meta so the
# leaderboard can weight findings-per-dollar; fugu burned $4.74 in one call
# and only the billing dashboard knew]
cat >"$T/canned_or_response.json" <<'EOF'
{"choices":[{"message":{"content":"## Critical\nNone.\n\n## High\nNone. Clean — no findings."}}],"usage":{"prompt_tokens":1000,"completion_tokens":50,"cost":0.0123}}
EOF
cat >"$T/bin/curl" <<SHIM
#!/bin/sh
cat "$T/canned_or_response.json"
SHIM
chmod +x "$T/bin/curl"
bash "$S/run_reviewers.sh" --base main --out "$T/o6" --reviewers glm >/dev/null 2>&1 || true
assert_eq "OR meta carries cost_usd" "$(jq -r '.cost_usd' "$T/o6/glm.meta.json")" "0.0123"
assert_eq "OR meta carries tokens_prompt" "$(jq -r '.tokens_prompt' "$T/o6/glm.meta.json")" "1000"
assert_eq "OR request asks for usage accounting" \
  "$(jq -r '.usage.include' "$T/o6/glm.request.json")" "true"
rm -f "$T/bin/curl"

# The bearer token must reach curl without ever touching argv or disk.
#
# Disk: it used to go through a 0600 `--config` file removed right after curl
# returned — every path except a lap KILLED mid-call, where the rm never runs.
# 14 live tokens had accumulated across run dirs before this was noticed.
# Argv: `ps` is world-readable for the duration of the call (PR #18 pass 1).
cat >"$T/bin/curl" <<SHIM
#!/bin/sh
cat >"$T/curl_stdin.txt"
printf '%s\n' "\$@" >"$T/curl_argv.txt"
cat "$T/canned_or_response.json"
SHIM
chmod +x "$T/bin/curl"
: >"$T/curl_stdin.txt"; : >"$T/curl_argv.txt"
bash "$S/run_reviewers.sh" --base main --out "$T/o6b" --reviewers glm >/dev/null 2>&1 || true

if [[ -n "$(find "$T/o6b" -name '.*curl-auth*' 2>/dev/null)" ]]; then
  bad "no auth file is left in the run dir"
else
  ok "no auth file is left in the run dir"
fi

# CONTROL ×2 — "no file on disk" and "not in argv" are both satisfied by a
# build that stopped sending the header at all. Prove it still arrives, and
# that it arrives by the intended route.
assert_contains "the bearer token still reaches curl on stdin" \
  "$(cat "$T/curl_stdin.txt" 2>/dev/null)" "Authorization: Bearer sk-or-test-shim"
if grep -q 'sk-or-test-shim' "$T/curl_argv.txt" 2>/dev/null; then
  bad "the token never appears in argv"
else
  ok "the token never appears in argv"
fi
rm -f "$T/bin/curl"

# retry accumulates spend: attempt 1 charged but preamble-only (rc=5, retried),
# attempt 2 charged and good — meta must carry the SUM, not the last attempt
# [pin: codex P2, PR #28 pass 1 — leaderboard undercounted flaky-expensive]
cat >"$T/canned_or_preamble.json" <<'EOF'
{"choices":[{"message":{"content":"I will now begin reviewing the changes."}}],"usage":{"prompt_tokens":900,"completion_tokens":9,"cost":0.01}}
EOF
cat >"$T/canned_or_good.json" <<'EOF'
{"choices":[{"message":{"content":"## Critical\nNone.\n\n## High\nNone. Clean — no findings."}}],"usage":{"prompt_tokens":900,"completion_tokens":40,"cost":0.02}}
EOF
rm -f "$T/curl_calls"
cat >"$T/bin/curl" <<SHIM
#!/bin/sh
echo x >> "$T/curl_calls"
if [ "\$(wc -l < "$T/curl_calls" | tr -d ' ')" -ge 2 ]; then
  cat "$T/canned_or_good.json"
else
  cat "$T/canned_or_preamble.json"
fi
SHIM
chmod +x "$T/bin/curl"
bash "$S/run_reviewers.sh" --base main --out "$T/o7" --reviewers glm >/dev/null 2>&1 || true
assert_eq "retried run reports summed cost" "$(jq -r '.cost_usd' "$T/o7/glm.meta.json")" "0.030000"
assert_eq "second attempt recorded" "$(jq -r '.attempt' "$T/o7/glm.meta.json")" "2"
rm -f "$T/bin/curl" "$T/curl_calls"

# leaderboard: avg_cost_usd aggregates; roster draw halves a $0.50 reviewer
# NOTE: both seats here MUST have no draw_boost in reviewer_profiles.json, or
# the boost multiplier swamps the cost divisor this asserts. deepseek was the
# control until it took a 2.5 boost on 2026-08-14; minimax replaced it.
COSTLOG="$T/cost-runlog.jsonl"
cat >"$COSTLOG" <<'EOF'
{"ts":"2026-07-03T01:00:00Z","reviewers":{"glm":{"status":"ok","exit_code":0,"duration_s":50,"output_bytes":10,"timeout_budget_s":600,"cost_usd":0.5},"minimax":{"status":"ok","exit_code":0,"duration_s":50,"output_bytes":10,"timeout_budget_s":600,"cost_usd":0}}}
{"ts":"2026-07-03T02:00:00Z","reviewers":{"glm":{"status":"ok","exit_code":0,"duration_s":50,"output_bytes":10,"timeout_budget_s":600,"cost_usd":0.5},"minimax":{"status":"ok","exit_code":0,"duration_s":50,"output_bytes":10,"timeout_budget_s":600,"cost_usd":0}}}
EOF
CLB="$(CROSS_REVIEW_RUNLOG="$COSTLOG" bash "$S/leaderboard.sh" --mode json)"
assert_eq "leaderboard aggregates avg_cost_usd" \
  "$(jq -r '.[] | select(.reviewer=="glm") | .avg_cost_usd' <<<"$CLB")" "0.5"
assert_eq "zero-cost reviewer stays 0" \
  "$(jq -r '.[] | select(.reviewer=="minimax") | .avg_cost_usd' <<<"$CLB")" "0"
# identical twins except cost: expensive one draws at half weight
CAND="$(CROSS_REVIEW_RUNLOG="$COSTLOG" bash "$S/select_roster.sh" --seed 5 2>&1 >/dev/null | grep '^  candidate')"
W_GLM="$(printf '%s\n' "$CAND" | awk '$2=="glm" {sub(/weight=/,"",$NF); print $NF}')"
W_MM="$(printf '%s\n' "$CAND" | awk '$2=="minimax" {sub(/weight=/,"",$NF); print $NF}')"
assert_contains "candidate line surfaces cost" "$CAND" 'cost=$'
if [ -n "$W_GLM" ] && [ -n "$W_MM" ] && awk -v g="$W_GLM" -v d="$W_MM" 'BEGIN{exit !(g*1.9 < d*1.1 && g*2.1 > d*0.9)}'; then
  ok "\$0.50/run reviewer draws at ~half weight ($W_GLM vs $W_MM)"
else
  bad "cost divisor not applied in draw weight (glm=$W_GLM minimax=$W_MM)"
fi
# [pin: PR #28 pass 2 (codex) — a zero/garbage COST_PIVOT_USD must not
# divide-by-zero the draw or shrink the roster below the floor]
R_PIVOT0="$(COST_PIVOT_USD=0 CROSS_REVIEW_RUNLOG="$COSTLOG" bash "$S/select_roster.sh" --seed 5 2>/dev/null)"
N_PIVOT0="$(awk -F',' '{print NF}' <<<"$R_PIVOT0")"
if [ "$N_PIVOT0" -ge 3 ]; then ok "COST_PIVOT_USD=0 coerced to default (roster $N_PIVOT0)"; else bad "pivot=0 broke the draw ($R_PIVOT0)"; fi
R_PIVOTX="$(COST_PIVOT_USD=banana CROSS_REVIEW_RUNLOG="$COSTLOG" bash "$S/select_roster.sh" --seed 5 2>/dev/null)"
N_PIVOTX="$(awk -F',' '{print NF}' <<<"$R_PIVOTX")"
if [ "$N_PIVOTX" -ge 3 ]; then ok "non-numeric COST_PIVOT_USD coerced (roster $N_PIVOTX)"; else bad "pivot=banana broke the draw ($R_PIVOTX)"; fi
R_PIVOTD="$(COST_PIVOT_USD=0.0.1 CROSS_REVIEW_RUNLOG="$COSTLOG" bash "$S/select_roster.sh" --seed 5 2>/dev/null)"
N_PIVOTD="$(awk -F',' '{print NF}' <<<"$R_PIVOTD")"
if [ "$N_PIVOTD" -ge 3 ]; then ok "multi-dot COST_PIVOT_USD coerced (roster $N_PIVOTD)"; else bad "pivot=0.0.1 broke the draw ($R_PIVOTD)"; fi

echo "── anchor_findings.sh (resolve vs hallucinated location) ──"
cat >"$T/anchor.json" <<EOF
{"base":"main","head":"HEAD","findings":[
 {"id":"a1","severity":"High","file":"f.txt","line":5,"snippet":"line 42","claim":"real line","sources":["codex"]},
 {"id":"a2","severity":"Low","file":"f.txt","line":9,"snippet":"this text exists nowhere in the diff","claim":"hallucinated","sources":["glm"]}
]}
EOF
bash "$S/anchor_findings.sh" --findings "$T/anchor.json" --base main --repo "$REPO" --out "$T/anchored.json" >/dev/null 2>&1
assert_eq "real snippet anchors" \
  "$(jq -r '.findings[] | select(.id=="a1") | .anchor.resolved' "$T/anchored.json")" "true"
assert_eq "hallucinated snippet stays unanchored" \
  "$(jq -r '.findings[] | select(.id=="a2") | .anchor.resolved' "$T/anchored.json")" "false"

echo "── anchor_findings.sh --emit-events (opt-in, regression-safe) ──"
ANCHOR_EVLOG="$T/anchor-events.jsonl"
: >"$ANCHOR_EVLOG"
CROSS_REVIEW_FINDING_EVENTS="$ANCHOR_EVLOG" bash "$S/anchor_findings.sh" \
  --findings "$T/anchor.json" --base main --repo "$REPO" --out "$T/anchored-ev.json" \
  --emit-events run-anchor-test >/dev/null 2>&1
assert_eq "anchor output byte-identical with --emit-events added" \
  "$(jq -Sc . "$T/anchored.json")" "$(jq -Sc . "$T/anchored-ev.json")"
assert_eq "one anchored event per finding" "$(wc -l <"$ANCHOR_EVLOG" | tr -d ' ')" "2"
assert_eq "anchored event carries resolved=true for a1" \
  "$(jq -r 'select(.finding_id=="a1") | .resolved' "$ANCHOR_EVLOG")" "true"
assert_eq "anchored event carries resolved=false for a2" \
  "$(jq -r 'select(.finding_id=="a2") | .resolved' "$ANCHOR_EVLOG")" "false"

echo "── factcheck_findings.sh --emit-events (opt-in, keep_all fail-safe path) ──"
FACTCHECK_EVLOG="$T/factcheck-events.jsonl"
: >"$FACTCHECK_EVLOG"
cat >"$T/fc-findings.json" <<'EOF'
{"findings":[
 {"id":"c1","file":"f.txt","line":1,"snippet":"x","claim":"a claim","sources":["codex"]}
]}
EOF
# --diff pointed at a nonexistent path forces the keep_all fail-safe
# deterministically, before any agy/curl dispatch — zero network, per this
# suite's hard constraint (see file header).
CROSS_REVIEW_FINDING_EVENTS="$FACTCHECK_EVLOG" bash "$S/factcheck_findings.sh" \
  --findings "$T/fc-findings.json" --out "$T/fc-out.json" --diff /nonexistent/path \
  --emit-events run-factcheck-test >/dev/null 2>&1
assert_eq "keep_all fail-safe still emits factcheck_kept" \
  "$(jq -r '.event' "$FACTCHECK_EVLOG")" "factcheck_kept"
assert_contains "event carries the fail-safe reason" \
  "$(jq -r '.reason' "$FACTCHECK_EVLOG")" "diff file not found"

echo "── fingerprint_findings.sh (stable ids) ──"
cat >"$T/fp-findings.json" <<'EOF'
{"findings":[
 {"id":"f1","severity":"High","file":"a.ts","line":10,"snippet":"x","claim":"same claim text","sources":["codex","glm"]},
 {"id":"f2","severity":"Low","file":"b.ts","line":20,"snippet":"y","claim":"different claim","sources":[]}
]}
EOF
bash "$S/fingerprint_findings.sh" --findings "$T/fp-findings.json" --out "$T/fp-out1.json" --project fixtureproj >/dev/null 2>&1
bash "$S/fingerprint_findings.sh" --findings "$T/fp-findings.json" --out "$T/fp-out2.json" --project fixtureproj >/dev/null 2>&1
assert_eq "same (project,file,claim) -> same id across runs" \
  "$(jq -r '.findings[0].id' "$T/fp-out1.json")" "$(jq -r '.findings[0].id' "$T/fp-out2.json")"
assert_eq "local_id preserves the original sequence id" \
  "$(jq -r '.findings[0].local_id' "$T/fp-out1.json")" "f1"
F1_ID="$(jq -r '.findings[0].id' "$T/fp-out1.json")"
F2_ID="$(jq -r '.findings[1].id' "$T/fp-out1.json")"
if [[ "$F1_ID" =~ ^f-[0-9a-f]{8}$ ]]; then ok "id matches ^f-[0-9a-f]{8}\$ shape"; else bad "id shape wrong: $F1_ID"; fi
if [[ "$F1_ID" != "$F2_ID" ]]; then ok "distinct findings get distinct ids"; else bad "different findings collided on id"; fi
sed 's/same claim text/reworded claim text/' "$T/fp-findings.json" >"$T/fp-findings2.json"
bash "$S/fingerprint_findings.sh" --findings "$T/fp-findings2.json" --out "$T/fp-out3.json" --project fixtureproj >/dev/null 2>&1
F1_ID_REWORDED="$(jq -r '.findings[0].id' "$T/fp-out3.json")"
if [[ "$F1_ID_REWORDED" != "$F1_ID" ]]; then ok "reworded claim changes the id (known limitation, expected)"; else bad "id unexpectedly stable across reworded claim"; fi
# [pin: codex P2 on PR #38 — case-distinct files (Foo.ts vs foo.ts) must not
# collide; only the CLAIM is case-normalized, file/project keep exact case]
cat >"$T/fp-case.json" <<'EOF'
{"findings":[
 {"id":"c1","severity":"Low","file":"Foo.ts","line":1,"snippet":"x","claim":"same claim","sources":[]},
 {"id":"c2","severity":"Low","file":"foo.ts","line":1,"snippet":"x","claim":"same claim","sources":[]},
 {"id":"c3","severity":"Low","file":"Foo.ts","line":1,"snippet":"x","claim":"SAME   claim","sources":[]}
]}
EOF
bash "$S/fingerprint_findings.sh" --findings "$T/fp-case.json" --out "$T/fp-case-out.json" --project fixtureproj >/dev/null 2>&1
C1="$(jq -r '.findings[0].id' "$T/fp-case-out.json")"
C2="$(jq -r '.findings[1].id' "$T/fp-case-out.json")"
C3="$(jq -r '.findings[2].id' "$T/fp-case-out.json")"
if [[ "$C1" != "$C2" ]]; then ok "case-distinct files get distinct ids"; else bad "Foo.ts and foo.ts collided on id"; fi
assert_eq "claim stays case/whitespace-insensitive" "$C1" "$C3"

echo "── append_finding_event.sh (append, validation, concurrency) ──"
EVLOG="$T/events.jsonl"
: >"$EVLOG"
CROSS_REVIEW_FINDING_EVENTS="$EVLOG" bash "$S/append_finding_event.sh" \
  --event proposed --finding-id f-aaaa1111 --run-id run-x --fields '{"reviewer":"codex"}' >/dev/null 2>&1
assert_eq "valid append lands one line" "$(wc -l <"$EVLOG" | tr -d ' ')" "1"
assert_eq "event field round-trips" "$(jq -r '.event' "$EVLOG")" "proposed"
assert_eq "finding_id field round-trips" "$(jq -r '.finding_id' "$EVLOG")" "f-aaaa1111"
assert_eq "fields payload merges in" "$(jq -r '.reviewer' "$EVLOG")" "codex"
CROSS_REVIEW_FINDING_EVENTS="$EVLOG" bash "$S/append_finding_event.sh" \
  --event x --finding-id f-1 --run-id r-1 --fields 'not-json' >/dev/null 2>&1
assert_eq "malformed --fields rejects (exit 2)" "$?" "2"
CONCLOG="$T/conc-events.jsonl"
: >"$CONCLOG"
for i in $(seq 1 20); do
  CROSS_REVIEW_FINDING_EVENTS="$CONCLOG" bash "$S/append_finding_event.sh" \
    --event proposed --finding-id "f-conc$i" --run-id run-conc --fields "{\"i\":$i}" >/dev/null 2>&1 &
done
wait
assert_eq "concurrent appends: all 20 lines present" "$(wc -l <"$CONCLOG" | tr -d ' ')" "20"
assert_eq "concurrent appends: every line parses as JSON" \
  "$(jq -c . "$CONCLOG" 2>/dev/null | grep -c '^.' || true)" "20"

echo "── import_runlog.sh (idempotent merge) ──"
SRC="$T/src.jsonl"; DST="$T/dst.jsonl"; : >"$DST"
printf '{"ts":"2026-06-01T00:00:00Z","reviewers":{"codex":{"status":"ok"}}}\nnot json garbage\n{"ts":"2026-06-02T00:00:00Z","reviewers":{"kimi":{"status":"ok"}}}\n' >"$SRC"
bash "$S/import_runlog.sh" --from "$SRC" --into "$DST" >/dev/null 2>&1
assert_eq "import: valid lines merged, garbage skipped" "$(wc -l <"$DST" | tr -d ' ')" "2"
bash "$S/import_runlog.sh" --from "$SRC" --into "$DST" >/dev/null 2>&1
assert_eq "import: re-import adds nothing (idempotent)" "$(wc -l <"$DST" | tr -d ' ')" "2"

echo "── worktree.sh sweep/end ownership (issue #6) ──"
# Sandboxed roots via the test-only env overrides; dirs backdated so -mmin matches.
WTROOT="$T/wtroot"; FAKETMP="$T/faketmp"; mkdir -p "$WTROOT" "$FAKETMP"
mkdir -p "$FAKETMP/cr-unrelated"          # someone else's dir — must survive
mkdir -p "$FAKETMP/cr-legacy-owned"       # our marker → swept
printf 'created-by=cross-review/worktree.sh\n' >"$FAKETMP/cr-legacy-owned/.cross-review-worktree"
mkdir -p "$FAKETMP/cr-legacy-gitptr"      # pre-marker legacy worktree pointer → swept
printf 'gitdir: /some/repo/.git/worktrees/cr-old-123\n' >"$FAKETMP/cr-legacy-gitptr/.git"
mkdir -p "$WTROOT/cr-stale-canonical"     # canonical root is ours by construction → swept
touch -t 202601010000 "$FAKETMP/cr-unrelated" "$FAKETMP/cr-legacy-owned" "$FAKETMP/cr-legacy-gitptr" "$WTROOT/cr-stale-canonical"
CROSS_REVIEW_WORKTREE_ROOT="$WTROOT" CROSS_REVIEW_LEGACY_TMP_ROOT="$FAKETMP" \
  bash "$S/worktree.sh" sweep --older-than-hours 1 >/dev/null 2>&1
if [[ -d "$FAKETMP/cr-unrelated" ]]; then ok "unrelated tmp cr-* dir survives sweep"; else bad "unrelated tmp dir was deleted"; fi
if [[ ! -d "$FAKETMP/cr-legacy-owned" ]]; then ok "marker-owned legacy dir swept"; else bad "marker-owned legacy dir not swept"; fi
if [[ ! -d "$FAKETMP/cr-legacy-gitptr" ]]; then ok "git-pointer legacy dir swept"; else bad "git-pointer legacy dir not swept"; fi
if [[ ! -d "$WTROOT/cr-stale-canonical" ]]; then ok "stale canonical-root dir swept"; else bad "canonical stale dir not swept"; fi

# end: refuses an unowned legacy path, removes an owned one
mkdir -p "$FAKETMP/cr-end-unowned" "$FAKETMP/cr-end-owned"
printf 'created-by=cross-review/worktree.sh\n' >"$FAKETMP/cr-end-owned/.cross-review-worktree"
if CROSS_REVIEW_WORKTREE_ROOT="$WTROOT" CROSS_REVIEW_LEGACY_TMP_ROOT="$FAKETMP" \
  bash "$S/worktree.sh" end --worktree "$FAKETMP/cr-end-unowned" >/dev/null 2>&1; then
  bad "end removed an unowned legacy path (exit 0)"
else
  if [[ -d "$FAKETMP/cr-end-unowned" ]]; then ok "end refuses unowned legacy path"; else bad "end deleted unowned dir despite nonzero exit"; fi
fi
CROSS_REVIEW_WORKTREE_ROOT="$WTROOT" CROSS_REVIEW_LEGACY_TMP_ROOT="$FAKETMP" \
  bash "$S/worktree.sh" end --worktree "$FAKETMP/cr-end-owned" >/dev/null 2>&1
if [[ ! -d "$FAKETMP/cr-end-owned" ]]; then ok "end removes marker-owned legacy path"; else bad "end did not remove owned dir"; fi

# start drops the ownership marker in every new worktree
( cd "$REPO" && CROSS_REVIEW_WORKTREE_ROOT="$WTROOT" CROSS_REVIEW_RUN_ROOT="$T/runroot" \
    bash "$S/worktree.sh" start --ref HEAD --id marker-test --base main >"$T/wt-start.json" 2>/dev/null )
WT_PATH="$(jq -r '.worktree' "$T/wt-start.json")"
if [[ -n "$WT_PATH" && -f "$WT_PATH/.cross-review-worktree" ]]; then ok "start drops ownership marker"; else bad "no marker in fresh worktree ($WT_PATH)"; fi

# ── start records the reviewed SHA and writes context.json itself ──
# Six real reviews (kindred-mama-ai #3214/#3252/#3264/#3269/#3276/#3280) landed
# 68-676KB of reviewer output with no context.json, because writing it was prose
# in SKILL.md that the caller skipped. A run that never recorded its SHA cannot
# be reconciled afterwards at all — the stamp has nothing truthful to carry.
WT_RUN="$(jq -r '.run_dir' "$T/wt-start.json")"
if [[ -f "$WT_RUN/context.json" ]]; then ok "start writes context.json"; else bad "no context.json in $WT_RUN"; fi
if jq -e . "$WT_RUN/context.json" >/dev/null 2>&1; then ok "context.json is valid JSON"; else bad "context.json is not parseable"; fi
assert_eq "context.json head_sha == the commit actually checked out" \
  "$(jq -r '.head_sha' "$WT_RUN/context.json")" "$(git -C "$REPO" rev-parse HEAD)"
assert_eq "context.json base_sha == the base ref's commit" \
  "$(jq -r '.base_sha' "$WT_RUN/context.json")" "$(git -C "$REPO" rev-parse main)"
# stdout and the on-disk record must be the same bytes — two sources of truth
# about what was reviewed is how a stamp ends up disagreeing with the run.
if diff -q <(tr -d '\n' <"$T/wt-start.json") <(tr -d '\n' <"$WT_RUN/context.json") >/dev/null 2>&1; then
  ok "context.json is byte-identical to start's stdout"
else bad "context.json and stdout disagree"; fi
CROSS_REVIEW_WORKTREE_ROOT="$WTROOT" bash "$S/worktree.sh" end --worktree "$WT_PATH" >/dev/null 2>&1 || true

# The repo field is written to a file that outlives the run, so a credential in
# the remote URL must never reach it. Both fixtures carry the same password.
OREPO="$T/repo-origin"; mkdir -p "$OREPO"
( cd "$OREPO" && git init -q -b main 2>/dev/null || git -C "$OREPO" init -q
  echo x >"$OREPO/f"; git -C "$OREPO" add .
  git -C "$OREPO" -c user.email=t@t -c user.name=t commit -qm init ) >/dev/null 2>&1
git -C "$OREPO" remote add origin 'https://user:s3cr3tpw@github.com/Owner/Name.git'
( cd "$OREPO" && CROSS_REVIEW_WORKTREE_ROOT="$WTROOT" CROSS_REVIEW_RUN_ROOT="$T/runroot" \
    bash "$S/worktree.sh" start --ref HEAD --id cred-test --base main >"$T/wt-cred.json" 2>/dev/null )
CRED_RUN="$(jq -r '.run_dir' "$T/wt-cred.json")"
assert_eq "credentialed remote reduces to owner/repo" \
  "$(jq -r '.repo' "$CRED_RUN/context.json")" "Owner/Name"
if grep -q 's3cr3tpw' "$CRED_RUN/context.json"; then bad "context.json leaked the remote credential"; else ok "context.json carries no credential"; fi
CROSS_REVIEW_WORKTREE_ROOT="$WTROOT" bash "$S/worktree.sh" end --worktree "$(jq -r '.worktree' "$T/wt-cred.json")" >/dev/null 2>&1 || true

# A one-component remote puts the userinfo field where the owner would be —
# the validating regex must reject it outright rather than record `pw@host/x`.
git -C "$OREPO" remote set-url origin 'https://user:s3cr3tpw@github.com/justrepo'
( cd "$OREPO" && CROSS_REVIEW_WORKTREE_ROOT="$WTROOT" CROSS_REVIEW_RUN_ROOT="$T/runroot" \
    bash "$S/worktree.sh" start --ref HEAD --id cred2-test --base main >"$T/wt-cred2.json" 2>/dev/null )
CRED2_RUN="$(jq -r '.run_dir' "$T/wt-cred2.json")"
assert_eq "unparseable remote fails closed to empty repo" \
  "$(jq -r '.repo' "$CRED2_RUN/context.json")" ""

# No credential at all, still only one path component: awk hands back
# "github.com/justrepo", which a symmetric regex accepts and records a HOSTNAME
# as the owner. GitHub owners cannot contain dots; repos can. (minimax L.)
git -C "$OREPO" remote set-url origin 'https://github.com/justrepo'
( cd "$OREPO" && CROSS_REVIEW_WORKTREE_ROOT="$WTROOT" CROSS_REVIEW_RUN_ROOT="$T/runroot" \
    bash "$S/worktree.sh" start --ref HEAD --id host-owner --base main >"$T/wt-host.json" 2>/dev/null )
assert_eq "a hostname is not accepted as the owner" \
  "$(jq -r '.repo' "$(jq -r '.run_dir' "$T/wt-host.json")/context.json")" ""
CROSS_REVIEW_WORKTREE_ROOT="$WTROOT" bash "$S/worktree.sh" end --worktree "$(jq -r '.worktree' "$T/wt-host.json")" >/dev/null 2>&1 || true

# A remote ending .git/ : stripping .git BEFORE the trailing slash leaves the
# suffix behind, and "Owner/Name.git" passes the regex. (antigravity M.)
git -C "$OREPO" remote set-url origin 'https://github.com/Owner/Name.git/'
( cd "$OREPO" && CROSS_REVIEW_WORKTREE_ROOT="$WTROOT" CROSS_REVIEW_RUN_ROOT="$T/runroot" \
    bash "$S/worktree.sh" start --ref HEAD --id trailing-slash --base main >"$T/wt-slash.json" 2>/dev/null )
assert_eq "a trailing slash after .git still reduces to owner/repo" \
  "$(jq -r '.repo' "$(jq -r '.run_dir' "$T/wt-slash.json")/context.json")" "Owner/Name"
CROSS_REVIEW_WORKTREE_ROOT="$WTROOT" bash "$S/worktree.sh" end --worktree "$(jq -r '.worktree' "$T/wt-slash.json")" >/dev/null 2>&1 || true
if grep -q 's3cr3tpw' "$CRED2_RUN/context.json"; then bad "one-component remote leaked the credential"; else ok "one-component remote leaks nothing"; fi
CROSS_REVIEW_WORKTREE_ROOT="$WTROOT" bash "$S/worktree.sh" end --worktree "$(jq -r '.worktree' "$T/wt-cred2.json")" >/dev/null 2>&1 || true

echo "── run_with_timeout bash-watchdog fallback (issue #7) ──"
printf '#!/bin/sh\ncat >/dev/null 2>&1 || true\nsleep 30\n' >"$T/bin/kimi"
WD_START=$(date +%s)
CROSS_REVIEW_FORCE_NO_TIMEOUT_BIN=1 bash "$S/run_reviewers.sh" --base main --out "$T/o4" --reviewers kimi --timeout-kimi 3 >/dev/null 2>&1
WD_ELAPSED=$(( $(date +%s) - WD_START ))
assert_eq "watchdog classifies timeout (timed_out=true)" "$(jq -r '.timed_out' "$T/o4/kimi.meta.json")" "true"
if [[ "$WD_ELAPSED" -lt 25 ]]; then ok "watchdog bounded the run (${WD_ELAPSED}s, shim sleeps 30)"; else bad "watchdog did not bound the run (${WD_ELAPSED}s)"; fi
printf '#!/bin/sh\ncat >/dev/null 2>&1 || true\nprintf "shim review: no findings\\n"\n' >"$T/bin/kimi"

echo "── analyze_runlog.sh degraded-reviewer warnings (jq pipe-context crash) ──"
# [pin: 2026-07-03 — emit_warning's `["…"] | index(.reviewer)` re-bound `.` to
# the array literal, so jq crashed ("Cannot index array with string") for
# exactly the reviewers degraded enough to warn about, and warn mode reported
# "all reviewers nominal" while north sat at a 50% timeout rate.]
WARNLOG="$T/warn-runlog.jsonl"
cat >"$WARNLOG" <<'EOF'
{"ts":"2026-07-03T01:00:00Z","reviewers":{"north":{"status":"ok","exit_code":0,"duration_s":300,"output_bytes":10,"timeout_budget_s":600},"codex":{"status":"ok","exit_code":0,"duration_s":100,"output_bytes":10,"timeout_budget_s":300}}}
{"ts":"2026-07-03T02:00:00Z","reviewers":{"north":{"status":"timed_out","exit_code":124,"duration_s":600,"output_bytes":0,"timeout_budget_s":600},"codex":{"status":"timed_out","exit_code":124,"duration_s":300,"output_bytes":0,"timeout_budget_s":300}}}
{"ts":"2026-07-03T03:00:00Z","reviewers":{"north":{"status":"timed_out","exit_code":124,"duration_s":600,"output_bytes":0,"timeout_budget_s":600},"codex":{"status":"timed_out","exit_code":124,"duration_s":300,"output_bytes":0,"timeout_budget_s":300}}}
EOF
WARN_OUT="$(CROSS_REVIEW_RUNLOG="$WARNLOG" bash "$S/analyze_runlog.sh" --mode warn 2>&1)"
assert_contains "pool reviewer at 66% timeout rate warns" "$WARN_OUT" "north timed out"
assert_contains "flag reviewer warning suggests --timeout-codex" "$WARN_OUT" "--timeout-codex"

echo "── analyze_runlog.sh sleep-suspect samples (wall clock past enforced budget) ──"
# [pin: 2026-07-03 — the Mac slept mid-round (pmset: Dark Wake Thermal
# Emergency); gtimeout/curl timers freeze during system sleep while date +%s
# keeps counting, so codex logged 1024s against a 300s budget with rc=0 and
# the analyzer suggested bumping every timeout. Sleep-inflated samples must
# be excluded from tuning math, not learned from.]
SLEEPLOG="$T/sleep-runlog.jsonl"
cat >"$SLEEPLOG" <<'EOF'
{"ts":"2026-07-03T01:00:00Z","reviewers":{"codex":{"status":"ok","exit_code":0,"duration_s":100,"output_bytes":10,"timeout_budget_s":300}}}
{"ts":"2026-07-03T02:00:00Z","reviewers":{"codex":{"status":"ok","exit_code":0,"duration_s":110,"output_bytes":10,"timeout_budget_s":300}}}
{"ts":"2026-07-03T03:00:00Z","reviewers":{"codex":{"status":"ok","exit_code":0,"duration_s":1024,"output_bytes":10,"timeout_budget_s":300}}}
{"ts":"2026-07-03T04:00:00Z","reviewers":{"codex":{"status":"ok","exit_code":0,"duration_s":120,"output_bytes":10,"timeout_budget_s":300}}}
EOF
SLEEP_OUT="$(CROSS_REVIEW_RUNLOG="$SLEEPLOG" bash "$S/analyze_runlog.sh" --mode report 2>&1)"
assert_contains "report surfaces sleep-suspect count" "$SLEEP_OUT" "sleep_suspect=1"
case "$SLEEP_OUT" in
  *"SUGGEST: bump codex"*) bad "sleep-inflated p95 still drives a timeout bump" ;;
  *) ok "no timeout bump from sleep-inflated p95" ;;
esac

echo "── leaderboard.sh sleep-killed timeout exclusion ──"
# [pin: 2026-07-03 — north's 4 same-day timeouts all overran the enforced
# curl --max-time on wall clock (machine asleep mid-transfer); they say
# nothing about the provider and must not ding reliability.]
SLPLB="$T/sleeplb-runlog.jsonl"
cat >"$SLPLB" <<'EOF'
{"ts":"2026-07-03T01:00:00Z","reviewers":{"north":{"status":"ok","exit_code":0,"duration_s":400,"output_bytes":10,"timeout_budget_s":600}}}
{"ts":"2026-07-03T02:00:00Z","reviewers":{"north":{"status":"timed_out","exit_code":124,"duration_s":926,"output_bytes":0,"timeout_budget_s":600}}}
EOF
LB2="$(CROSS_REVIEW_RUNLOG="$SLPLB" bash "$S/leaderboard.sh" --mode json)"
assert_eq "sleep-killed timeout excluded from attempts" \
  "$(jq -r '.[] | select(.reviewer=="north") | .attempts' <<<"$LB2")" "1"
assert_eq "reliability unpunished by sleep-killed timeout" \
  "$(jq -r '.[] | select(.reviewer=="north") | .score' <<<"$LB2")" "75"
# a genuine timeout (duration ≈ budget) still counts against reliability
GENLB="$T/genlb-runlog.jsonl"
cat >"$GENLB" <<'EOF'
{"ts":"2026-07-03T01:00:00Z","reviewers":{"north":{"status":"ok","exit_code":0,"duration_s":400,"output_bytes":10,"timeout_budget_s":600}}}
{"ts":"2026-07-03T02:00:00Z","reviewers":{"north":{"status":"timed_out","exit_code":124,"duration_s":610,"output_bytes":0,"timeout_budget_s":600}}}
EOF
LB3="$(CROSS_REVIEW_RUNLOG="$GENLB" bash "$S/leaderboard.sh" --mode json)"
assert_eq "genuine timeout still counts as an attempt" \
  "$(jq -r '.[] | select(.reviewer=="north") | .attempts' <<<"$LB3")" "2"

echo "── no-verdict (preamble-only) output detection ──"
# [pin: PR #2620 2026-07-03 — kimi delivered a 161-byte preamble with no
# findings and no clean verdict; it logged status ok, silently starving
# synthesis of the vote while the leaderboard counted a reliable run. The
# gzip-ratio gate can't catch short non-repetitive text.]
cat >"$T/bin/kimi" <<'SHIM'
#!/bin/sh
cat >/dev/null 2>&1 || true
printf "I will now examine the changes on the current branch against the base and report back with a thorough assessment of the code.\n"
SHIM
chmod +x "$T/bin/kimi"
bash "$S/run_reviewers.sh" --base main --out "$T/o6" --reviewers kimi --timeout-kimi 60 >/dev/null 2>&1 || true
assert_eq "preamble-only output stamps no_verdict_output" \
  "$(jq -r '.failure_kind' "$T/o6/kimi.meta.json")" "no_verdict_output"
assert_eq "preamble-only output classifies exit 5" \
  "$(jq -r '.exit_code' "$T/o6/kimi.meta.json")" "5"
# a short but explicit clean verdict must stay ok — brevity alone is not failure
printf '#!/bin/sh\ncat >/dev/null 2>&1 || true\nprintf "No findings - the change looks correct.\\n"\n' >"$T/bin/kimi"
bash "$S/run_reviewers.sh" --base main --out "$T/o7" --reviewers kimi --timeout-kimi 60 >/dev/null 2>&1
assert_eq "short explicit clean verdict stays ok" \
  "$(jq -r '.exit_code' "$T/o7/kimi.meta.json")" "0"
printf '{"exit_code": 5, "duration_s": 9, "timed_out": false, "output_bytes": 161, "attempt": 2, "timeout_budget_s": 600, "failure_kind": "no_verdict_output"}\n' >"$RUN/raw/kimi.meta.json"
NVLOG="$T/nv-runlog.jsonl"
CROSS_REVIEW_RUNLOG="$NVLOG" bash "$S/append_runlog.sh" \
  --run-dir "$RUN" --project test --base main --pr - --pass 1 \
  --verdict CLEAN --convergent 0 --top "-" >/dev/null 2>&1
assert_eq "runlog status is no_verdict, not ok" \
  "$(tail -1 "$NVLOG" | jq -r '.reviewers.kimi.status')" "no_verdict"
rm -f "$RUN/raw/kimi.meta.json"
printf '#!/bin/sh\ncat >/dev/null 2>&1 || true\nprintf "shim review: no findings\\n"\n' >"$T/bin/kimi"

echo "── reviewer-binary PATH guard (background-shell 127) ──"
# [pin: 2026-07-03 — background-dispatched rounds ran with a PATH lacking
# ~/.local/bin, so `timeout … kimi` exited 127 ("No such file or directory")
# and kimi logged failed=6 of 10 runs. detect_reviewers.sh had the ~/.local/bin
# guard; run_reviewers.sh (the dispatcher) did not — detection said available,
# dispatch said command-not-found.]
mkdir -p "$HOME/.local/bin"
printf '#!/bin/sh\ncat >/dev/null 2>&1 || true\nprintf "shim review: no findings\\n"\n' >"$HOME/.local/bin/kimi"
chmod +x "$HOME/.local/bin/kimi"
STRIPPED_PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -vx "$T/bin" | paste -s -d: -)"
PATH="$STRIPPED_PATH" bash "$S/run_reviewers.sh" --base main --out "$T/o8" --reviewers kimi --timeout-kimi 60 >/dev/null 2>&1
assert_eq "reviewer binary resolved via ~/.local/bin PATH guard" \
  "$(jq -r '.exit_code' "$T/o8/kimi.meta.json" 2>/dev/null)" "0"
rm -f "$HOME/.local/bin/kimi"

echo "── agy no-verdict gate: guarded by the rc/bytes if-elif chain ──"
# [pin: PR #27 pass 1 — mimo+minimax convergent claim that the agy runner's
# `elif output_no_verdict` lacks the rc==0 guard and would mask real failures
# as no_verdict_output. FALSIFIED: the chain's opening
# `if [[ $rc -eq 0 && "$bytes" -eq 0 || $rc -ne 0 ]]` catches every non-zero
# rc first, so the elif is only reachable when rc==0 && bytes>0 — diff-only
# reviewers couldn't see the enclosing if outside the hunk. Both directions
# verified live before pinning (see feedback_convergent_not_correct).]
cat >"$T/bin/agy" <<'SHIM'
#!/bin/sh
if [ "$1" = "models" ]; then printf "Gemini 3.5 Flash (High)\nGemini 3.1 Pro (High)\n"; exit 0; fi
printf "Error: something went wrong during startup\n"
exit 1
SHIM
chmod +x "$T/bin/agy"
bash "$S/run_reviewers.sh" --base main --out "$T/o9" --reviewers antigravity --timeout 60 >/dev/null 2>&1 || true
assert_eq "agy rc=1 + short no-marker stdout keeps real exit code" \
  "$(jq -r '.exit_code' "$T/o9/antigravity.meta.json")" "1"
assert_eq "agy rc=1 not reclassified as no_verdict_output" \
  "$(jq -r '.failure_kind' "$T/o9/antigravity.meta.json")" "null"
cat >"$T/bin/agy" <<'SHIM'
#!/bin/sh
if [ "$1" = "models" ]; then printf "Gemini 3.5 Flash (High)\nGemini 3.1 Pro (High)\n"; exit 0; fi
printf "I will now examine the changes on the current branch and report back with an assessment.\n"
exit 0
SHIM
chmod +x "$T/bin/agy"
bash "$S/run_reviewers.sh" --base main --out "$T/o10" --reviewers antigravity --timeout 60 >/dev/null 2>&1 || true
assert_eq "agy rc=0 preamble-only stamps no_verdict_output" \
  "$(jq -r '.failure_kind' "$T/o10/antigravity.meta.json")" "no_verdict_output"
echo "── agy headless soft-deny classifies apart from empty_output ──"
# [pin: 2026-07-20 — a soft-denied tool confirmation (agy >=1.1.3 headless)
# used to land as failure_kind=empty_output, whose documented remedy is
# "re-run agy login". That misdirection got the Gemini seats declared dead
# while agy was in fact healthy. The two MUST classify separately: gagged
# (prompt-shape bug, seat fine) vs unauthed (re-login).]
cat >"$T/bin/agy" <<'SHIM'
#!/bin/sh
if [ "$1" = "models" ]; then printf "Gemini 3.5 Flash (High)\nGemini 3.1 Pro (High)\n"; exit 0; fi
while [ $# -gt 0 ]; do
  if [ "$1" = "--log-file" ]; then printf 'tool_confirmation_manager.go:183] Print mode: soft-denying tool confirmation\n' >"$2"; fi
  shift
done
printf 'jetski: no output produced - a tool required the "command" permission that headless mode cannot prompt for, so it was auto-denied.\n' >&2
exit 0
SHIM
chmod +x "$T/bin/agy"
bash "$S/run_reviewers.sh" --base main --out "$T/o11" --reviewers antigravity --timeout 60 >/dev/null 2>&1 || true
assert_eq "agy soft-deny stamps headless_permission_denied" \
  "$(jq -r '.failure_kind' "$T/o11/antigravity.meta.json")" "headless_permission_denied"
assert_eq "agy soft-deny is NOT misfiled as empty_output" \
  "$(jq -r 'select(.failure_kind == "empty_output") | "LEAKED"' "$T/o11/antigravity.meta.json")" ""
assert_eq "soft-deny maps to status permission_denied in the runlog" \
  "$(jq -c '. + {status: (if .timed_out == true then "timed_out"
                          elif .failure_kind == "quota_exhausted" then "quota"
                          elif .failure_kind == "headless_permission_denied" then "permission_denied"
                          elif .exit_code == 0 and (.output_bytes // 0) > 0 then "ok"
                          elif .exit_code == 0 then "empty"
                          else "failed" end)} | .status' "$T/o11/antigravity.meta.json")" '"permission_denied"'

echo "── agy internal print-timeout classifies apart from empty_output/failed ──"
# [pin: 2026-08-03 — Gemini 3.1 Pro at High effort needs 300-400s on a 100KB
# prompt. When agy's own --print-timeout expires first it exits rc=1 with 0
# bytes and stderr "Error: timeout waiting for response"; coreutils `timeout`
# never fires, so this used to land as a bare failed run with failure_kind=null
# and timed_out=false — invisible to the runlog's timeout-rate warning, and one
# step away from the empty_output "go re-auth" misdirection. It is a timeout:
# it must say so, and the remedy is a bigger budget.]
cat >"$T/bin/agy" <<'SHIM'
#!/bin/sh
if [ "$1" = "models" ]; then printf "Gemini 3.5 Flash (High)\nGemini 3.1 Pro (High)\n"; exit 0; fi
printf 'Error: timeout waiting for response\n' >&2
exit 1
SHIM
chmod +x "$T/bin/agy"
bash "$S/run_reviewers.sh" --base main --out "$T/o13" --reviewers antigravity --timeout 60 >/dev/null 2>&1 || true
assert_eq "agy print-timeout stamps print_timeout" \
  "$(jq -r '.failure_kind' "$T/o13/antigravity.meta.json")" "print_timeout"
assert_eq "agy print-timeout marks timed_out=true so the runlog warning sees it" \
  "$(jq -r '.timed_out' "$T/o13/antigravity.meta.json")" "true"
assert_eq "agy print-timeout is NOT misfiled as empty_output" \
  "$(jq -r 'select(.failure_kind == "empty_output") | "LEAKED"' "$T/o13/antigravity.meta.json")" ""
assert_eq "print-timeout maps to status timed_out in the runlog" \
  "$(jq -c '. + {status: (if .timed_out == true then "timed_out"
                          elif .failure_kind == "quota_exhausted" then "quota"
                          elif .failure_kind == "headless_permission_denied" then "permission_denied"
                          elif .exit_code == 0 and (.output_bytes // 0) > 0 then "ok"
                          elif .exit_code == 0 then "empty"
                          else "failed" end)} | .status' "$T/o13/antigravity.meta.json")" '"timed_out"'

# A non-timeout nonzero exit must NOT be swallowed by the print_timeout branch.
cat >"$T/bin/agy" <<'SHIM'
#!/bin/sh
if [ "$1" = "models" ]; then printf "Gemini 3.5 Flash (High)\nGemini 3.1 Pro (High)\n"; exit 0; fi
printf 'Error: something else entirely\n' >&2
exit 1
SHIM
chmod +x "$T/bin/agy"
bash "$S/run_reviewers.sh" --base main --out "$T/o14" --reviewers antigravity --timeout 60 >/dev/null 2>&1 || true
assert_eq "unrelated agy failure does not claim print_timeout" \
  "$(jq -r '.failure_kind' "$T/o14/antigravity.meta.json")" "null"
assert_eq "unrelated agy failure stays timed_out=false" \
  "$(jq -r '.timed_out' "$T/o14/antigravity.meta.json")" "false"

# Per-attempt artifacts must survive the retry that overwrites the canonical
# paths — without them attempt 1's cause is unknowable (this flake took a
# rebuild of the evidence trail to diagnose).
assert_eq "attempt-stamped meta.json is preserved for forensics" \
  "$(jq -r '.failure_kind' "$T/o13/antigravity.attempt1.meta.json" 2>/dev/null)" "print_timeout"

# Silent agy (no log line, no stderr) must STILL classify as empty_output —
# the new branch must not swallow the genuine expired-auth case.
cat >"$T/bin/agy" <<'SHIM'
#!/bin/sh
if [ "$1" = "models" ]; then printf "Gemini 3.5 Flash (High)\nGemini 3.1 Pro (High)\n"; exit 0; fi
exit 0
SHIM
chmod +x "$T/bin/agy"
bash "$S/run_reviewers.sh" --base main --out "$T/o12" --reviewers antigravity --timeout 60 >/dev/null 2>&1 || true
assert_eq "silent agy still classifies as empty_output (auth path intact)" \
  "$(jq -r '.failure_kind' "$T/o12/antigravity.meta.json")" "empty_output"

printf '#!/bin/sh\nif [ "$1" = "models" ]; then printf "Gemini 3.5 Flash (High)\\nGemini 3.1 Pro (High)\\n"; fi\n' >"$T/bin/agy"
chmod +x "$T/bin/agy"

echo "── analyze_runlog.sh contaminated-window NOTE (raw vs clean timeout rate) ──"
# [pin: PR #27 pass 1, minimax M2 — a window whose timeouts are all
# sleep-killed must emit an informational NOTE, not a WARN demanding tuning.]
CONTAMLOG="$T/contam-runlog.jsonl"
cat >"$CONTAMLOG" <<'EOF'
{"ts":"2026-07-03T01:00:00Z","reviewers":{"north":{"status":"ok","exit_code":0,"duration_s":300,"output_bytes":10,"timeout_budget_s":600}}}
{"ts":"2026-07-03T02:00:00Z","reviewers":{"north":{"status":"timed_out","exit_code":124,"duration_s":926,"output_bytes":0,"timeout_budget_s":600}}}
{"ts":"2026-07-03T03:00:00Z","reviewers":{"north":{"status":"timed_out","exit_code":124,"duration_s":930,"output_bytes":0,"timeout_budget_s":600}}}
EOF
CONTAM_OUT="$(CROSS_REVIEW_RUNLOG="$CONTAMLOG" bash "$S/analyze_runlog.sh" --mode warn 2>&1)"
assert_contains "sleep-contaminated timeout window notes, not warns" "$CONTAM_OUT" "NOTE: north raw timeout rate 66"
case "$CONTAM_OUT" in
  *"WARN: north timed out"*) bad "contaminated window still fires a tuning WARN" ;;
  *) ok "no tuning WARN from contaminated window" ;;
esac

echo "── kimi27 rotation seat (direct-Moonshot, draw_boost) ──"
# [pin: 2026-07-03, per Gabriel — kimi-k2.7-code joins the rotation pool as a
# direct-Moonshot seat (NOT an OpenRouter fallback; the no-OR-for-first-party
# policy is untouched) with a draw_boost so it is selected frequently while it
# earns leaderboard data. Retired 2026-07-12 (10 sampled runs, score 72) — the
# profile's draw_boost dropped from 2.5 to 1.0, so this now pins the boost
# mechanism being a true no-op at 1.0, not the earlier forced-sampling weight.]
DETECT_OUT="$(bash "$S/detect_reviewers.sh")"
assert_eq "detect reports kimi27 available with Moonshot key" \
  "$(jq -r '.kimi27' <<<"$DETECT_OUT")" "true"
BOOST_ERR="$T/boost.err"
CROSS_REVIEW_RUNLOG="$FIXLOG" bash "$S/select_roster.sh" --seed 42 >/dev/null 2>"$BOOST_ERR"
assert_contains "selector draws kimi27 as a candidate" "$(cat "$BOOST_ERR")" "kimi27"
# rookie base weight = max(50,15) * (1 + 0.5/sqrt(1)) / (1 + 0/240) = 75.0;
# draw_boost retired to 1.0 → 75.0, identical to an unboosted rookie (spark).
# The control seat must carry NO draw_boost; nemotron held this role until it
# took a 2.5 boost on 2026-08-14.
assert_contains "kimi27 weight reflects the retired (1.0) draw_boost" \
  "$(grep 'kimi27' "$BOOST_ERR")" "weight=75.0"
assert_contains "unboosted rookie weight unchanged" \
  "$(grep 'spark' "$BOOST_ERR")" "weight=75.0"
# no Moonshot key (env cleared, sandbox HOME has no key file) → honest skip
MOONSHOT_API_KEY= bash "$S/run_reviewers.sh" --base main --out "$T/o11" --reviewers kimi27 >/dev/null 2>"$T/k27skip.err"
assert_eq "kimi27 without a key exits 1 (all requested reviewers failed)" "$?" "1"
assert_contains "kimi27 skip names the missing key" "$(cat "$T/k27skip.err")" "Moonshot"
# same-provider convergence: kimi (baseline) + kimi27 agreeing is ONE provider vote
printf '{"exit_code": 0, "duration_s": 30, "timed_out": false, "output_bytes": 900, "attempt": 1, "timeout_budget_s": 600, "model": "kimi-k2.7-code", "cli": "moonshot", "failure_kind": null}\n' >"$RUN/raw/kimi27.meta.json"
cat >"$T/k27-findings.json" <<'EOF'
{"findings":[
 {"id":"m1","file":"a.sh","line":1,"claim":"x","sources":["kimi","kimi27"],"factcheck":{"verdict":"keep"}},
 {"id":"m2","file":"a.sh","line":2,"claim":"y","sources":["kimi27","codex"],"factcheck":{"verdict":"keep"}}
]}
EOF
K27LOG="$T/k27-runlog.jsonl"
CROSS_REVIEW_RUNLOG="$K27LOG" bash "$S/append_runlog.sh" \
  --run-dir "$RUN" --project test --base main --pr - --pass 1 \
  --verdict CLEAN --convergent 1 --top "-" --findings "$T/k27-findings.json" >/dev/null 2>&1
assert_eq "kimi27 telemetry lands in the runlog" \
  "$(tail -1 "$K27LOG" | jq -r '.reviewers.kimi27.status')" "ok"
assert_eq "kimi+kimi27 agreement is NOT cross-provider convergent" \
  "$(tail -1 "$K27LOG" | jq -r '.reviewers.kimi27.findings_convergent')" "1"
rm -f "$RUN/raw/kimi27.meta.json"
# request body: usage:{include:true} is an OpenRouter extension — the moonshot
# cli path must omit it (codex P2 falsified-as-worded but accepted as hygiene,
# PR #29 pass 1). The shim key makes curl fail fast; the body file is written
# BEFORE curl runs, so this asserts offline on the file, not the network.
bash "$S/run_reviewers.sh" --base main --out "$T/o12" --reviewers kimi27 --timeout 15 >/dev/null 2>&1 || true
if [[ -f "$T/o12/kimi27.request.json" ]]; then
  assert_eq "moonshot request body omits OpenRouter usage extension" \
    "$(jq 'has("usage")' "$T/o12/kimi27.request.json")" "false"
else
  bad "kimi27 request body was never written"
fi
# detect positional coupling: clearing ONLY the moonshot key must flip kimi27
# to false while the OR pool stays true (kimi+kat convergent nit — pins the
# printf arg mapping empirically, not just by comment)
DETECT2="$(MOONSHOT_API_KEY= bash "$S/detect_reviewers.sh")"
assert_eq "no moonshot key → kimi27 false" "$(jq -r '.kimi27' <<<"$DETECT2")" "false"
assert_eq "no moonshot key → OR pool unaffected" "$(jq -r '.glm' <<<"$DETECT2")" "true"

echo "── kimi3 rotation seat (direct-Moonshot K3, draw_boost) ──"
# [pin: 2026-07-18, per Gabriel — kimi-k3 (Moonshot's flagship, released
# 2026-07-16) joins the rotation pool as a second direct-Moonshot seat,
# same billing rail as kimi27 and the kimi baseline (NOT an OpenRouter
# fallback). Carries draw_boost 2.5 while it earns leaderboard data, same
# bring-up pattern as kimi27.]
DETECT_OUT3="$(bash "$S/detect_reviewers.sh")"
assert_eq "detect reports kimi3 available with Moonshot key" \
  "$(jq -r '.kimi3' <<<"$DETECT_OUT3")" "true"
assert_eq "detect still reports kimi27 available (positional coupling check)" \
  "$(jq -r '.kimi27' <<<"$DETECT_OUT3")" "true"
BOOST_ERR3="$T/boost3.err"
CROSS_REVIEW_RUNLOG="$FIXLOG" bash "$S/select_roster.sh" --seed 42 >/dev/null 2>"$BOOST_ERR3"
assert_contains "selector draws kimi3 as a candidate" "$(cat "$BOOST_ERR3")" "kimi3"
# rookie base weight = max(50,15) * (1 + 0.5/sqrt(1)) / (1 + 0/240) = 75.0;
# draw_boost 2.5 (fresh seat, not yet retired) → 75.0 * 2.5 = 187.5.
assert_contains "kimi3 weight reflects its draw_boost (2.5, not yet retired)" \
  "$(grep 'kimi3 ' "$BOOST_ERR3")" "weight=187.5"
# no Moonshot key (env cleared, sandbox HOME has no key file) → honest skip
MOONSHOT_API_KEY= bash "$S/run_reviewers.sh" --base main --out "$T/o13" --reviewers kimi3 >/dev/null 2>"$T/k3skip.err"
assert_eq "kimi3 without a key exits 1 (all requested reviewers failed)" "$?" "1"
assert_contains "kimi3 skip names the missing key" "$(cat "$T/k3skip.err")" "Moonshot"
# same-provider convergence: kimi (baseline) + kimi3 agreeing is ONE provider vote
printf '{"exit_code": 0, "duration_s": 30, "timed_out": false, "output_bytes": 900, "attempt": 1, "timeout_budget_s": 600, "model": "kimi-k3", "cli": "moonshot", "failure_kind": null}\n' >"$RUN/raw/kimi3.meta.json"
cat >"$T/k3-findings.json" <<'EOF'
{"findings":[
 {"id":"n1","file":"a.sh","line":1,"claim":"x","sources":["kimi","kimi3"],"factcheck":{"verdict":"keep"}},
 {"id":"n2","file":"a.sh","line":2,"claim":"y","sources":["kimi3","codex"],"factcheck":{"verdict":"keep"}}
]}
EOF
K3LOG="$T/k3-runlog.jsonl"
CROSS_REVIEW_RUNLOG="$K3LOG" bash "$S/append_runlog.sh" \
  --run-dir "$RUN" --project test --base main --pr - --pass 1 \
  --verdict CLEAN --convergent 1 --top "-" --findings "$T/k3-findings.json" >/dev/null 2>&1
assert_eq "kimi3 telemetry lands in the runlog" \
  "$(tail -1 "$K3LOG" | jq -r '.reviewers.kimi3.status')" "ok"
assert_eq "kimi+kimi3 agreement is NOT cross-provider convergent" \
  "$(tail -1 "$K3LOG" | jq -r '.reviewers.kimi3.findings_convergent')" "1"
rm -f "$RUN/raw/kimi3.meta.json"
# request body: usage:{include:true} is an OpenRouter extension — the moonshot
# cli path must omit it, same hygiene as kimi27.
bash "$S/run_reviewers.sh" --base main --out "$T/o14" --reviewers kimi3 --timeout 15 >/dev/null 2>&1 || true
if [[ -f "$T/o14/kimi3.request.json" ]]; then
  assert_eq "moonshot request body omits OpenRouter usage extension" \
    "$(jq 'has("usage")' "$T/o14/kimi3.request.json")" "false"
else
  bad "kimi3 request body was never written"
fi
# detect positional coupling: clearing ONLY the moonshot key must flip BOTH
# kimi27 and kimi3 to false while the OR pool stays true.
DETECT3="$(MOONSHOT_API_KEY= bash "$S/detect_reviewers.sh")"
assert_eq "no moonshot key → kimi3 false" "$(jq -r '.kimi3' <<<"$DETECT3")" "false"
assert_eq "no moonshot key → kimi27 false" "$(jq -r '.kimi27' <<<"$DETECT3")" "false"
assert_eq "no moonshot key → OR pool unaffected" "$(jq -r '.glm' <<<"$DETECT3")" "true"

echo "── doc-narrative caution note (text-only reviewers, PR #350 class) ──"
# [pin: PR #350 (2026-07-05) — devstral replayed 9 of 12 findings, and
# deepseek 4 of 5, from an in-diff investigation doc's PROSE description of
# PRE-FIX bugs, reporting them as live findings. codex+kimi (agentic, with
# file-reading tools) were not fooled — they could check whether the
# described bugs were actually still present. Text-only reviewers (kimi +
# the OpenRouter pool, including kimi27) get an explicit caution injected
# into the prompt whenever the diff touches a doc/markdown file. Detection is
# by FILE EXTENSION, not prose content — content-sniffing for "bug language"
# needs unbounded phrasing coverage and is the same fragile-heuristic trap
# output_no_verdict already warns against.]
git checkout -qb docbranch main
printf 'bug: X used to crash before the fix was applied\n' >investigation.md
git add investigation.md
git -c user.email=t@t -c user.name=t commit -qm "add investigation doc"

# kimi: prompt goes over stdin, not a file — capture it via a shim variant
# that tees stdin before answering, so the assertion reads real prompt text
# rather than trusting the wiring by inspection.
cat >"$T/bin/kimi" <<'SHIM'
#!/bin/sh
cat >"${KIMI_STDIN_CAPTURE:-/dev/null}"
printf "shim review: no findings\n"
SHIM
chmod +x "$T/bin/kimi"

KIMI_STDIN_CAPTURE="$T/kimi-stdin-doc.txt" bash "$S/run_reviewers.sh" --base main --out "$T/o16" --reviewers kimi --timeout-kimi 30 >/dev/null 2>&1
assert_contains "kimi prompt warns on doc-narrative risk (.md in diff)" \
  "$(cat "$T/kimi-stdin-doc.txt" 2>/dev/null)" "documentation/markdown"

# negative case: feat's diff (thousands of numbered lines in f.txt) has no
# doc/markdown file — the caution must NOT fire on an ordinary code diff.
git checkout -q feat
KIMI_STDIN_CAPTURE="$T/kimi-stdin-nodoc.txt" bash "$S/run_reviewers.sh" --base main --out "$T/o17" --reviewers kimi --timeout-kimi 30 >/dev/null 2>&1
case "$(cat "$T/kimi-stdin-nodoc.txt" 2>/dev/null)" in
  *"documentation/markdown"*) bad "kimi prompt warns even without doc files in the diff" ;;
  *) ok "no doc-narrative note when diff has no doc files" ;;
esac

# openrouter-pool path shares the same prompt-building function — one probe
# (glm) confirms the wiring reaches it too, not just kimi's separate runner.
git checkout -q docbranch
bash "$S/run_reviewers.sh" --base main --out "$T/o18" --reviewers glm --timeout 15 >/dev/null 2>&1 || true
assert_contains "openrouter-pool prompt (glm) warns on doc-narrative risk" \
  "$(jq -r '.messages[0].content' "$T/o18/glm.request.json" 2>/dev/null)" "documentation/markdown"

printf '#!/bin/sh\ncat >/dev/null 2>&1 || true\nprintf "shim review: no findings\\n"\n' >"$T/bin/kimi"
git branch -D docbranch >/dev/null 2>&1
git checkout -q feat

echo "── doc-narrative caution: brace-compressed rename + 50-file cap (codex P2/P3) ──"
# [pin: PR #30 pass 1, codex — both FALSIFIED against real git output before
# being accepted (parent direct-source verification): git diff --stat
# compresses a rename as "docs/{old.txt => new.md} | 1 +" (the ".md" is
# followed by "}", not whitespace/EOL — the original regex missed it), and
# `head -50` on --stat can truncate a doc file past the cutoff on a >50-file
# diff — exactly the false-negative this feature exists to prevent. Fixed by
# switching detection from the capped --stat display to an uncapped
# `git diff --name-only` file list (one clean path per line, no brace
# compression, no cap).]
cat >"$T/bin/kimi" <<'SHIM'
#!/bin/sh
cat >"${KIMI_STDIN_CAPTURE:-/dev/null}"
printf "shim review: no findings\n"
SHIM
chmod +x "$T/bin/kimi"
git checkout -qb renamebranch main
git mv f.txt renamed-doc.md 2>/dev/null || git mv f.txt docs.md
git -c user.email=t@t -c user.name=t commit -qam "rename to markdown"
KIMI_STDIN_CAPTURE="$T/kimi-stdin-rename.txt" bash "$S/run_reviewers.sh" --base main --out "$T/o19" --reviewers kimi --timeout-kimi 30 >/dev/null 2>&1
assert_contains "brace-compressed rename to .md still triggers the caution" \
  "$(cat "$T/kimi-stdin-rename.txt" 2>/dev/null)" "documentation/markdown"
git checkout -q feat
git branch -D renamebranch >/dev/null 2>&1

git checkout -qb capbranch main
for _i in $(seq 1 55); do echo "x" >"cap$_i.ts"; done
git add . && git -c user.email=t@t -c user.name=t commit -qm "55 code files"
git checkout -qb capbranch2 capbranch
for _i in $(seq 1 55); do echo "y" >"cap$_i.ts"; done
echo "doc content" >zzz-late-doc.md
git add . && git -c user.email=t@t -c user.name=t commit -qm "55 code files + 1 late doc file"
KIMI_STDIN_CAPTURE="$T/kimi-stdin-cap.txt" bash "$S/run_reviewers.sh" --base capbranch --out "$T/o20" --reviewers kimi --timeout-kimi 30 >/dev/null 2>&1
assert_contains "doc file past the 50-file --stat cap still triggers the caution" \
  "$(cat "$T/kimi-stdin-cap.txt" 2>/dev/null)" "documentation/markdown"
git checkout -q feat
git branch -D capbranch capbranch2 >/dev/null 2>&1

# [pin: PR #30 pass 2, codex — FALSIFIED-then-confirmed against real git
# output: `git diff --name-only` drops the SOURCE path on a rename, showing
# only the destination ("investigation.md => notes.txt" becomes just
# "notes.txt"). If the doc is renamed to a non-doc extension WITH edits, the
# extension check on the destination alone misses it entirely — even though
# the diff hunk still carries every line of the original doc's prose as
# context/removed lines. `--name-status` reports BOTH paths for a rename
# (tab-separated: "R083\told.md\tnew.txt"), so the same extension regex
# catches the source column too.]
git checkout -qb revrename-base main
printf 'bug: X used to crash before the fix was applied\nmore prose\n' >investigation2.md
git add investigation2.md
git -c user.email=t@t -c user.name=t commit -qm "add investigation doc (base)"
git checkout -qb revrename-feat revrename-base
git mv investigation2.md notes2.txt
printf 'bug: X used to crash before the fix was applied\nmore prose\nan added line\n' >notes2.txt
git -c user.email=t@t -c user.name=t commit -qam "rename doc to non-doc extension with an edit"
KIMI_STDIN_CAPTURE="$T/kimi-stdin-revrename.txt" bash "$S/run_reviewers.sh" --base revrename-base --out "$T/o21" --reviewers kimi --timeout-kimi 30 >/dev/null 2>&1
assert_contains "doc renamed away to a non-doc extension (with edit) still triggers the caution" \
  "$(cat "$T/kimi-stdin-revrename.txt" 2>/dev/null)" "documentation/markdown"
git checkout -q feat
git branch -D revrename-base revrename-feat >/dev/null 2>&1

printf '#!/bin/sh\ncat >/dev/null 2>&1 || true\nprintf "shim review: no findings\\n"\n' >"$T/bin/kimi"

echo "── standalone suites: json-output / score / report-block / digest ──"
# Each standalone suite exits 0 all-green, 1 on any failure; fold into this
# harness as one assertion per suite so CI stays a single entrypoint.
for suite in test_json_output test_score_findings test_report_block test_digest test_snapshot test_profiles test_leaderboard_events; do
  if [[ -f "$SKILL_DIR/tests/$suite.sh" ]]; then
    if bash "$SKILL_DIR/tests/$suite.sh" >"$T/$suite.log" 2>&1; then
      ok "$suite suite green ($(grep -oE '[0-9]+ passed' "$T/$suite.log" | tail -1))"
    else
      bad "$suite suite failed — FAILs: $(grep -E '^  FAIL' "$T/$suite.log" | head -3 | tr '\n' ' ') tail: $(tail -1 "$T/$suite.log")"
    fi
  else
    bad "$suite.sh missing from tests/"
  fi
done

echo "── model slugs have exactly one source of truth ──"
# [pin: 2026-08-03 — run_reviewers.sh used to carry a literal `<slug>_model=`
# per reviewer that reviewer_profiles.json then overrode. The literals were
# therefore never used, rotted silently, and misled anyone fixing a rename in
# the wrong file: poolside/laguna-m.1 and mistralai/devstral-2512 were both
# delisted upstream while still named in the script. There must be no second
# copy, and a reviewer with no profile model must fail loudly, not guess.]
assert_eq "run_reviewers.sh carries no model-slug literals" \
  "$(grep -cE '^[a-z0-9_]+_model="' "$SKILL_DIR/scripts/run_reviewers.sh" || true)" "0"
assert_contains "models resolve from reviewer_profiles.json" \
  "$(cat "$SKILL_DIR/scripts/run_reviewers.sh")" 'profile_get "$_r" model'

# A profile with no `.model` must skip the reviewer with a named failure_kind
# rather than POSTing an empty model and reading the 404 as unreliability.
jq 'del(.glm.model)' "$SKILL_DIR/references/reviewer_profiles.json" >"$T/profiles_nomodel.json"
cp "$SKILL_DIR/references/reviewer_profiles.json" "$T/profiles.bak"
cp "$T/profiles_nomodel.json" "$SKILL_DIR/references/reviewer_profiles.json"
OPENROUTER_API_KEY=test-key bash "$S/run_reviewers.sh" --base main --out "$T/o17" --reviewers glm --timeout 60 >/dev/null 2>"$T/o17.err" || true
cp "$T/profiles.bak" "$SKILL_DIR/references/reviewer_profiles.json"
assert_eq "a reviewer with no profile model stamps no_model_configured" \
  "$(jq -r '.failure_kind' "$T/o17/glm.meta.json" 2>/dev/null)" "no_model_configured"
assert_contains "the skip names the file to edit" \
  "$(cat "$T/o17.err")" "reviewer_profiles.json"

echo "── delisted OpenRouter slugs are caught before the round ──"
# [pin: 2026-08-03 — poolside/laguna-m.1 was delisted upstream and burned a
# round as a 1s 404 that looked like reviewer flakiness. The validator turns
# that into a preflight warning.]
val_home="$T/valhome"
mkdir -p "$val_home/.cross-review/cache"
printf 'z-ai/glm-5.2\npoolside/laguna-s-2.1\n' >"$val_home/.cross-review/cache/or_models.txt"
cat >"$T/val_profiles.json" <<'JSON'
{
  "glm":    { "cli": "openrouter", "model": "z-ai/glm-5.2" },
  "laguna": { "cli": "openrouter", "model": "poolside/laguna-s-2.1" },
  "ghost":  { "cli": "openrouter", "model": "vendor/deleted-model-9" },
  "codex":  { "cli": "codex", "model": "n/a" }
}
JSON
val_out="$(HOME="$val_home" OPENROUTER_API_KEY=test-key bash "$SKILL_DIR/scripts/validate_or_models.sh" --profiles "$T/val_profiles.json" 2>&1 >/dev/null)"
assert_contains "validator warns about a delisted slug" "$val_out" "vendor/deleted-model-9"
assert_eq "validator stays silent about live slugs" \
  "$(printf '%s' "$val_out" | grep -c 'glm-5.2' || true)" "0"
assert_eq "validator ignores non-OpenRouter lanes" \
  "$(printf '%s' "$val_out" | grep -c 'codex' || true)" "0"
assert_eq "--no-fetch with a cold cache is silent and exits 0" \
  "$(HOME="$T/coldhome" OPENROUTER_API_KEY=test-key bash "$SKILL_DIR/scripts/validate_or_models.sh" --profiles "$T/val_profiles.json" --no-fetch 2>&1; echo "rc=$?")" "rc=0"
assert_contains "the dispatch preflight never fetches (no HTTP in front of the reviewers)" \
  "$(cat "$SKILL_DIR/scripts/run_reviewers.sh")" 'validate_or_models.sh" --no-fetch'
val_json="$(HOME="$val_home" OPENROUTER_API_KEY=test-key bash "$SKILL_DIR/scripts/validate_or_models.sh" --profiles "$T/val_profiles.json" --json 2>/dev/null)"
assert_eq "validator reports the missing count in --json" \
  "$(printf '%s' "$val_json" | jq -r '.missing')" "1"
HOME="$val_home" OPENROUTER_API_KEY=test-key bash "$SKILL_DIR/scripts/validate_or_models.sh" --profiles "$T/val_profiles.json" --strict >/dev/null 2>&1
assert_eq "--strict exits 1 when a slug is missing" "$?" "1"
# Offline / no key must never block a round.
assert_eq "no key → validator exits 0 and says nothing" \
  "$(HOME="$T/emptyhome" OPENROUTER_API_KEY= bash "$SKILL_DIR/scripts/validate_or_models.sh" --profiles "$T/val_profiles.json" 2>&1; echo "rc=$?")" "rc=0"

echo "── attempt-stamped artifacts never merge as a second reviewer ──"
# [pin: 2026-08-03 — per-attempt forensics write <slug>.attempt<N>.stdout into
# the same raw/ dir. merge_raw_findings globbed *.stdout, so those counted as
# their own reviewer: for a JSON-emitting lane that would double-count findings
# and manufacture convergence between <slug> and <slug>.attempt1.]
mkdir -p "$T/rawdup"
printf '{"findings":[{"severity":"High","file":"a.ts","line":1,"snippet":"x","claim":"dup me"}]}\n' >"$T/rawdup/spark.stdout"
cp "$T/rawdup/spark.stdout" "$T/rawdup/spark.attempt1.stdout"
bash "$SKILL_DIR/scripts/merge_raw_findings.sh" --raw "$T/rawdup" --out "$T/rawdup/merged.json" >/dev/null 2>&1 || true
assert_eq "the same finding from an attempt copy is not merged twice" \
  "$(jq '.findings | length' "$T/rawdup/merged.json" 2>/dev/null)" "1"
assert_eq "sources name the reviewer once, not the attempt file too" \
  "$(jq -r '.findings[0].sources | length' "$T/rawdup/merged.json" 2>/dev/null)" "1"

echo "── agy shell gate is concurrency-safe (shared repo state) ──"
# [pin: codex P2, PR #41 pass 1 — install/remove used to be a plain
# backup-and-replace of the repo's shared .agents/hooks.json. Two runs against
# the same repo would interleave: A installs, B backs up A's temporary gate as
# if it were the user's file, A restores the real original (killing B's gate
# mid-review), B restores A's temporary gate PERMANENTLY — leaving a hook that
# rewrites every command to `echo` for every agy session in that repo. The fix
# is a lock + holder refcount; these tests pin the two outcomes that matter.]
cat >"$T/bin/agy" <<'SHIM'
#!/bin/sh
if [ "$1" = "models" ]; then printf "gemini-3.5-flash-high\ngemini-3.1-pro-high\n"; exit 0; fi
sleep 2
printf 'shim review: no findings\n'
exit 0
SHIM
chmod +x "$T/bin/agy"

# (a) with a pre-existing hooks.json, two overlapping runs must both finish and
#     leave the user's file byte-identical.
mkdir -p "$REPO/.agents"
printf '{"my-own-hook": {"PreToolUse": []}}\n' >"$REPO/.agents/hooks.json"
gate_orig_sum="$(shasum "$REPO/.agents/hooks.json" | awk '{print $1}')"
( bash "$S/run_reviewers.sh" --base main --out "$T/oc1" --reviewers antigravity --timeout 60 >/dev/null 2>&1 ) &
gate_p1=$!
( bash "$S/run_reviewers.sh" --base main --out "$T/oc2" --reviewers gemini-pro --timeout 60 >/dev/null 2>&1 ) &
gate_p2=$!
wait "$gate_p1" "$gate_p2" 2>/dev/null || true
assert_eq "overlapping runs leave the repo's own hooks.json untouched" \
  "$(shasum "$REPO/.agents/hooks.json" 2>/dev/null | awk '{print $1}')" "$gate_orig_sum"
assert_eq "no gate rule is left behind in the user's hooks.json" \
  "$(grep -c 'cross-review-shell-gate' "$REPO/.agents/hooks.json" 2>/dev/null || true)" "0"
assert_eq "no holder/lock residue after both runs" \
  "$(ls -A "$REPO/.agents" 2>/dev/null | grep -c 'cross-review-gate' || true)" "0"
rm -f "$REPO/.agents/hooks.json"; rmdir "$REPO/.agents" 2>/dev/null || true

# (b) with no pre-existing hooks.json, two overlapping runs must remove the
#     gate entirely — a stale gate silently neuters every agy session there.
( bash "$S/run_reviewers.sh" --base main --out "$T/oc3" --reviewers antigravity --timeout 60 >/dev/null 2>&1 ) &
gate_p3=$!
( bash "$S/run_reviewers.sh" --base main --out "$T/oc4" --reviewers gemini-pro --timeout 60 >/dev/null 2>&1 ) &
gate_p4=$!
wait "$gate_p3" "$gate_p4" 2>/dev/null || true
assert_eq "overlapping runs leave no stale gate behind" \
  "$([[ -f "$REPO/.agents/hooks.json" ]] && echo LEFTOVER || echo clean)" "clean"

# (c2) crash recovery: when every registered holder is dead, hooks.json on disk
#      is the dead run's GATE and .cross-review-gate.orig is the user's real
#      file. The new run must not mistake the gate for the original, or its own
#      cleanup restores the gate permanently.
#      [pin: codex P1, PR #41 pass 2]
mkdir -p "$REPO/.agents"
printf '{"my-own-hook": {"PreToolUse": []}}\n' >"$REPO/.agents/.cross-review-gate.orig"
crash_orig_sum="$(shasum "$REPO/.agents/.cross-review-gate.orig" | awk '{print $1}')"
printf '{"cross-review-shell-gate": {"PreToolUse": []}}\n' >"$REPO/.agents/hooks.json"
printf '999999\n' >"$REPO/.agents/.cross-review-gate.holders"   # PID that cannot be alive
bash "$S/run_reviewers.sh" --base main --out "$T/oc6" --reviewers antigravity --timeout 60 >/dev/null 2>&1 || true
assert_eq "crash recovery restores the user's ORIGINAL hooks.json, not the stale gate" \
  "$(shasum "$REPO/.agents/hooks.json" 2>/dev/null | awk '{print $1}')" "$crash_orig_sum"
rm -rf "$REPO/.agents"

# (c) a live holder must keep the gate installed — the last run out restores.
mkdir -p "$REPO/.agents"
sleep 120 & gate_live_pid=$!
printf '%s\n' "$gate_live_pid" >"$REPO/.agents/.cross-review-gate.holders"
printf '{"cross-review-shell-gate": {"PreToolUse": []}}\n' >"$REPO/.agents/hooks.json"
bash "$S/run_reviewers.sh" --base main --out "$T/oc5" --reviewers antigravity --timeout 60 >/dev/null 2>&1 || true
assert_eq "a run does not tear down a gate another live run is using" \
  "$([[ -f "$REPO/.agents/hooks.json" ]] && echo kept || echo REMOVED)" "kept"
kill "$gate_live_pid" 2>/dev/null || true
rm -rf "$REPO/.agents"

printf '#!/bin/sh\nif [ "$1" = "models" ]; then printf "Gemini 3.5 Flash (High)\\nGemini 3.1 Pro (High)\\n"; fi\nprintf "shim review: no findings\\n"\n' >"$T/bin/agy"
chmod +x "$T/bin/agy"

echo "── agy gate message survives an apostrophe (shell quoting) ──"
# [pin: kimi Medium, PR #41 pass 1 — the message used to be hand-wrapped in bare
# single quotes, so editing it to contain an apostrophe would emit a malformed
# command line. Mutate the message and prove the emitted command is still valid.]
sed "s/^msg='SHELL DISABLED:/msg='don'\\''t run this; SHELL DISABLED:/" \
  "$SKILL_DIR/scripts/agy_shell_gate.sh" >"$T/gate_apos.sh"
chmod +x "$T/gate_apos.sh"
apos_out="$(printf '%s' '{"toolCall":{}}' | bash "$T/gate_apos.sh" 2>/dev/null)"
apos_cmd="$(printf '%s' "$apos_out" | jq -r '.overwrite.CommandLine' 2>/dev/null)"
assert_eq "gate JSON still parses with an apostrophe in the message" \
  "$(printf '%s' "$apos_out" | jq -r '.decision' 2>/dev/null)" "allow"
if bash -n -c "$apos_cmd" 2>/dev/null; then
  ok "generated echo is valid shell with an apostrophe in the message"
else
  bad "an apostrophe in the gate message produces a malformed command line"
fi

echo "── agy model detection survives the models-listing rename ──"
# [pin: 2026-08-03 — agy 1.1.10 changed `agy models` from display names
# ("Gemini 3.1 Pro (High)") to slugs ("gemini-3.1-pro-high"). The detection
# grep matched only the old shape, so gemini-pro silently false-negatived out
# of every roster while the lap itself was perfectly healthy. Both shapes must
# match, in detect_reviewers.sh AND select_roster.sh.]
# Run the probe against a throwaway HOME so the fixtures never touch the real
# ~/.cross-review/cache — an interrupted run used to leave a fake model listing
# behind that later rounds would trust (kimi27 Low, PR #41 pass 1).
det_home="$T/dethome"
det_cache="$det_home/.cross-review/cache/agy_models.txt"
mkdir -p "$(dirname "$det_cache")"
for shape in "Gemini 3.1 Pro (High)" "gemini-3.1-pro-high"; do
  printf 'gemini-3.5-flash-high\n%s\n' "$shape" >"$det_cache"
  assert_eq "detect_reviewers sees gemini-pro in '$shape' listing" \
    "$(HOME="$det_home" PATH="$T/bin:$PATH" bash "$SKILL_DIR/scripts/detect_reviewers.sh" 2>/dev/null | jq -r '."gemini-pro"')" "true"
done
# A listing with no Pro entry at all must still report false — the match must
# not have been widened into "always true".
printf 'gemini-3.5-flash-high\ngemini-3.6-flash-low\n' >"$det_cache"
assert_eq "detect_reviewers reports gemini-pro false when no Pro model is listed" \
  "$(HOME="$det_home" PATH="$T/bin:$PATH" bash "$SKILL_DIR/scripts/detect_reviewers.sh" 2>/dev/null | jq -r '."gemini-pro"')" "false"
assert_contains "select_roster matches the slug shape too" \
  "$(cat "$SKILL_DIR/scripts/select_roster.sh")" 'gemini[ ._-]?3'

echo "── agy silent model fallback is surfaced, not swallowed ──"
# [pin: 2026-08-03 — `agy --model` NEVER errors on an unrecognised string; it
# quietly serves the default (Flash). A renamed model would turn the deep Pro
# lap into a second Flash lap and the round would silently lose its provider
# diversity. The resolved model must be read back from agy's own log.]
cat >"$T/bin/agy" <<'SHIM'
#!/bin/sh
if [ "$1" = "models" ]; then printf "gemini-3.5-flash-high\ngemini-3.1-pro-high\n"; exit 0; fi
while [ $# -gt 0 ]; do
  if [ "$1" = "--log-file" ]; then printf 'model_resolver.go:73] Resolving model Gemini 3.5 Flash (High)\n' >"$2"; fi
  shift
done
printf 'shim review: no findings\n'
exit 0
SHIM
chmod +x "$T/bin/agy"
bash "$S/run_reviewers.sh" --base main --out "$T/o15" --reviewers gemini-pro --timeout 60 >/dev/null 2>"$T/o15.err" || true
assert_eq "meta records the model agy actually resolved" \
  "$(jq -r '.model_resolved' "$T/o15/gemini-pro.meta.json")" "Gemini 3.5 Flash (High)"
assert_contains "a silent Flash fallback on the Pro lap warns loudly" \
  "$(cat "$T/o15.err")" "but agy resolved"
# Matching model => no warning, and the field still round-trips.
cat >"$T/bin/agy" <<'SHIM'
#!/bin/sh
if [ "$1" = "models" ]; then printf "gemini-3.5-flash-high\ngemini-3.1-pro-high\n"; exit 0; fi
while [ $# -gt 0 ]; do
  if [ "$1" = "--log-file" ]; then printf 'model_resolver.go:73] Resolving model Gemini 3.1 Pro (High)\n' >"$2"; fi
  shift
done
printf 'shim review: no findings\n'
exit 0
SHIM
chmod +x "$T/bin/agy"
bash "$S/run_reviewers.sh" --base main --out "$T/o16" --reviewers gemini-pro --timeout 60 >/dev/null 2>"$T/o16.err" || true
assert_eq "no fallback warning when agy resolves the requested model" \
  "$(grep -c 'but agy resolved' "$T/o16.err" || true)" "0"
assert_eq "matching resolution is still recorded in meta" \
  "$(jq -r '.model_resolved' "$T/o16/gemini-pro.meta.json")" "Gemini 3.1 Pro (High)"
printf '#!/bin/sh\nif [ "$1" = "models" ]; then printf "Gemini 3.5 Flash (High)\\nGemini 3.1 Pro (High)\\n"; fi\n' >"$T/bin/agy"
chmod +x "$T/bin/agy"

echo "── agy shell gate (headless permission deadlock) ──"
# [pin: 2026-07-31 — agy >=1.1.3 kills a headless run at 0 bytes the moment the
# model asks for a "command" permission. The gate must (a) emit valid JSON,
# (b) allow, (c) rewrite ANY command line to a bare echo, and (d) be wired into
# hooks.json as a run_command PreToolUse handler. Regressing any of these puts
# both Gemini laps back to failure_kind=headless_permission_denied.]
GATE="$SKILL_DIR/scripts/agy_shell_gate.sh"
if [[ -x "$GATE" ]]; then
  gate_out="$(printf '%s' '{"toolCall":{"name":"run_command","args":{"CommandLine":"rm -rf / && git push --force"}}}' | bash "$GATE" 2>/dev/null)"
  if printf '%s' "$gate_out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
    ok "gate emits valid JSON"
  else
    bad "gate emitted invalid JSON: $gate_out"
  fi
  assert_contains "gate decision is allow (a deny/ask would end the run at 0 bytes)" "$gate_out" '"decision":"allow"'
  gate_cmd="$(printf '%s' "$gate_out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["overwrite"]["CommandLine"])' 2>/dev/null)"
  case "$gate_cmd" in
    "echo "*) ok "gate rewrites the command line to a bare echo" ;;
    *)        bad "gate did not rewrite to echo — got: $gate_cmd" ;;
  esac
  case "$gate_cmd" in
    *"rm -rf"*|*"git push"*) bad "gate leaked the original command into the rewrite: $gate_cmd" ;;
    *)                       ok "gate drops the original command entirely" ;;
  esac
else
  bad "scripts/agy_shell_gate.sh missing or not executable"
fi
assert_contains "run_reviewers.sh installs the gate as a run_command PreToolUse hook" \
  "$(cat "$SKILL_DIR/scripts/run_reviewers.sh")" 'install_agy_shell_gate'
assert_contains "run_reviewers.sh removes the gate on exit" \
  "$(cat "$SKILL_DIR/scripts/run_reviewers.sh")" 'remove_agy_shell_gate'
assert_contains "agy laps mount the repo with --add-dir" \
  "$(cat "$SKILL_DIR/scripts/run_reviewers.sh")" '--add-dir'
# [pin: 2026-08-03 — `command(echo)` alone is NOT enough. agy asks for
# `unsandboxed(<target>)` whenever the model escalates a step outside the
# sandbox, and the gate's rewritten echo inherits that request kind. Missing
# rule = intermittent 0-byte laps that look like a flake.]
assert_contains "preflight warns about the unsandboxed(echo) rule too" \
  "$(cat "$SKILL_DIR/scripts/run_reviewers.sh")" 'unsandboxed(echo)'
assert_contains "SKILL.md documents both echo allow-rules" \
  "$(cat "$SKILL_DIR/SKILL.md")" 'unsandboxed(echo)'

# ── post_comment.sh: SHA binding + staleness banner ────────────────────────
# A review record is read long after it is posted. Without the reviewed SHA on
# the comment it reads as authoritative about whatever the PR contains NOW —
# which is how kindred-mama-ai#3207 lost a two-provider-confirmed fix (head
# moved 4× in one session) and how its review posted 19 minutes AFTER the PR
# had already merged.
echo
echo "── post_comment sha binding ──"

cat >"$T/bin/gh" <<'SH'
#!/bin/bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "pr view") printf '%s\n' "${CR_TEST_PR_JSON:-}" ; exit 0 ;;
  "pr comment")
      while [ $# -gt 0 ]; do
        if [ "$1" = "--body-file" ]; then cp "$2" "$CR_TEST_CAPTURE"; fi
        shift
      done
      exit 0 ;;
esac
exit 0
SH
chmod +x "$T/bin/gh"

PC_FIND="$T/pc-findings.md"
printf '# findings\n\nnothing to report\n' >"$PC_FIND"
export CR_TEST_CAPTURE="$T/pc-capture.md"

pc_run() {   # $1=pr json, rest=extra args
  local json="$1"; shift
  : >"$CR_TEST_CAPTURE"
  CR_TEST_PR_JSON="$json" bash "$SKILL_DIR/scripts/post_comment.sh" \
    --pr 3207 --mode summary --findings "$PC_FIND" "$@" >/dev/null 2>&1
}

# 1. Head moved during the review → loud staleness warning naming both SHAs.
pc_run '{"headRefOid":"bdfafd698d9056568b3038b8b74f29cabc377b88","state":"OPEN"}' \
  --head-sha b813773502f9ba4f3c9cdf78c494ee08b230adcb
assert_contains "stale head is flagged" "$(cat "$CR_TEST_CAPTURE")" "the head moved during this review"
# Banner-specific phrasing: a bare "b81377350" also appears in the provenance
# line, so asserting the SHA alone passes even with the banner suppressed.
assert_contains "stale banner pairs reviewed with current" "$(cat "$CR_TEST_CAPTURE")" "Reviewed \`b81377350\`, current head is"
assert_contains "stale banner names the current sha" "$(cat "$CR_TEST_CAPTURE")" "bdfafd698"

# 2. Already merged → the record says so instead of reading as actionable.
pc_run '{"headRefOid":"399df23d4d5945162d0c5ed623484d608337165d","state":"MERGED"}' \
  --head-sha 399df23d4d5945162d0c5ed623484d608337165d
assert_contains "merged-before-review is flagged" "$(cat "$CR_TEST_CAPTURE")" "already merged before the review finished"

# ── post_comment records the posting outcome ──
# Six real reviews (kindred-mama-ai #3214/#3252/#3264/#3269/#3276/#3280) left
# 68-676KB of reviewer output and nothing on GitHub. Nothing on disk said whether
# posting was attempted, so "reviewed but dropped" was indistinguishable from
# "never reviewed". Every terminal path now records which one it was.
# Fresh dir per case — a leftover posted.json from a prior case would let these
# pass without the code writing anything.
pcp_run() {  # $1=case, $2=mode; echoes the run dir
  local d="$T/pcp/$1"; mkdir -p "$d"
  printf '# findings\n\nnothing\n' >"$d/findings.md"
  CR_TEST_PR_JSON='{"headRefOid":"abc","state":"OPEN"}' \
    bash "$SKILL_DIR/scripts/post_comment.sh" --pr 3207 --mode "$2" \
      --findings "$d/findings.md" --head-sha deadbeefcafe1234567890 >/dev/null 2>&1
  printf '%s' "$d"
}

# gh shim that emits a comment URL and can be made to fail on demand.
cat >"$T/bin/gh" <<'SH'
#!/bin/bash
case "$1 $2" in
  "auth status") [ -n "${CR_TEST_GH_NOAUTH:-}" ] && exit 1; exit 0 ;;
  "pr view") printf '%s\n' "${CR_TEST_PR_JSON:-}" ; exit 0 ;;
  "pr comment")
      while [ $# -gt 0 ]; do
        if [ "$1" = "--body-file" ] && [ -n "${CR_TEST_CAPTURE:-}" ]; then cp "$2" "$CR_TEST_CAPTURE"; fi
        shift
      done
      if [ -n "${CR_TEST_COMMENT_FAIL:-}" ]; then echo "rate limited" >&2; exit 1; fi
      if [ -n "${CR_TEST_COMMENT_JUNK_URL:-}" ]; then echo "Warning: something odd"; exit 0; fi
      echo "https://github.com/o/r/pull/3207#issuecomment-999"
      exit 0 ;;
esac
exit 0
SH
chmod +x "$T/bin/gh"

D="$(pcp_run posted summary)"
if [[ -f "$D/posted.json" ]]; then ok "successful post writes posted.json"; else bad "no posted.json after a successful post"; fi
if jq -e . "$D/posted.json" >/dev/null 2>&1; then ok "posted.json is valid JSON"; else bad "posted.json is not parseable"; fi
assert_eq "successful post records posted=true" "$(jq -r '.posted' "$D/posted.json")" "true"
assert_eq "successful post records the comment url" \
  "$(jq -r '.comment_url' "$D/posted.json")" "https://github.com/o/r/pull/3207#issuecomment-999"
assert_eq "successful post records the reviewed sha" \
  "$(jq -r '.head_sha' "$D/posted.json")" "deadbeefcafe1234567890"

# Explicit export/unset rather than a `VAR=1 func` prefix: bash does not
# reliably scope assignments to a *function* call, so a leak would silently
# arm the wrong case.
export CR_TEST_COMMENT_FAIL=1
D="$(pcp_run ghfail summary)"
unset CR_TEST_COMMENT_FAIL
assert_eq "a failed gh comment records posted=false" "$(jq -r '.posted' "$D/posted.json")" "false"
assert_eq "and names the failure" "$(jq -r '.reason' "$D/posted.json")" "gh-comment-failed"

# A malformed URL must not be recorded, and must NOT downgrade posted to false:
# the comment went up, and calling it a failure makes reconcile.sh post it twice.
export CR_TEST_COMMENT_JUNK_URL=1
D="$(pcp_run junkurl summary)"
unset CR_TEST_COMMENT_JUNK_URL
assert_eq "a garbled comment url is still a successful post" "$(jq -r '.posted' "$D/posted.json")" "true"
assert_eq "and the garbled url is dropped rather than recorded" "$(jq -r '.comment_url' "$D/posted.json")" ""

export CR_TEST_GH_NOAUTH=1
D="$(pcp_run noauth summary)"
unset CR_TEST_GH_NOAUTH
assert_eq "no-auth fallback is distinguishable from file mode" \
  "$(jq -r '.reason' "$D/posted.json")" "gh-unavailable-or-no-pr"

D="$(pcp_run filemode file)"
assert_eq "deliberate file mode records its own reason" "$(jq -r '.reason' "$D/posted.json")" "file-mode"

D="$(pcp_run nonemode none)"
assert_eq "mode=none still leaves a record" "$(jq -r '.reason' "$D/posted.json")" "mode-none"

# The whole point of the reason field: reconciliation must be able to tell a
# review that MEANT to post from one that was asked to stay local.
if [[ "$(jq -r '.reason' "$T/pcp/noauth/posted.json")" != "$(jq -r '.reason' "$T/pcp/filemode/posted.json")" ]]; then
  ok "failed-to-post and asked-not-to-post are different reasons"
else bad "both file-mode paths report the same reason"; fi
unset CR_TEST_COMMENT_FAIL CR_TEST_GH_NOAUTH

# 2b. Closed-but-not-merged gets its own banner. Without this the CLOSED
#     branch could regress silently while the MERGED test stayed green.
pc_run '{"headRefOid":"399df23d4d5945162d0c5ed623484d608337165d","state":"CLOSED"}' \
  --head-sha 399df23d4d5945162d0c5ed623484d608337165d
assert_contains "closed-before-review is flagged" "$(cat "$CR_TEST_CAPTURE")" "closed before the review finished"

# 3. CONTROL — head matches and PR is open: provenance, and NO warning. Without
#    this the assertions above would pass on a script that always warns.
pc_run '{"headRefOid":"399df23d4d5945162d0c5ed623484d608337165d","state":"OPEN"}' \
  --head-sha 399df23d4d5945162d0c5ed623484d608337165d
assert_contains "matching head records provenance" "$(cat "$CR_TEST_CAPTURE")" "Reviewed \`399df23d4\`"
if grep -qi "WARNING" "$CR_TEST_CAPTURE"; then
  bad "control: no warning when head matches and PR is open"
else
  ok "control: no warning when head matches and PR is open"
fi

# 4. Fail-open: an unusable `gh pr view` response must not stop the post.
pc_run '' --head-sha 399df23d4d5945162d0c5ed623484d608337165d
assert_contains "posts anyway when PR metadata is unavailable" "$(cat "$CR_TEST_CAPTURE")" "nothing to report"

# 5. Backwards compatible: no --head-sha at all still posts.
pc_run '{"headRefOid":"abc","state":"OPEN"}'
assert_contains "still posts without --head-sha" "$(cat "$CR_TEST_CAPTURE")" "nothing to report"

# 6. The roster line is derived from raw/*.meta.json, and a retried agy lap
#    leaves BOTH <slug>.meta.json and <slug>.attempt<N>.meta.json behind.
#    merge_raw_findings.sh has excluded the attempt copies since PR #41; the
#    roster line did not, and credited PR #50's review to five names for four
#    reviewers. Same bug, second location.
mkdir -p "$(dirname "$PC_FIND")/raw"
: >"$(dirname "$PC_FIND")/raw/antigravity.meta.json"
: >"$(dirname "$PC_FIND")/raw/antigravity.attempt1.meta.json"
: >"$(dirname "$PC_FIND")/raw/codex.meta.json"
: >"$(dirname "$PC_FIND")/raw/gemini-pro.agy-failed.meta.json"
pc_run '{"headRefOid":"abc","state":"OPEN"}'
# Grab the whole line. A `[^.]*` capture stops at the dot INSIDE
# "antigravity.attempt1", so it can never contain the string the assertion
# below looks for — it passed with the exclusion removed.
PC_ROSTER="$(grep '_Automated review by' "$CR_TEST_CAPTURE" 2>/dev/null || true)"
if [[ "$PC_ROSTER" == *"attempt1"* ]]; then
  bad "a retried lap is not counted as an extra reviewer (got: $PC_ROSTER)"
else
  ok "a retried lap is not counted as an extra reviewer"
fi
# CONTROL: the real reviewers must still be listed — an exclusion that dropped
# everything would satisfy the assertion above.
assert_contains "the reviewers that ran are still named" "$PC_ROSTER" "antigravity"
assert_contains "and so are the others" "$PC_ROSTER" "codex"
rm -rf "$(dirname "$PC_FIND")/raw"

rm -f "$T/bin/gh"

echo
echo "── merge gate reads the sha stamp ──"

# The stamp post_comment.sh writes is only worth writing if something reads it
# before a merge. merge_preflight.sh is that reader; hooks/merge_gate.sh makes
# it binding on the agent. Both fail OPEN, so every assertion below is paired
# with a control that proves the check can still say no.
MG_FIX="$T/mg-fixture.json"
MG_ARGS="$T/mg-gh-args"
# The shim answers every query with the same fixture, so a verdict alone cannot
# tell you WHICH PR was looked up. Record the arguments too.
cat >"$T/bin/gh" <<SH
#!/bin/sh
printf ' %s' "\$@" >>"$MG_ARGS"
printf '\n' >>"$MG_ARGS"
cat "$MG_FIX" 2>/dev/null || true
SH
chmod +x "$T/bin/gh"

# mg_pf <fixture-json> [args...] → sets MG_OUT / MG_RC
mg_pf() {
  local fixture="$1"; shift
  printf '%s' "$fixture" >"$MG_FIX"
  MG_OUT="$(bash "$S/merge_preflight.sh" --json "$@" 2>/dev/null)"
  MG_RC=$?
}
mg_status() { printf '%s' "$MG_OUT" | jq -r '.status // ""' 2>/dev/null; }

HEAD40='399df23d4d5945162d0c5ed623484d608337165d'
REVIEWED_OLD='## Cross-review — pass 1\n\n_Automated review by codex + kimi. Reviewed `b81377350`. See below._'
REVIEWED_NEW='## Cross-review — pass 2\n\n_Automated review by codex. Reviewed `399df23d4`. See below._'

# 1. The whole point: a record bound to a different commit blocks the merge.
mg_pf "{\"headRefOid\":\"$HEAD40\",\"state\":\"OPEN\",\"comments\":[{\"body\":\"$REVIEWED_OLD\"}]}" --pr 3207
assert_eq "stale review exits 1" "$MG_RC" "1"
assert_eq "stale review reports status=stale" "$(mg_status)" "stale"

# 2. CONTROL — reviewed at the current head. Without this, every assertion
#    above would also pass on a script that blocks unconditionally.
mg_pf "{\"headRefOid\":\"$HEAD40\",\"state\":\"OPEN\",\"comments\":[{\"body\":\"$REVIEWED_NEW\"}]}" --pr 3207
assert_eq "control: matching head exits 0" "$MG_RC" "0"
assert_eq "control: matching head reports status=clear" "$(mg_status)" "clear"

# 3. Green when absent — a PR nobody cross-reviewed is not blocked. This gate
#    is a safety net over reviews already run, not a review mandate.
mg_pf "{\"headRefOid\":\"$HEAD40\",\"state\":\"OPEN\",\"comments\":[]}" --pr 3207
assert_eq "no review record exits 0" "$MG_RC" "0"
assert_eq "no review record reports status=unreviewed" "$(mg_status)" "unreviewed"

# 4. A record posted before --head-sha existed carries no stamp to compare.
mg_pf "{\"headRefOid\":\"$HEAD40\",\"state\":\"OPEN\",\"comments\":[{\"body\":\"## Cross-review — pass 1\\n\\n_Automated review by codex._\"}]}" --pr 3207
assert_eq "unstamped record reports status=unbound" "$(mg_status)" "unbound"
assert_eq "unstamped record exits 0" "$MG_RC" "0"

# 5. Newest record wins — this is what lets a re-review CLEAR a stale gate.
#    Ordered oldest-first, as `gh pr view --json comments` returns them.
mg_pf "{\"headRefOid\":\"$HEAD40\",\"state\":\"OPEN\",\"comments\":[{\"body\":\"$REVIEWED_OLD\"},{\"body\":\"$REVIEWED_NEW\"}]}" --pr 3207
assert_eq "a newer passing review clears an older stale one" "$(mg_status)" "clear"

# 6. Nothing to gate on a PR that is already merged or closed.
mg_pf "{\"headRefOid\":\"$HEAD40\",\"state\":\"MERGED\",\"comments\":[{\"body\":\"$REVIEWED_OLD\"}]}" --pr 3207
assert_eq "merged PR is not gated" "$(mg_status)" "closed"

# 7. Fail open: an unusable `gh pr view` response must never block a merge.
mg_pf '' --pr 3207
assert_eq "unreadable PR metadata exits 0" "$MG_RC" "0"
assert_eq "unreadable PR metadata reports status=indeterminate" "$(mg_status)" "indeterminate"

# 8. Usage error is distinct from both outcomes (rc 2, not 0 or 1).
MG_OUT="$(bash "$S/merge_preflight.sh" --json 2>/dev/null)"; MG_RC=$?
assert_eq "missing --pr exits 2" "$MG_RC" "2"

# ── the hook that makes it binding ────────────────────────────────────────────
MG_HOOK="$SKILL_DIR/hooks/merge_gate.sh"

# mg_hook <fixture-json> <command> → prints the permission decision, or PASS
mg_hook() {
  printf '%s' "$1" >"$MG_FIX"
  printf '{"tool_input":{"command":%s}}' "$(jq -Rn --arg c "$2" '$c')" \
    | bash "$MG_HOOK" 2>/dev/null \
    | jq -r '.hookSpecificOutput.permissionDecision // "PASS"' 2>/dev/null
}
MG_STALE="{\"headRefOid\":\"$HEAD40\",\"state\":\"OPEN\",\"comments\":[{\"body\":\"$REVIEWED_OLD\"}]}"
MG_CLEAR="{\"headRefOid\":\"$HEAD40\",\"state\":\"OPEN\",\"comments\":[{\"body\":\"$REVIEWED_NEW\"}]}"

assert_eq "hook denies a stale merge" \
  "$(mg_hook "$MG_STALE" 'gh pr merge 3207 --squash --auto')" "deny"
# A merge reviewed at head is no longer waved through unconditionally: it must
# also bind itself to that commit. See the TOCTOU block further down for why.
assert_eq "control: hook allows a merge reviewed at head AND bound to it" \
  "$(mg_hook "$MG_CLEAR" "gh pr merge 3207 --squash --match-head-commit $HEAD40")" "PASS"
assert_eq "hook ignores commands that are not a merge" \
  "$(mg_hook "$MG_STALE" 'ls -la')" "PASS"

# The literal string appears in any commit message or PR body that DISCUSSES
# the gate — including the ones in this very PR. Matching raw text would make
# the hook unable to describe itself.
assert_eq "hook is not tripped by a heredoc quoting the command" \
  "$(mg_hook "$MG_STALE" "$(printf 'git commit -F - <<EOF\nfix: explain why gh pr merge was blocked\nEOF')")" "PASS"
assert_eq "hook is not tripped by the command quoted in --body" \
  "$(mg_hook "$MG_STALE" 'gh pr create --body "run gh pr merge 3207 when green"')" "PASS"

# The PR number does not have to come first. Assert on what the hook actually
# looked up, not only on the verdict: with no number found it falls back to the
# current branch, which this fixture would answer identically — so a verdict
# alone would stay green on a hook that never parsed the number at all.
: >"$MG_ARGS"
assert_eq "hook finds the PR number after a flag" \
  "$(mg_hook "$MG_STALE" 'gh pr merge --squash 3207')" "deny"
assert_contains "hook looks up that number rather than the current branch" \
  "$(cat "$MG_ARGS" 2>/dev/null)" " pr view 3207 "

# ── PR #50 review: every defect below was reproduced before it was fixed ─────
# The theme is that a shell command has more shapes than a regex has branches,
# so each of these asserts on the PR the hook RESOLVED, not just its verdict.

# mg_lookup <fixture> <command> → what the hook passed to `gh pr view`
mg_lookup() {
  : >"$MG_ARGS"
  mg_hook "$1" "$2" >/dev/null
  sed -nE 's/.*pr view ([^ ]+) .*/\1/p' "$MG_ARGS" 2>/dev/null | head -1
}

# 1. [codex] The cheap bail-out matched the literal "gh pr merge", so one extra
#    space skipped the gate entirely — before the whitespace-flexible regex ran.
assert_eq "two spaces do not bypass the gate" \
  "$(mg_hook "$MG_STALE" 'gh  pr merge 3207')" "deny"

# 2. [antigravity] Per-line stripping left earlier lines in the token scan, so a
#    number anywhere above the merge was read as the PR. Both directions are
#    harmful: false block, and false CLEAR when the wrong PR happens to be fine.
assert_eq "a number on an earlier line is not mistaken for the PR" \
  "$(mg_lookup "$MG_STALE" "$(printf 'timeout 300 pnpm test\ngh pr merge 3207')")" "3207"

# 3. [codex] Only the last merge in a compound command was checked, but the
#    first one runs first.
assert_eq "the first merge in a compound command is checked" \
  "$(mg_lookup "$MG_STALE" 'gh pr merge 111 && gh pr merge 222')" "111"

# 4. [codex] `--disable-auto` CANCELS a queued merge — it is the corrective
#    action for a stale auto-merge, and the gate was refusing it.
assert_eq "cancelling an auto-merge is not gated" \
  "$(mg_hook "$MG_STALE" 'gh pr merge 3207 --disable-auto')" "PASS"

# 5. [codex+antigravity, two providers] Quotes are still data at word-split
#    time, so a quoted number was not recognised as a number at all.
assert_eq "a quoted PR number is still a PR number" \
  "$(mg_lookup "$MG_STALE" 'gh pr merge "3207"')" "3207"

# 6. [codex+antigravity, two providers] Same for the repo value, where the
#    consequence was worse: gh could not resolve '"o/r"', so the gate no-opped.
assert_contains "a quoted --repo value loses its quotes" \
  "$(: >"$MG_ARGS"; mg_hook "$MG_STALE" 'gh pr merge 3207 --repo "o/r"' >/dev/null; cat "$MG_ARGS")" \
  " --repo o/r"

# 7. [codex] `-R` is gh's documented short alias; ignoring it meant querying
#    the right number in the wrong repository.
assert_contains "the -R repo alias is honoured" \
  "$(: >"$MG_ARGS"; mg_hook "$MG_STALE" 'gh pr merge -R o/r 3207' >/dev/null; cat "$MG_ARGS")" \
  " --repo o/r"

# 8. [antigravity+codex] `gh pr merge <branch>` is valid; the hook used to drop
#    the branch and check whatever the shell happened to be on.
assert_eq "a branch-name target is used as the PR reference" \
  "$(mg_lookup "$MG_STALE" 'gh pr merge my-branch')" "my-branch"

# 9. Flag-value awareness: the word after --match-head-commit is that flag's
#    value, not the PR. A positional scan without a flag table gets this wrong.
assert_eq "a flag's value is not mistaken for the PR reference" \
  "$(mg_lookup "$MG_STALE" 'gh pr merge --match-head-commit 999 3207')" "3207"

# 10. [codex] The refusal told the agent to get authorization, but no command
#     could express it — so the instruction could only be followed by evading
#     the matcher. The override is auditable, not secure: it is there so a user
#     who says "it's just a rebase" can be obeyed in the open.
assert_eq "an explicit override is honoured" \
  "$(mg_hook "$MG_STALE" 'CROSS_REVIEW_MERGE_OVERRIDE=1 gh pr merge 3207')" "PASS"

# 11. CONTROL for 1-10: the plain form must still deny. Every assertion above
#     is about resolving the right PR; without this one they would all pass on
#     a hook that resolved perfectly and then never blocked anything.
assert_eq "control: the plain merge form still denies" \
  "$(mg_hook "$MG_STALE" 'gh pr merge 3207')" "deny"

# 12. CONTROL: both reviewers claimed a quoted mention would false-deny. It
#     does not — the anchor requires a shell-ish character before `gh`. Pinned
#     so the parser rework above cannot quietly introduce the bug they imagined.
assert_eq "control: a quoted mention inside another command still passes" \
  "$(mg_hook "$MG_STALE" "python3 -c \"print('gh pr merge 3207')\"")" "PASS"

# ── PR #50 pass 2: bypasses the pass-1 fixes introduced or left behind ──────

# [glm] `merge` had to be followed by whitespace or end-of-string, but the
# newline mapping turned a bare `gh pr merge` into `gh pr merge;` — so the
# plainest and most common form of the command matched nothing at all. Pass 1's
# own control used `--squash`, which has a space after `merge`, and missed it.
assert_eq "a bare merge before a newline is still gated" \
  "$(mg_hook "$MG_STALE" "$(printf 'gh pr merge\n')")" "deny"
assert_eq "a bare merge before a semicolon is still gated" \
  "$(mg_hook "$MG_STALE" 'gh pr merge; echo done')" "deny"

# [codex] Anchoring the match to a shell separator was a REGRESSION introduced
# in pass 1: the original alternative included whitespace, so an environment
# prefix or shell keyword used to be caught and then was not.
assert_eq "an environment prefix does not bypass the gate" \
  "$(mg_lookup "$MG_STALE" 'GH_REPO=o/r gh pr merge 3207')" "3207"
assert_eq "a shell keyword prefix does not bypass the gate" \
  "$(mg_lookup "$MG_STALE" 'if gh pr merge 3207; then echo hi; fi')" "3207"

# [codex] -A is gh's documented alias for --author-email and consumes the next
# token; without it the email resolved as the PR reference.
assert_eq "the -A alias consumes its value" \
  "$(mg_lookup "$MG_STALE" 'gh pr merge -A user@example.com 3207')" "3207"

# [glm + codex, two providers] The override was a substring match anywhere, so
# three things that authorize nothing disarmed the gate: a mention in an
# unrelated command, a shell comment the shell never evaluates, and =10.
assert_eq "a mention in an earlier command is not an override" \
  "$(mg_hook "$MG_STALE" 'echo CROSS_REVIEW_MERGE_OVERRIDE=1; gh pr merge 3207')" "deny"
assert_eq "a trailing comment is not an override" \
  "$(mg_hook "$MG_STALE" 'gh pr merge 3207 # CROSS_REVIEW_MERGE_OVERRIDE=1 needed')" "deny"
assert_eq "a longer value is not an override" \
  "$(mg_hook "$MG_STALE" 'CROSS_REVIEW_MERGE_OVERRIDE=10 gh pr merge 3207')" "deny"

# CONTROL for the three above: the real form must still work, or they would all
# pass on a hook whose override never fires.
assert_eq "control: the real override prefix still passes" \
  "$(mg_hook "$MG_STALE" 'CROSS_REVIEW_MERGE_OVERRIDE=1 gh pr merge 3207')" "PASS"

# CONTROL: accepting whitespace before `gh` widens the matcher; ordinary git
# commands containing the word must stay untouched.
assert_eq "control: git merge is not a gh pr merge" \
  "$(mg_hook "$MG_STALE" 'git merge origin/master')" "PASS"

# ── PR #50 pass 3: the two findings that were documented instead of fixed ───
# Both were codex P1s from pass 1. Writing a limitation into a comment is not
# the same as handling it, and a KNOWN LIMITS block is where a finding goes to
# be forgotten.

MG_CLEAR_FULL="{\"headRefOid\":\"$HEAD40\",\"state\":\"OPEN\",\"number\":50,\"url\":\"https://github.com/o/r/pull/50\",\"comments\":[{\"body\":\"$REVIEWED_NEW\"}]}"
MG_NONE="{\"headRefOid\":\"$HEAD40\",\"state\":\"OPEN\",\"number\":50,\"url\":\"https://github.com/o/r/pull/50\",\"comments\":[]}"

# TOCTOU. A `clear` verdict is a statement about the head at read time. A push
# landing before GitHub handles the merge would be merged unreviewed, so the
# merge must assert the SHA itself — GitHub then refuses if it moved.
assert_eq "a clear verdict still refuses an unbound merge" \
  "$(mg_hook "$MG_CLEAR_FULL" 'gh pr merge 50 --squash')" "deny"
# mg_reason <fixture> <command> → the text handed back to the agent
mg_reason() {
  printf '%s' "$1" >"$MG_FIX"
  printf '{"tool_input":{"command":%s}}' "$(jq -Rn --arg c "$2" '$c')" \
    | bash "$MG_HOOK" 2>/dev/null \
    | jq -r '.hookSpecificOutput.permissionDecisionReason // ""' 2>/dev/null
}
# A refusal the agent cannot act on is the mistake this gate already made once
# (the override that no command could express). Assert the fix is spelled out.
assert_contains "and the refusal hands over the exact SHA to bind" \
  "$(mg_reason "$MG_CLEAR_FULL" 'gh pr merge 50 --squash')" \
  "--match-head-commit $HEAD40"

# CONTROL ×2: both spellings of the flag must satisfy it, or the assertion
# above would be indistinguishable from a hook that denies every merge.
assert_eq "control: a bound merge passes" \
  "$(mg_hook "$MG_CLEAR_FULL" "gh pr merge 50 --squash --match-head-commit $HEAD40")" "PASS"
assert_eq "control: the =SHA spelling also passes" \
  "$(mg_hook "$MG_CLEAR_FULL" "gh pr merge 50 --match-head-commit=$HEAD40")" "PASS"

# CONTROL: binding is required only where there is something to bind TO.
# Demanding it on an unreviewed PR would quietly convert green-when-absent
# into a review mandate — the one thing this gate promises not to become.
assert_eq "control: an unreviewed PR is not forced to bind" \
  "$(mg_hook "$MG_NONE" 'gh pr merge 50 --squash')" "PASS"

# The REST endpoint merges a PR without ever saying `gh pr merge`. It was the
# first line of the KNOWN LIMITS block, which also makes it the first thing an
# agent blocked by this gate would reach for.
assert_eq "the REST merge endpoint is gated too" \
  "$(mg_hook "$MG_STALE" 'gh api -X PUT repos/o/r/pulls/50/merge')" "deny"

# CONTROL: reading a PR through the same CLI must stay untouched.
assert_eq "control: a non-merge gh api call passes" \
  "$(mg_hook "$MG_STALE" 'gh api repos/o/r/pulls/50')" "PASS"

# ── preflight: the Critical ────────────────────────────────────────────────
STAMPED='## Cross-review — pass 1\n\n_Reviewed `b81377350`._'
UNSTAMPED='## Cross-review — pass 2\n\n_no stamp on this one._'

# [antigravity] An unstamped record is not evidence of coverage, but `last`
# selected it anyway and reported unbound — switching the gate off while a
# stale stamped record sat right behind it. post_comment.sh produces exactly
# this comment whenever --head-sha is omitted, which #49 explicitly supports.
mg_pf "{\"headRefOid\":\"$HEAD40\",\"state\":\"OPEN\",\"comments\":[{\"body\":\"$STAMPED\"},{\"body\":\"$UNSTAMPED\"}]}" --pr 3207
assert_eq "an unstamped later record cannot mask a stale one" "$(mg_status)" "stale"
assert_eq "and it still exits 1" "$MG_RC" "1"

# CONTROL: with no stamped record anywhere, unbound is still the right answer.
mg_pf "{\"headRefOid\":\"$HEAD40\",\"state\":\"OPEN\",\"comments\":[{\"body\":\"$UNSTAMPED\"}]}" --pr 3207
assert_eq "control: records with no stamp at all report unbound" "$(mg_status)" "unbound"

# [codex, and independently confirmed with GH_DEBUG=api on gh 2.96.0]
# `gh pr view --json comments` issues comments(first: 100) — the OLDEST
# hundred. At the cap the newest review may be missing entirely, so refetch
# through the paginating REST endpoint.
BIG="$(jq -nc --arg b "$STAMPED" '[range(100) | {body: $b}]')"
: >"$MG_ARGS"
mg_pf "{\"headRefOid\":\"$HEAD40\",\"state\":\"OPEN\",\"number\":7,\"url\":\"https://github.com/o/r/pull/7\",\"comments\":$BIG}" --pr 7
assert_contains "a capped comment list is refetched with pagination" \
  "$(cat "$MG_ARGS" 2>/dev/null)" "api --paginate"

# ...but "the call was attempted" is not "the call worked", and that gap hid a
# real bug for a whole release: `gh api --paginate --slurp --jq` is REJECTED by
# gh ("the `--slurp` option is not supported with `--jq` or `--template`"), the
# error went to /dev/null, and the branch silently fell back to the capped
# list. The refetch never once paginated. The assertion above stayed green
# throughout, because the shim answered every call identically.
#
# So: a shim that reproduces gh's actual constraint and answers the two calls
# DIFFERENTLY, and an assertion on the verdict rather than on the argv.
cat >"$T/mg-pages.json" <<JSON
[[{"body":"$STAMPED"},{"body":"$REVIEWED_NEW"}]]
JSON
cat >"$T/bin/gh" <<SH
#!/bin/sh
printf ' %s' "\$@" >>"$MG_ARGS"
printf '\n' >>"$MG_ARGS"
slurp=0; usedjq=0; isapi=0
for a in "\$@"; do
  [ "\$a" = "--slurp" ] && slurp=1
  [ "\$a" = "--jq" ] && usedjq=1
  [ "\$a" = "api" ] && isapi=1
done
if [ "\$slurp" = 1 ] && [ "\$usedjq" = 1 ]; then
  echo 'the \`--slurp\` option is not supported with \`--jq\` or \`--template\`' >&2
  exit 1
fi
if [ "\$isapi" = 1 ]; then cat "$T/mg-pages.json"; else cat "$MG_FIX"; fi
SH
chmod +x "$T/bin/gh"

# The capped view shows 100 STALE records; only the paginated refetch reveals
# the newer passing one. A verdict of `clear` is therefore proof the refetch
# both ran AND was read.
mg_pf "{\"headRefOid\":\"$HEAD40\",\"state\":\"OPEN\",\"number\":7,\"url\":\"https://github.com/o/r/pull/7\",\"comments\":$BIG}" --pr 7
assert_eq "the refetched comments are the ones actually judged" "$(mg_status)" "clear"

# CONTROL: the refetch must not paper over a genuinely stale head. Same shim,
# but the paginated pages carry only the stale record — the verdict must flip
# back, or the assertion above would pass on a refetch that always says clear.
cat >"$T/mg-pages.json" <<JSON
[[{"body":"$STAMPED"}]]
JSON
mg_pf "{\"headRefOid\":\"$HEAD40\",\"state\":\"OPEN\",\"number\":7,\"url\":\"https://github.com/o/r/pull/7\",\"comments\":$BIG}" --pr 7
assert_eq "control: a refetch that finds only stale records still fails" "$(mg_status)" "stale"

# Restore the plain shim for the control below.
cat >"$T/bin/gh" <<SH
#!/bin/sh
printf ' %s' "\$@" >>"$MG_ARGS"
printf '\n' >>"$MG_ARGS"
cat "$MG_FIX" 2>/dev/null || true
SH
chmod +x "$T/bin/gh"

# CONTROL: below the cap, no second API call — the refetch must not be
# unconditional, or every run pays for it. The fixture carries `number` and
# `url` deliberately: without them the refetch cannot run for lack of a repo to
# query, and this control would pass on an unconditional refetch too.
: >"$MG_ARGS"
mg_pf "{\"headRefOid\":\"$HEAD40\",\"state\":\"OPEN\",\"number\":7,\"url\":\"https://github.com/o/r/pull/7\",\"comments\":[{\"body\":\"$STAMPED\"}]}" --pr 7
if grep -q 'api --paginate' "$MG_ARGS" 2>/dev/null; then
  bad "control: no pagination refetch under the 100-comment cap"
else
  ok "control: no pagination refetch under the 100-comment cap"
fi

rm -f "$T/bin/gh"

echo
echo "── reconcile.sh: which runs never reached GitHub ──"
# The six kindred-mama-ai drops (#3214/#3252/#3264/#3269/#3276/#3280) all have
# reviewer output and no provenance, so they must classify as unattributable,
# NOT droppable — re-posting them would mean stamping a guessed SHA.
RR="$T/reconcile-runs"; mkdir -p "$RR"
mkrun() {  # $1=name  $2=has_ctx  $3=head_sha  $4=has_output  $5=posted.json body
  local d="$RR/$1"; mkdir -p "$d/raw"
  [[ "$2" == "ctx" ]] && printf '{"head_sha":"%s","id":"pr-777","repo":"o/r"}\n' "$3" >"$d/context.json"
  [[ "$4" == "out" ]] && printf 'reviewer said things\n' >"$d/raw/codex.stdout"
  printf '# findings\n' >"$d/findings.md"
  [[ -n "${5:-}" ]] && printf '%s\n' "$5" >"$d/posted.json"
  printf '%s' "$d"
}
# Subshell: reconcile.sh sets -u, which must not leak into the suite.
cls() { ( source "$SKILL_DIR/scripts/reconcile.sh"
          [[ -n "${2:-}" ]] && repo_filter="$2"
          classify_run "$1" ) | tr '\037' '|'; }

D="$(mkrun full ctx aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa out)"
assert_eq "review with provenance and no post is droppable" "$(cls "$D" | cut -d'|' -f1)" "droppable"
assert_eq "and carries the PR it belongs to" "$(cls "$D" | cut -d'|' -f2)" "777"

D="$(mkrun wasposted ctx bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb out '{"posted":true,"reason":"posted","comment_url":"https://x/1"}')"
assert_eq "an already-posted review is not droppable" "$(cls "$D" | cut -d'|' -f1)" "posted"

D="$(mkrun deliberate ctx cccccccccccccccccccccccccccccccccccccccc out '{"posted":false,"reason":"file-mode"}')"
assert_eq "a deliberate file-mode run is not a drop" "$(cls "$D" | cut -d'|' -f1)" "deliberate"

D="$(mkrun ghfailed ctx dddddddddddddddddddddddddddddddddddddddd out '{"posted":false,"reason":"gh-comment-failed"}')"
assert_eq "a failed post IS droppable" "$(cls "$D" | cut -d'|' -f1)" "droppable"

# The shape of the six real drops: reviewer output, no context.json.
D="$(mkrun noprovenance noctx "" out)"
assert_eq "reviewer output with no recorded SHA is unattributable" "$(cls "$D" | cut -d'|' -f1)" "unattributable"
assert_contains "and says why it cannot be posted" "$(cls "$D")" "no reviewed SHA recorded"

# The fixture above is under-determined: it has no PR number EITHER, so it stays
# unattributable via the PR check even with the head_sha guard deleted — a
# mutant that removed that guard survived. The six real drops
# (kindred-mama-ai-pr-3280-…) take their PR from the DIRECTORY NAME, so they
# have a PR and no SHA. That is the combination the guard actually exists for:
# without it they become droppable and --post stamps them with nothing.
D="$(mkrun realdrop-pr-3280 noctx "" out)"
assert_eq "a PR number without a recorded SHA is still unattributable" "$(cls "$D" | cut -d'|' -f1)" "unattributable"
assert_eq "and the PR is known even though the SHA is not" "$(cls "$D" | cut -d'|' -f2)" "3280"

# posted.json describes the ACTUAL attempt; context.json describes the run's
# start. After an auto-fix pass they disagree, and reconciling from the stale
# context SHA would stamp the recovered comment with the wrong commit — the
# merge gate would then call a current review stale. (codex P1.)
D="$RR/passdrift"; mkdir -p "$D/raw"; printf 'x\n' >"$D/raw/codex.stdout"; printf '# f\n' >"$D/findings.md"
printf '{"head_sha":"1111111111111111111111111111111111111111","id":"pr-777","repo":"o/r"}\n' >"$D/context.json"
printf '{"posted":false,"reason":"gh-comment-failed","pr":"999","repo":"other/proj","pass":"2","head_sha":"2222222222222222222222222222222222222222"}\n' >"$D/posted.json"
assert_eq "the attempt's SHA wins over the run's start SHA" \
  "$(cls "$D" | cut -d'|' -f3)" "2222222222222222222222222222222222222222"
assert_eq "the attempt's PR wins over the id-derived one" "$(cls "$D" | cut -d'|' -f2)" "999"
assert_eq "the attempt's repo is carried" "$(cls "$D" | cut -d'|' -f4)" "other/proj"
assert_eq "the attempt's pass number is carried" "$(cls "$D" | cut -d'|' -f5)" "2"

# An id that merely CONTAINS a PR-looking substring must not redirect a
# recovered comment to that PR. (codex P1.)
# Realistic directory name — worktree.sh builds <repo>-<slug>-<ts>-<pid>, so a
# fixture called "looseid" cannot exercise the basename fallback at all. The
# pass-2 version of this test used exactly that and passed while the hole was
# wide open. (antigravity H, pass 3.)
D="$RR/myrepo-feature-x-pr-456-20260811T000000-12345"; mkdir -p "$D/raw"; printf 'x\n' >"$D/raw/codex.stdout"; printf '# f\n' >"$D/findings.md"
printf '{"head_sha":"3333333333333333333333333333333333333333","id":"feature-x-pr-456","repo":"o/r"}\n' >"$D/context.json"
assert_eq "an unanchored pr-NNN inside an id does not become the target PR" \
  "$(cls "$D" | cut -d'|' -f2)" ""
assert_eq "and with no PR it is unattributable, not droppable" "$(cls "$D" | cut -d'|' -f1)" "unattributable"

# A run recorded before the repo field existed has a SHA, a PR and a body, but
# no way to say WHICH repository. --post would then call `gh pr comment 266`
# with no --repo and hit PR #266 in whatever repo the caller stands in. Three
# real runs on this machine are in exactly that state. (Follow-up to #53.)
D="$RR/norepo"; mkdir -p "$D/raw"; printf 'x\n' >"$D/raw/codex.stdout"; printf '# f\n' >"$D/findings.md"
printf '{"head_sha":"4444444444444444444444444444444444444444","id":"pr-266"}\n' >"$D/context.json"
assert_eq "a run with no recorded repository is not droppable" "$(cls "$D" | cut -d'|' -f1)" "unattributable"
assert_contains "and says the repository is what is missing" "$(cls "$D")" "no repository recorded"

# A corrupt SHA is not provenance — worktree.sh validates on write, this is read.
D="$RR/badsha"; mkdir -p "$D/raw"; printf 'x\n' >"$D/raw/codex.stdout"; printf '# f\n' >"$D/findings.md"
printf '{"head_sha":"not-a-sha","id":"pr-777","repo":"o/r"}\n' >"$D/context.json"
assert_eq "a malformed SHA is discarded rather than stamped" "$(cls "$D" | cut -d'|' -f1)" "unattributable"

D="$(mkrun aborted ctx eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee noout)"
assert_eq "a run with no reviewer output is not a drop" "$(cls "$D" | cut -d'|' -f1)" "unreviewed"

# --repo filters on context.json's repo, not the directory name.
assert_eq "non-matching repo is filtered out" \
  "$(cls "$RR/full" "other/repo" | cut -d'|' -f1)" "filtered"

# Exit code is the machine-readable half: 1 means there is something to fix.
bash "$SKILL_DIR/scripts/reconcile.sh" --runs-root "$RR" >/dev/null 2>&1
assert_eq "exit 1 when droppable runs exist" "$?" "1"
if bash "$SKILL_DIR/scripts/reconcile.sh" --runs-root "$RR/full" >/dev/null 2>&1; then
  ok "exit 0 when nothing is droppable"
else bad "non-zero exit with no droppable runs"; fi
# Capture first, then parse. This suite runs under `set -o pipefail`, and
# reconcile.sh deliberately exits 1 when it finds droppable runs — so
# `reconcile --json | jq` reports the LEFT side's status and the assertion fails
# on perfectly valid JSON. Any command whose non-zero exit is a signal rather
# than an error cannot be the left half of a pipe here.
RECON_JSON="$(bash "$SKILL_DIR/scripts/reconcile.sh" --runs-root "$RR" --json 2>/dev/null)"
if printf '%s' "$RECON_JSON" | jq -e 'type=="array"' >/dev/null 2>&1; then
  ok "--json emits a parseable array"
else bad "--json output is not a JSON array"; fi
assert_eq "--json reports every scanned run" \
  "$(printf '%s' "$RECON_JSON" | jq 'length' 2>/dev/null)" "11"
assert_eq "--json agrees with the text report on what is droppable" \
  "$(printf '%s' "$RECON_JSON" | jq '[.[] | select(.state=="droppable")] | length' 2>/dev/null)" "3"
# Report-only by default: scanning must never post. If the default ever flips,
# this shim gets called and the marker file appears.
: >"$T/reconcile-posted-marker"
cat >"$T/bin/gh" <<'SH'
#!/bin/bash
[ "$1 $2" = "pr comment" ] && echo "$*" >>"$CR_RECON_MARKER"
[ "$1 $2" = "auth status" ] && exit 0
exit 0
SH
chmod +x "$T/bin/gh"
export CR_RECON_MARKER="$T/reconcile-posted-marker"
bash "$SKILL_DIR/scripts/reconcile.sh" --runs-root "$RR" >/dev/null 2>&1
assert_eq "a default scan posts nothing" "$(wc -c <"$CR_RECON_MARKER" | tr -d ' ')" "0"
# Passing control: without this, "marker is empty" would also hold if reconcile
# were broken and posted nothing under any flag.
bash "$SKILL_DIR/scripts/reconcile.sh" --runs-root "$RR" --post >/dev/null 2>&1
if [[ -s "$CR_RECON_MARKER" ]]; then ok "control: --post does reach gh pr comment"; else bad "--post posted nothing — the default-scan test proves nothing"; fi
# Without --repo, `gh pr view 999` resolves against whatever repo the caller is
# standing in — and this scan spans every repo under the runs root. (codex P1.)
if grep -q -- '--repo other/proj' "$CR_RECON_MARKER"; then
  ok "--post targets the repo recorded by the attempt"
else bad "--post invoked gh with no --repo — it can hit a same-numbered PR elsewhere"; fi
unset CR_RECON_MARKER

echo "── dual-copy identity (repo context only) ──"

# [pin: mimo pass-4 — the two in-repo copies must never drift again]
REPO_ROOT="$(cd "$SKILL_DIR/.." 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || true)"
COPY_A="$REPO_ROOT/cross-review"
COPY_B="$REPO_ROOT/plugins/cross-review/skills/cross-review"
if [[ -n "$REPO_ROOT" && -d "$COPY_A" && -d "$COPY_B" ]]; then
  # runlog.jsonl / finding_events.jsonl are runtime state, not source: the
  # installed skill is a symlink to COPY_A, so its history lands there and
  # would otherwise read as drift on every run (2026-08-03).
  if diff -r --exclude 'runlog.jsonl*' --exclude 'finding_events.jsonl' --exclude 'iteration-1' --exclude '*.bak*' --exclude '.DS_Store' "$COPY_A" "$COPY_B" >/dev/null 2>&1; then
    ok "root copy ≡ plugin copy"
  else
    bad "root copy and plugin copy have drifted — sync before merging"
  fi
else
  echo "  skip dual-copy identity (not in the skills repo)"
fi

echo
echo "══ $PASS passed, $FAIL failed ══"
[[ "$FAIL" -eq 0 ]]
