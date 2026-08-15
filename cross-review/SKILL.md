---
name: cross-review
description: Run external AI code reviewers in parallel against the current branch's diff, synthesize deduped findings, auto-apply fixes, and iterate until clean. codex and kimi are fixed baselines; the rest of each round's roster (Gemini via agy, GLM/DeepSeek/MiMo/MiniMax/Qwen/Devstral/Laguna/KAT/North/Nemotron/Spark/Seed/Grok via OpenRouter, plus Kimi k2.7-code and Kimi K3 direct on Moonshot) rotates via a leaderboard-weighted random draw — every round has ≥3 reviewers. Use this skill whenever the user wants a second opinion on code, cross-review, swarm review, peer review, external review, or wants codex/antigravity/gemini/kimi/glm to look at changes before shipping — even if they don't explicitly name the CLIs. Also trigger on "have codex check this", "get a second pair of eyes", "cross-check my changes", "review before merge", "swarm review", "review this PR", or right after Claude creates a PR. Do NOT trigger for routine lint/test runs, style-only checks, or when the user wants Claude itself (not external CLIs) to review.
---

# cross-review

Orchestrates a rotating fleet of external AI reviewers to review the current branch's changes, consolidates their findings, applies fixes, and re-runs until the diff is clean or an iteration budget is exhausted. The goal is to catch things a single model would miss — different reviewers have different blind spots, so their overlap is signal and their disagreements are worth reading.

**The fleet (baselines + rotation):** `codex` (OpenAI) and `kimi` (Moonshot) are **fixed baselines — on every round**. The rest of the roster rotates per round via `select_roster.sh`: a weighted random draw over `antigravity` (agy / Gemini 3.5 Flash, fast lap), `gemini-pro` (agy / Gemini 3.1 Pro, deep lap), and the OpenRouter pool — `glm` (GLM 5.2, Zhipu), `deepseek` (DeepSeek V4 Pro), `mimo` (Xiaomi MiMo v2.5), `minimax` (MiniMax M3), `qwen` (Qwen3 Coder Next, Alibaba), `devstral` (Devstral 2, Mistral), `laguna` (Poolside Laguna M.1), `kat` (KAT-Coder-Pro V2.5, Kuaishou), `north` (Cohere North Mini Code, free tier), `nemotron` (NVIDIA Nemotron 3.5 Lightning, free tier), `spark` (Meta Muse Spark 1.1), `seed` (ByteDance Seed 2.0 Code, added 2026-08-14), `grok` (xAI Grok 4.6, added 2026-08-14) — plus two seats on the **direct Moonshot platform API** (NOT an OpenRouter fallback, same billing rail as the kimi baseline): `kimi27` (Kimi k2.7-code, added 2026-07-03) and `kimi3` (Kimi K3, Moonshot's 2.8T-parameter flagship released 2026-07-16, added as a rotation seat 2026-07-18). Both carry a `draw_boost` in their profile while they're new, so they're drawn frequently to earn leaderboard data. Same provider as the kimi baseline — kimi+kimi27+kimi3 agreement is ONE provider vote. Draw weights come from the `leaderboard.sh` score, with an exploration bonus for under-sampled reviewers and an optional per-reviewer `draw_boost` multiplier from `reviewer_profiles.json`. **Every round has at least 3 reviewers.** See "Leaderboard & rotation" below.

**On the Gemini fleet:** `antigravity` and `gemini-pro` are both Google-Gemini reviewers running through the **same** `agy` (Antigravity) CLI, differing only by `--model` (Flash High vs. Pro High). The `agy` CLI replaced the standalone `gemini` CLI, which stopped serving consumer requests on **2026-06-18**. Because they share a provider, treat Flash↔Pro agreement as **one** provider's vote, not two independent ones. They also **share one Google "Individual quota"** (resets on a ~2-day cadence) — when it's exhausted, agy exits 0 with empty stdout in seconds and only the `.agy.log` says why; the wrapper detects this (`failure_kind: "quota_exhausted"` + an `agy.quota_exhausted` sentinel). The sentinel spares **retries and the fact-check pass** — the concurrently-launched sibling lap usually completes its own doomed ~5s call first, since laps start only 2s apart.

**No first-party fallbacks (policy, 2026-07-01):** codex, the Gemini laps, and any Claude reviewer are **never** routed through OpenRouter. A failed agy lap drops out of the round honestly; rotation covers the gap next round and the leaderboard down-weights it until it recovers. The OpenRouter pool reviewers require an OpenRouter key: `$OPENROUTER_API_KEY` env var or `~/.config/openrouter/key`.

## When to use this

- A PR has just been created by Claude and the user wants a second opinion before merge.
- The user asks to "cross-review", "swarm review", "get codex/antigravity/gemini/kimi to look at this".
- The user wants an agentic review loop that applies fixes rather than just listing them.

When in doubt, ask whether they want just findings or the full fix-and-iterate loop.

## Core workflow

The skill runs in this order. Do not skip steps — each produces state the next depends on.

### 1. Detect available reviewers

```bash
bash ~/.claude/skills/cross-review/scripts/detect_reviewers.sh
```

Prints JSON like `{"codex": true, "antigravity": true, "gemini-pro": true, "kimi": true, "glm": true, "deepseek": true, "mimo": true, "minimax": true, "qwen": true, "devstral": true, "laguna": true, "kat": true, "north": true, "nemotron": true, "spark": true, "seed": true, "grok": true, "kimi27": true, "kimi3": true, "openrouter": true}`. Note that `antigravity` and `gemini-pro` both track the **single `agy` binary**, the thirteen OpenRouter-pool reviewers all track the **single `openrouter` condition** (key + curl), and `kimi27`/`kimi3` both track the **single Moonshot platform key**. If none are available, stop and tell the user how to install them:

- codex: `brew install codex-cli`
- antigravity + gemini-pro (both via `agy`): `curl -fsSL https://antigravity.google/cli/install.sh | bash`, then `agy login` once
- kimi: `curl -L code.kimi.com/install.sh | bash`
- OpenRouter pool (glm/deepseek/mimo/minimax/qwen/devstral/laguna/kat/north/nemotron/spark/seed/grok): create a key at openrouter.ai, then `export OPENROUTER_API_KEY=...` or `mkdir -p ~/.config/openrouter && (umask 077; printf '%s\n' 'sk-or-...' > ~/.config/openrouter/key)`
- kimi27 + kimi3 (Kimi k2.7-code and Kimi K3, direct Moonshot): `export MOONSHOT_API_KEY=...` or `mkdir -p ~/.config/moonshot && (umask 077; printf '%s\n' 'sk-...' > ~/.config/moonshot/key)` — same platform key the kimi baseline bills against

Do not proceed with zero reviewers. (The standalone `gemini` CLI is no longer used — it was retired in the 2026-06-18 Gemini-CLI consumer sunset; both Gemini reviewers now run on `agy`.)

#### Baselines fail closed

`codex` and `kimi` are **fixed baselines**, not rotating seats. If either is
unavailable, `detect_reviewers.sh` prints its JSON as usual and then **exits 1**.
Callers must treat a non-zero exit as "do not run a round."

This used to be advisory — a missing baseline just reported `false` and the round
proceeded a reviewer short while looking perfectly healthy. On 2026-08-14 `codex`
fell off `$PATH` in kindred-mama-ai and **nine consecutive rounds ran without it**
before anyone noticed, because a missing verifier and a passing verification are
indistinguishable from the outside. The exit code is now the binding signal.

The usual cause is PATH, not a missing install. `codex` and `kimi` are npm globals
under `$NVM_DIR/versions/node/<version>/bin`, and nvm is a shell function from your
rc file that never runs in a non-interactive shell. The script resolves that
directory itself (via `alias/default`, falling back to the newest installed
version), so a correct install should just work — check `which codex` before
assuming otherwise.

To run degraded on purpose, make it explicit at the call site:

```bash
CROSS_REVIEW_ALLOW_MISSING_BASELINE=1 bash ~/.claude/skills/cross-review/scripts/detect_reviewers.sh
```

That downgrades the failure to a stderr warning. Use it for a deliberate
single-reviewer spot check, never as a default in a wrapper — a default there
recreates exactly the silence this replaced.

> **Do not retire the Gemini seats on a `gemini` CLI error.** Running `gemini` by hand now fails with `IneligibleTierError: This client is no longer supported for Gemini Code Assist for individuals` (`reasonCode: UNSUPPORTED_CLIENT`, `tierId: free-tier`). That is the **retired client** refusing to start — it says nothing about the seats this skill actually uses, and the error text itself names the migration target (`antigravity.google`) that `agy` already is. Verified live 2026-07-20: with `gemini` in that state, `agy -p` returns normal output and `agy models` lists Gemini 3.5 Flash + Gemini 3.1 Pro. **The only authority on Gemini-seat availability is `detect_reviewers.sh`** (which probes `agy`, never `gemini`). If it reports `"antigravity": true` / `"gemini-pro": true`, the seats are live — do not hand-drop the round to fewer reviewers.
>
> Corollary for the failure path: an agy lap that returns zero bytes is **not** automatically a dead seat. Check `failure_kind` in its `meta.json` — `headless_permission_denied` means the seat is authed and in quota but a tool confirmation was auto-denied; `print_timeout` (rc=1, stderr `Error: timeout waiting for response`) means agy's own `--print-timeout` expired and the remedy is a bigger `--timeout-<slug>`, since Gemini 3.1 Pro at High effort routinely needs 300-400s; only bare `empty_output` points at expired `agy login`. Each attempt's artifacts are kept at `<slug>.attempt<N>.{stdout,stderr,meta.json,agy.log}` — read attempt 1's when a lap only succeeded on retry.

> **`command(echo)` must be allow-listed for the agy laps to work at all.** agy ≥1.1.3 kills a headless run at 0 bytes the instant the model asks for a "command" permission, and both Gemini models always reach for a shell. `run_reviewers.sh` neutralises that with a `PreToolUse` hook (`scripts/agy_shell_gate.sh`, installed as a temporary `<repo>/.agents/hooks.json` and removed on exit) that rewrites every command to a harmless `echo` — but the rewritten line is still permission-checked, so `~/.gemini/antigravity-cli/settings.json` needs:
>
> ```json
> { "permissions": { "allow": ["command(echo)", "unsandboxed(echo)"] } }
> ```
>
> Both rules are needed — agy asks for `command(<target>)` for an ordinary shell step and `unsandboxed(<target>)` when the model escalates outside the sandbox, and the escalation is the model's own choice (so missing the second rule reads as an intermittent flake). Those two rules are the whole global footprint — no `--dangerously-skip-permissions`, no broad read-only allow-list (tried; it fails on the first unlisted command). `run_reviewers.sh` prints a WARN when the rule is missing. Full write-up: `docs/investigation-agy-empty-output.md`.

### 1.5 Pre-run health check (recent runlog)

Before spending tokens on a fresh round, glance at the last 10 runs to see if any reviewer is currently degraded. The analyzer surfaces only what's actionable — silent in the common case.

```bash
bash ~/.claude/skills/cross-review/scripts/analyze_runlog.sh --recent 10 --mode warn
bash ~/.claude/skills/cross-review/scripts/validate_or_models.sh
```

`validate_or_models.sh` checks every `cli: "openrouter"` model slug in `reviewer_profiles.json` against OpenRouter's live catalog (24h cache) and WARNs about any that have been delisted. A dead slug otherwise costs a whole round: the seat 404s in about a second and drops out, which reads as reviewer flakiness rather than stale config — `poolside/laguna-m.1` did exactly that on 2026-08-03, and `mistralai/devstral-2512` was silently queued to do the same. Fix the `model` field in the profile (the ONLY place slugs live) and re-run. This step is also what warms the cache: `run_reviewers.sh` re-checks at dispatch with `--no-fetch`, so no HTTP ever runs in front of the reviewers.

If a warning prints (e.g. *"WARN: gemini-pro timed out 35% of last 10 runs — consider --timeout-gemini-pro 1100"*), surface it to the user and ask whether to apply the suggested override for this run. Do not auto-apply — surface-and-confirm only. If no warning, proceed silently.

The analyzer has a separate `--mode report` that prints a full health snapshot; that's surfaced via `/cross-review --self-check`, not on every run.

### 2. Determine review scope and prepare an isolated worktree

Figure out what to review:

- **PR number given** (`/cross-review 123`): `gh pr view 123 --json baseRefName,headRefName,number,url` to get base branch, confirm current checkout matches head.
- **No PR number**: review current branch vs. its merge-base with `main` (or `origin/HEAD`). If there's no diff, stop and say so — nothing to review.

**Always run the review in an isolated worktree, never in the user's main checkout.** This avoids disturbing their uncommitted work and makes teardown trivial.

```bash
bash ~/.claude/skills/cross-review/scripts/worktree.sh start \
  --ref <pr-head-ref>      # e.g. origin/dq-22-empty-state-tab-bar or a SHA
  --id <slug>              # e.g. pr-213 or branch-dq-22
  --base <base-branch>     # defaults to origin/main
```

The script prints a single JSON line with:

- `worktree` — `/tmp/cr-<id>-<ts>/` — the detached checkout you `cd` into to run reviewers
- `run_dir` — `~/.cross-review/runs/<repo>-<id>-<ts>/` — **stable** output location that survives worktree teardown. All reviewer outputs, findings, and raw artifacts go here, not inside the worktree
- `size_files`, `size_lines` — diff size
- `warn_large_diff` — true if diff exceeds ~30 files or ~2000 lines
- `warn_secrets` — true if any changed path matches secret-like patterns (`.env`, `credentials`, `.pem`, `id_rsa`, keystores, etc.)
- `risky_files` — comma-separated list of the offenders (first 5)

**Pre-flight repo-state check.** Before dispatching reviewers, refuse to run on a dirty tree:

```bash
if git ls-files -u | grep -q . ; then
  echo "Working tree has unresolved merge conflicts. Resolve them or stash, then re-run." >&2
  exit 2
fi
if [ -n "$(git diff --check 2>/dev/null)" ]; then
  echo "Working tree has whitespace/conflict markers. Inspect with 'git diff --check' first." >&2
  exit 2
fi
```

Reviewers shown a half-resolved state will hallucinate confidently about the broken hunks.

**Before proceeding, check both warnings:**

- **On `warn_large_diff: true`**, stop and confirm with the user. Reviewers scale linearly with diff size; a big PR can easily cost 100k+ tokens per reviewer. Offer options: proceed anyway, narrow the scope to specific files via a custom prompt, or skip the run.
- **On `warn_secrets: true`**, show the flagged paths to the user and get explicit consent before sending the diff. All reviewers ingest the full diff (across three providers — OpenAI, Google, Moonshot) — even rotated-and-removed secrets would leave the machine. Path-based detection is a conservative first line; false positives (a file legitimately named `secret-sauce.md`) are fine, the user will wave them through.

If either warning fires, do **not** proceed silently. A skill that quietly sends sensitive content or bleeds tokens is worse than one that asks.

`worktree.sh start` writes that JSON to `$run_dir/context.json` itself — you do not need to. It records `head_sha` (the commit the worktree is actually on, which is what a later stamp must carry), plus `base_sha`, `ref`, `id`, `repo`, and `started_at`. `cd` into `$worktree`; future steps use `$run_dir` for outputs and `$worktree` as cwd.

> This used to read "Save the JSON to `$run_dir/context.json`" — prose, which an agent can skip, and did. On 2026-08-11 six kindred-mama-ai PRs (#3214, #3252, #3264, #3269, #3276, #3280) had 68–676KB of real reviewer output on disk, no `context.json`, and no posted comment; nothing could tell them from PRs nobody reviewed. A run that never recorded its SHA cannot be reconciled afterwards at any price, so the script records it.

Mint `run_id="$(basename "$run_dir")"` now — `worktree.sh` already builds `run_dir` from a globally-unique `<repo>-<id>-<ts>-<pid>` name, so its basename is a ready-made join key. Every finding-lifecycle event (step 4/4.5) and the runlog entry (step 9.5) for this pass carry this same `run_id`, so they can be joined later.

### 2.5. (Optional) Bound the input with `repomix-handoff`

For large diffs (`warn_large_diff: true`), or when a reviewer has a tighter context window than the diff allows, you may want to feed a token-budgeted snapshot to the CLIs instead of letting them ingest the full raw diff. Produce the snapshot(s) here, then pass `--snapshot-dir "$run_dir"` to `run_reviewers.sh` (step 3) — it auto-injects each matching `snapshot-<reviewer>.*` file into that reviewer's prompt in place of the raw diff.

This is a sibling skill, not a hard dependency. If `repomix-handoff` is missing, skip this step and continue with the default raw-diff flow.

```bash
# Detect availability — exits 0 if the sibling skill + repomix are both installed
if [ -x ~/.claude/skills/repomix-handoff/scripts/detect_repomix.sh ] && \
   ~/.claude/skills/repomix-handoff/scripts/detect_repomix.sh | grep -q '"available": true'; then
  # Per-reviewer snapshot (picks style + token budget that each CLI handles
  # best) — loop over THIS ROUND'S roster, not the full fleet
  for r in $(echo "$roster" | tr ',' ' '); do
    bash ~/.claude/skills/repomix-handoff/scripts/handoff.sh \
      --reviewer "$r" \
      --output "$run_dir/snapshot-$r.${EXT:-md}" >/dev/null
  done
fi
```

`--snapshot-dir "$run_dir"` auto-injects snapshots for kimi, the OpenRouter pool, and the two agy laps (antigravity/gemini-pro): for each dispatched reviewer `<r>`, `run_reviewers.sh` looks for `$run_dir/snapshot-<r>.md`, then `.xml`, then `.txt` (first match wins) and, if found, uses that file's contents as the code-context block instead of the raw diff — same fencing and prompt-injection defusal treatment as the raw-diff path, and no 8000-line cap (snapshots are already token-budgeted upstream). A reviewer with no matching file keeps the normal raw-diff path unchanged, so you don't need a snapshot for every reviewer in the roster. **agy-lap size cap**: agy's `-p` is argv-only (no stdin/file prompt mode), so for antigravity/gemini-pro a snapshot whose assembled prompt would exceed the 100KB argv guard is refused with a stderr WARN and that lap falls back to the raw diff — in practice keep agy snapshots under ~90KB, or accept the fallback. **codex is the one exception**: `codex exec review --base` does its own diffing internally and has no text-embedded diff to swap out, so a `snapshot-codex.*` file is ignored — if you need to bound codex's input too, drop `--base` and build a custom prompt by hand (see `references/cli_flags.md`).

The reviewer presets in `repomix-handoff` already bake in safe defaults (if it lacks the `antigravity`/`gemini-pro` keys, fall back to its `gemini` preset — same Google-Gemini context budget):

| Reviewer | Style | Max tokens |
|---|---|---|
| codex       | XML      | 160k |
| antigravity | Markdown | 1M   |
| gemini-pro  | Markdown | 1M   |
| kimi        | Markdown | 200k |
| OpenRouter pool (glm/deepseek/mimo/minimax/qwen/devstral/laguna/kat/north/nemotron/spark/seed/grok) | Markdown | 160k |
| claude      | XML      | 200k |

**Skip this step** if `warn_secrets: true` is still unresolved — bound or unbound, packed snapshots still contain whatever you pack.

### 2.6. (Optional) Enrich the reviewer prompt with `/impact` and `ast-grep scan`

Reviewers do better when they know what's affected and which project-specific rules already exist. Both checks are sibling skills / tools — degrade gracefully if missing.

**`/impact` — blast radius:** runs reverse-dep analysis to list affected files + recommended test files. Append to `$run_dir/context.md` so reviewers see it.

```bash
if [ -x ~/.claude/skills/impact/scripts/impact.sh ]; then
  bash ~/.claude/skills/impact/scripts/impact.sh --base "$base_branch" --json \
    > "$run_dir/impact.json" 2>/dev/null || true
fi
```

**`ast-grep scan` — project rules:** if the target repo has `sgconfig.yml` at its root, run a scan over the diff and surface findings. Catches violations of repo-specific architectural rules (e.g. "do not write to `memory_items` outside `FirestoreMemoryClient`") that reviewers wouldn't know to look for.

```bash
if [ -f "$worktree/sgconfig.yml" ] && command -v ast-grep >/dev/null; then
  ( cd "$worktree" && ast-grep scan --json=stream 2>/dev/null ) \
    > "$run_dir/sgscan.jsonl" || true
fi
```

When either file exists, generate the summary deterministically — do **not** summarize by hand and do **not** dump full JSON into the prompt:

```bash
bash ~/.claude/skills/cross-review/scripts/digest_context.sh \
  --sgscan "$run_dir/sgscan.jsonl" --impact "$run_dir/impact.json" \
  >> "$run_dir/context.md"
```

`digest_context.sh` emits a ≤20-line markdown digest (findings grouped by rule, top offending files, affected-file/test counts with overflow markers) — byte-identical for identical inputs. Splice its stdout into the reviewer prompt's preamble. Either flag may be omitted when that input doesn't exist.

### 3. Pick the roster and run reviewers in parallel

**Call `select_roster.sh` yourself first** (rather than leaving it to `run_reviewers.sh`'s internal default) so this round's draw gets a durable record instead of only a stderr line a human happens to read once:

```bash
bash ~/.claude/skills/cross-review/scripts/select_roster.sh --json --extras 2 \
  > "$run_dir/roster_decision.json"
roster="$(jq -r '.roster' "$run_dir/roster_decision.json")"

bash ~/.claude/skills/cross-review/scripts/run_reviewers.sh \
  --base <base-branch> \
  --reviewers "$roster" \
  --out "$run_dir/raw"
```

`select_roster.sh --json` picks codex + kimi (fixed baselines) plus a leaderboard-weighted random draw from the rotation pool (default 2 picks, always ≥3 reviewers total), and its stdout carries the full decision record: `roster`, `baselines`, `selected`, `seed`, `policy_version`, and a `candidates` array (every pool member considered, with its score/weight/latest_status). The stderr candidate lines are still printed for the log tail — surface the roster line to the user same as before. Pass `--reviewers <comma-list>` directly to `run_reviewers.sh` (skipping `select_roster.sh` entirely) only when the user asks for specific reviewers or for the full fleet.

The wrapper handles the flag dialects:

- `codex exec review --base <branch> --full-auto`
- `agy --model "Gemini 3.5 Flash (High)" --sandbox -p '<prompt>'` — the **antigravity** reviewer (fast lap)
- `agy --model "Gemini 3.1 Pro (High)" --sandbox -p '<prompt>'` — the **gemini-pro** reviewer (deep lap; same `agy` binary, different model)
- `kimi --plan --print --quiet` with the prompt piped via stdin
- `curl` against the OpenRouter chat-completions API with the diff inlined (8000-line cap, like kimi) — the whole rotation pool: **glm** (`z-ai/glm-5.2`), **deepseek** (`deepseek/deepseek-v4-pro-0813`), **mimo** (`xiaomi/mimo-v2.5`), **minimax** (`minimax/minimax-m3`), **qwen** (`qwen/qwen3-coder-next`), **devstral** (`mistralai/mistral-large-2512`), **laguna** (`poolside/laguna-s-2.1`), **kat** (`kwaipilot/kat-coder-pro-v2.5`), **north** (`cohere/north-mini-code:free`), **nemotron** (`nvidia/nemotron-3.5-lightning:free`), **spark** (`meta/muse-spark-1.1`), **seed** (`bytedance-seed/seed-2.0-code`), **grok** (`x-ai/grok-4.6`)
- Same curl body against the **direct Moonshot** chat-completions endpoint — **kimi27** (`kimi-k2.7-code`, cli label `moonshot` in meta.json) and **kimi3** (`kimi-k3`, cli label `moonshot` in meta.json)

Outputs land at `<reviewer>.{stdout,stderr,meta.json}` (OpenRouter reviewers also write `request.json`/`response.json` for audit); each `meta.json` carries `model` and `cli` fields — and, for the agy laps, a `failure_kind` field (`quota_exhausted` | `agy_panic` | `empty_output` | null). There are **no fallback runs**: a failed lap's meta says why it failed and that's the record. The wrapper returns when all are done.

**Modes:**
- **rotation** (default): baselines + weighted draw, as above.
- **swarm**: `--reviewers` with every reviewer the detect step found. Maximum coverage, maximum tokens — for release-critical reviews.
- **solo**: run just one (the fastest available). Useful when the user wants a quick sniff test.

**Round deadline + trailing reviewers (speed without quality loss).** A round should return in **~10 minutes**. Some reviewers legitimately need far longer on large diffs — kimi-k2.5's thinking mode runs ~500s per 1,000 diff lines (observed: 43 min on a 4.6k-line diff), and some OpenRouter models stream slowly on 300KB prompts. Do NOT block the round on them and do NOT truncate their input. Instead:

1. Before dispatching, estimate each roster member's duration: leaderboard `p50_duration_s`, plus kimi's size scaling (`~84s + 500s × diff_klines`).
2. Any reviewer predicted well past the deadline becomes **trailing**: dispatch it as a *separate* background `run_reviewers.sh --reviewers <r>` call into the same `$run_dir/raw`, and run the main round without it.
3. Synthesize, verify, and post the pass on time from the delivered reviews, noting `<r> trailing` in the report block and PR comment.
4. When the trailing reviewer lands, read its output; if it adds real findings, post a short addendum comment and fold them into the next pass's triage. Its meta is on disk, so the runlog entry for the pass can be appended after it lands (or note it as trailing).
5. On large diffs, add one extra fast rotation pick (`--extras 3`) so breadth compensates while depth trails.

The principle (Gabriel, 2026-07-01): **latency shapes scheduling — who is drawn, what trails — never the quality bar.** Baselines stay on every round, verification gates always run, no reviewer's input gets silently truncated.

The wrapper logs timing and exit codes per reviewer. If one fails, continue with the rest — a partial review is still useful. If all fail, stop and surface the errors.

### 4. Synthesize findings

**First, run the deterministic pre-pass.** The curl-lane reviewers (OpenRouter pool + kimi27/kimi3) are forced to answer in the findings-JSON schema (`response_format: json_object` + `references/json_findings_suffix.txt`), so their output needs no LLM extraction:

```bash
bash ~/.claude/skills/cross-review/scripts/merge_raw_findings.sh \
  --raw "$run_dir/raw" --out "$run_dir/findings.premerged.json"
```

Every reviewer whose stdout parsed cleanly is folded into `findings.premerged.json` with `sources` tags; reviewers listed as `unparsed:` on stderr (the CLI prose lanes — codex, agy laps, kimi CLI — plus any curl-lane reviewer that ignored the schema) are yours to extract by hand. Then score the merged set deterministically:

```bash
bash ~/.claude/skills/cross-review/scripts/score_findings.sh \
  --findings "$run_dir/findings.json" --out "$run_dir/findings.scored.json"
```

`score_findings.sh` computes `providers`, `provider_votes`, `convergent`, `disposition` (from the `skip_unless_convergent`/`high_precision`/`trust_if_convergent` priors), and `rank_score` — the provider-vote and prior arithmetic below is now encoded there; trust its output over head-math.

Read the remaining **unparsed** files under `raw/` yourself — for those free-form outputs you (the model) are still the extractor. For each such file:

- Pull out concrete issues tied to specific files/lines when possible.
- Drop pure praise, filler, and anything not actionable.
- Note the reviewer (codex / antigravity / gemini-pro / kimi / glm) so the user can see agreement vs. disagreement.

Produce a merged list at `$run_dir/findings.md` with this structure:

```markdown
# Cross-review findings — <branch> vs <base>

## Critical
- **[file:line]** <one-line title> (sources: codex, antigravity, gemini-pro, kimi)
  <why it matters, concrete fix sketch if offered>

## High
- ...

## Medium
- ...

## Low / nits
- ... (can be batched; don't need individual treatment)
```

**Severity rubric** (borrow the reviewers' judgment when they offer one, otherwise apply yours):

- **Critical**: breaks correctness, leaks secrets, opens security hole, crashes in normal use.
- **High**: violates a project constraint from CLAUDE.md (e.g., hardcoded colors vs. design tokens, mocks in integration tests), wrong semantics that tests wouldn't catch, bad defaults.
- **Medium**: risky edge case, poor error handling at a boundary, unclear naming that will trip future readers.
- **Low / nit**: style, minor phrasing, minor optimization.

When multiple reviewers flag the same issue at different severities, take the highest one and note the disagreement. Convergence across providers is a very strong signal; a finding flagged by only one deserves more skepticism.

**Provider independence matters more than reviewer count.** `antigravity` and `gemini-pro` are the same provider (Google/Gemini, both via `agy`) — if only those two agree, that's effectively *one* independent vote, not two. Every profile in `reviewer_profiles.json` carries an explicit `provider` field (openai, google, moonshot, zhipu, deepseek, xiaomi, minimax, sakana, cohere, nvidia) — count convergence by distinct providers, not reviewer names. Weight a codex+gemini-pro+kimi agreement far above an antigravity+gemini-pro agreement even though both are "two reviewers." Routing wrinkle: the OpenRouter pool rides one router but each model is its own provider vote — OpenRouter is a router, not a provider. See `reviewer_profiles.json` `_synthesis_rules.provider_independence`.

**Apply per-reviewer priors from `references/reviewer_profiles.json` when triaging:**

- A finding tagged `skip_unless_convergent` for that reviewer's severity should be dropped if no other reviewer flagged the same area. Codex P3 nits and kimi Low/nit findings are the typical examples. (For "convergent" here, prefer a *different-provider* corroboration — antigravity backing gemini-pro doesn't lift a `skip_unless_convergent` finding much, since they're one provider.)
- A finding tagged `high_precision` (codex P1 today) should rank as near-certain real even if solo.
- `trust_if_convergent` means: keep when 2+ reviewers agree on it; downgrade or move to "verify" when solo.
- When two reviewers disagree on severity, break the tie with `synthesis_weight` (higher weight wins).

These priors live in `reviewer_profiles.json` — read once at synthesis time, edit there (not inline) when tuning. The analyzer's `--mode report` will eventually suggest edits to these values based on observed convergence and precision rates.

**Also emit a structured `findings.json` sidecar** next to `findings.md` — this feeds the fingerprint step below, which in turn feeds the step 4.5 verification gate. One object per finding:

```json
{
  "base": "<base-ref>", "head": "HEAD",
  "findings": [
    { "id": "f1", "severity": "Critical|High|Medium|Low",
      "file": "path/relative/to/repo", "line": 42,
      "snippet": "the exact offending line(s) the reviewer quoted, verbatim",
      "claim": "one-line statement of what is wrong",
      "sources": ["codex", "gemini-pro"], "suggested_fix": "optional" }
  ]
}
```

The `id` here is just a local sequence number for this pass — `fingerprint_findings.sh` (next step) replaces it with a stable, content-derived id before anchor/fact-check run. The `snippet` field is load-bearing: it is what the anchor pass matches against the diff and what the fact-check pass falsifies. When a reviewer didn't quote the offending code, pull the line from the diff yourself; if you genuinely can't, leave `snippet` empty (that finding simply won't be anchorable).

**Fingerprint findings** — give each finding a stable id before anchor/fact-check touch it, so its lifecycle can be tracked across passes:

```bash
bash ~/.claude/skills/cross-review/scripts/fingerprint_findings.sh \
  --findings "$run_dir/findings.json" --project "$(basename "$(git -C "$worktree" rev-parse --show-toplevel)")" \
  --out "$run_dir/findings.fingerprinted.json" --emit-events "$run_id"
```

Replaces each finding's `id` (the local "f1" sequence number, preserved as `local_id`) with a stable `f-<hash>` derived from `project|file|claim` — so the same real-world issue keeps the same id pass-to-pass, which nothing did before. `--emit-events` appends one `proposed` event per (finding × contributing reviewer) to `~/.claude/skills/cross-review/finding_events.jsonl`. Feed `findings.fingerprinted.json` — not the raw `findings.json` — into the anchor step below.

### 4.5 Verify findings — anchor + fact-check (recommended; required before auto-fix)

Two cheap passes that raise precision before any fix touches the tree. Lifted from open-code-review (see `docs/investigation-cr-ocr-ideas.md`). Run them in order on the `findings.fingerprinted.json` from the fingerprint step above:

**(a) Anchor — deterministic, no tokens.** Re-derive each finding's line by matching its `snippet` against the actual diff hunks:

```bash
bash ~/.claude/skills/cross-review/scripts/anchor_findings.sh \
  --findings "$run_dir/findings.fingerprinted.json" --base <base-branch> --repo "$worktree" \
  --out "$run_dir/findings.anchored.json" --emit-events "$run_id"
```

Each finding gains `anchor: {resolved, start_line, end_line, side}`; resolved findings get their `line` corrected. A finding with `anchor.resolved=false` (snippet found nowhere in the diff) is a strong **hallucinated-location** signal — mark it "⚠ unanchored" in `findings.md` and **do not auto-fix it without human confirmation**. Don't auto-drop it: a reviewer may legitimately cite an unchanged neighbouring line. `--emit-events` appends one `anchored` event per finding to `finding_events.jsonl`.

**(b) Fact-check — falsify-only LLM pass.** A cheap, diff-only reviewer removes findings the diff itself *disproves*:

```bash
bash ~/.claude/skills/cross-review/scripts/factcheck_findings.sh \
  --findings "$run_dir/findings.anchored.json" --base <base-branch> --repo "$worktree" \
  --reviewer agy --out "$run_dir/findings.verified.json" --emit-events "$run_id"
```

Each finding gains `factcheck: {verdict: "keep"|"drop", reason}`. The pass can **only drop a finding the diff actively contradicts** — it never invents findings and keeps anything it merely can't confirm (recall-safe by design; `references/factcheck_prompt.txt`). It is **fail-safe**: any error/timeout/unparseable response keeps every finding. When agy fails or returns empty (quota/panic/auth), the script automatically retries once via `deepseek/deepseek-v4-flash` on OpenRouter before the keep-all fail-safe — so the veto survives agy outages. (DeepSeek Flash, not OR-hosted Gemini: first-party models are never routed through OpenRouter by policy.) `--reviewer openrouter` also works to skip agy entirely. Exclude `verdict:"drop"` findings from the auto-fix triage and note them (struck through, with the veto reason) in `findings.md` and the record. `--emit-events` appends one `factcheck_kept`/`factcheck_dropped` event per finding to `finding_events.jsonl` — including on the fail-safe keep-all paths, so a "agy was down, kept everything" round still lands in the ledger.

**Parent direct-source verification may replace this pass entirely.** When you (the orchestrating session) have already verified each finding against the actual source files, test runs, or a live smoke test — evidence *stronger* than a diff-only LLM veto — running the LLM fact-check adds nothing: skip it. Two conditions bind: (1) the evidence gate still applies — every `verdict:"drop"` needs concrete falsification evidence in `factcheck.reason` (`append_runlog.sh` rejects reasonless drops regardless of who did the verifying); (2) record the substitution in the runlog `notes` (e.g. "factcheck replaced by parent direct-source verification") so the self-improvement loop can distinguish a skipped gate from a substituted one. This formalizes the de facto pattern from the 2026-07-03 rounds (PRs #2619–#2621).

**(c) Runtime-behavior claims — smoke-test in BOTH directions.** When a finding, or your reason for *declining* one, rests on a claim about runtime behavior — coreutils/awk/bash semantics, what an API actually returns, how a CLI parses a flag — run the 5-second smoke test before acting, whichever way you lean. The history cuts both ways: convergent findings have been falsified by one command (the 137→124 remap on PR #21 — two providers shared the same wrong `timeout -k` assumption; the `node -e` argv "Critical" on PR #13), and a solo finding that pattern-matched "probable false positive" was **confirmed** the same way (the awk backslash `od` test on PR #23). Pattern-matching on which reviewer said it, or how many agreed, is not verification. Record the outcome where it binds: a drop's evidence goes in `factcheck.reason` — **`append_runlog.sh` rejects reasonless drops** — and a confirmed falsification becomes a code comment at the exact line plus a regression test, so the guarantee travels with the code instead of living in session memory.

This gate is **cheap** (anchor is free; fact-check is one Flash-tier call) and most valuable exactly when auto-fix is opted in. Skip it only for a quick report-only sniff test. The `convergent` count and `Top` in the report block (step 9) should reflect the post-verification set.

### 5. Triage and apply fixes (opt-in only)

**Default is report-only.** The skill does **not** modify files or create commits unless the caller has explicitly opted in — either by passing `--apply-fixes` to the invoking skill command, or because the user said "apply the fixes" / "fix these and re-review" / equivalent in prose. If neither signal is present, skip this section and jump to step 7 (post the record).

This default exists because (a) the fix loop has far less production exposure than the detection phase, (b) a wrong auto-fix commit on the user's branch is hard to undo cleanly, and (c) reviewers sometimes flag things that are not actually bugs (see the RewardCard PR where `hardcoded Colors.dark` was intentional). When in doubt, the cheaper path is to report and let the user decide.

**When auto-fix is opted in:** first run the step 4.5 verification gate if you haven't. Triage operates on the **verified** set — `factcheck.verdict:"drop"` findings are excluded outright, and `anchor.resolved:false` findings are held for human confirmation rather than auto-fixed.

Triage policy: fix Critical and High findings where the reviewer's suggested fix is unambiguous; surface Medium for the user; ignore Low/nits unless asked.

For each fix:
1. Read the relevant files to understand the real context. The anchor pass already corrected `line` to the real hunk line (`anchor.start_line`) — trust that over the reviewer's original claim, and treat any still-unanchored finding as suspect.
2. If the suggested fix depends on a design decision (e.g., "should this be null-coalesced or throw?", "should this be a union type or an enum?"), stop and ask the user. Don't guess on semantics — the point of opt-in auto-fix is to handle the mechanical cases, not make product decisions.
3. Apply the change.
4. Run local checks if cheap: `pnpm lint` on touched packages, relevant unit tests. Don't run the full suite between every fix — batch and run once at the end of the pass.

When all Critical/High fixes for the pass are in, commit:

```bash
git add -p  # or specific paths
git commit -m "$(cat <<'EOF'
fix: address cross-review findings (pass <N>)

- <terse summary of what changed>

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

### 6. Re-review loop

After committing, re-run steps 3–5 — but **incrementally**: pass the *previous pass's HEAD* as `--base` so reviewers see only the fix commits, and include the prior pass's findings table in the prompt preamble with the ask "verify each fix landed; scan only these new hunks for regressions." A re-pass is answering a narrow question, not re-finding everything — this cuts pass-2+ from ~30 minutes to single digits on large PRs (and it's why big-diff first passes are the only slow case). Use `select_roster.sh --fast` for re-pass rotation picks. Run the full-diff review only when the fixes were structural enough to invalidate the original review's context.

Keep iterating until any of:

- No Critical or High findings remain.
- **Iteration cap: 3 passes.** If the reviewers are still finding Critical/High on pass 3, stop and hand to the user — something structural is wrong and more passes won't fix it.
- The same finding recurs across passes (reviewer doesn't accept the fix). Stop and ask the user.

Each pass's artifacts go in a new `run-<timestamp>/` so the record is preserved.

### 7. Post the record

Write a PR-level record so future Claude runs (or human reviewers) can see what happened. The record mode is configurable — the cheapest default is `summary`.

```bash
bash ~/.claude/skills/cross-review/scripts/post_comment.sh \
  --pr <pr-number> \
  --mode <summary|file|none> \
  --findings "$run_dir/findings.md" \
  --head-sha "$(jq -r .head_sha "$run_dir/context.json")" \
  --repo "$(jq -r .repo "$run_dir/context.json")"
```

**`--head-sha` is required in `summary` mode, and the script now enforces it.**
It used to be optional with this paragraph asking nicely, which meant the stamp
was optional, which meant it was not a stamp. Omit it and `post_comment.sh`
exits 2 without posting; the findings stay on disk and `posted.json` records
`no-head-sha`, so re-running with the sha is the fix. `file` and `none` modes
are unaffected, because they write nothing to GitHub.

Read it from `context.json` (`jq -r .head_sha "$run_dir/context.json"`) rather
than re-resolving the ref, so the stamp matches what the reviewers actually saw.
Pass the full 40 characters. The script expands an abbreviation via
`git rev-parse` when it can, and warns and falls back to the prose stamp when it
cannot.

#### The marker contract

`post_comment.sh` writes two stamps into every posted comment. They are not
redundant; they have different readers.

```
<!-- cross-review: sha=<40-char-sha> pass=<n> -->     ← the gate reads this
_Automated review by codex + kimi. Reviewed `abc123def`._   ← people read this
```

The HTML comment is the contract. `scripts/cross-review-currency.sh` in
kindred-mama-ai matches it with `CR_MARKER_RE` and prefers it over the prose
whenever both are present, because the marker is machine-written and the prose
is not. Keep its shape byte-stable: single line, invisible in rendered
markdown, full 40-char sha, `pass=` second.

The gate still accepts the prose forms — both `` Reviewed `sha` `` and
`` Reviewed at `sha` `` — as a fallback, so comments posted before the marker
existed keep working. Do not rely on that when composing a comment by hand.
On 2026-08-14 a census of the ten most recent cross-review comments on open PRs
found four (#3376, #3374, #3371, #3362) that had been reviewed at their exact
current head and were rejected by the gate because a model had written
"Reviewed at" where the script writes "Reviewed", and four more (#3369, #3367,
#3363, #3073) carrying no sha at all. That is the whole reason the marker
exists: **post the comment through `post_comment.sh` rather than composing the
body yourself.** A hand-written comment carries no marker and is at the mercy of
one English word.

**Do not skip this step.** `post_comment.sh` writes `$run_dir/posted.json` on
every terminal path — `posted`, `gh-comment-failed`, `gh-unavailable-or-no-pr`,
`file-mode`, `mode-none` — so a drop is detectable afterwards. The absence of
`posted.json` means the run never reached this step at all, which is how six
real reviews went invisible. `scripts/reconcile.sh` reports those:

```bash
bash ~/.claude/skills/cross-review/scripts/reconcile.sh          # report only
bash ~/.claude/skills/cross-review/scripts/reconcile.sh --post   # opt-in, posts
```

It exits 1 when anything is droppable. Runs whose SHA was never recorded are
reported as `unattributable` and are **not** posted — re-posting one would mean
stamping a guessed commit, and the stamp's whole value is that it is not a
guess. Those need a fresh review. `--post` is never the default: posting a
comment is an outward-facing act, and a scan that does it as a side effect is
the wrong shape regardless of how good the classification is.

This exists because a review record is read long after it is posted, and
without the SHA it reads as authoritative about whatever the PR contains
*now*. On kindred-mama-ai#3207 the head moved four times in one session; one
push reverted a P1 that two independent providers had confirmed and deleted
its regression test, while the posted record still looked definitive. The same
PR was merged **19 minutes before its review finished**, so a reviewer opening
that comment had no way to see that every finding in it was already shipped.

**Prefer `summary` whenever you have a PR number.** The stamp can only be read
back off a comment that actually exists on GitHub — a review that lands only in
`$run_dir/findings.md` is invisible to the merge gate below, and to everyone who
was not in the session.

### 7b. The gate that reads the stamp

A stamp nothing reads is a sensor with nothing wired to it. Two readers exist:

```bash
# Is this PR's newest review record bound to the commit about to be merged?
bash ~/.claude/skills/cross-review/scripts/merge_preflight.sh --pr <n> [--json]
#   exit 0  clear · reviewed at head, or no record, or the check couldn't run
#   exit 1  STALE · a record exists and covers a different commit
```

`hooks/merge_gate.sh` makes that binding on the agent. Wire it once in
`~/.claude/settings.json` and `gh pr merge` is refused whenever the newest
record covers a different commit:

```json
{ "hooks": { "PreToolUse": [
    { "matcher": "Bash", "hooks": [
        { "type": "command",
          "command": "/Users/<you>/.claude/skills/cross-review/hooks/merge_gate.sh" } ] } ] } }
```

Two deliberate limits. It is **green when absent** — a PR with no cross-review
comment is not blocked, because this is a safety net over reviews you already
run, not a mandate that every PR be reviewed; making it a mandate is a policy
decision, not a default. And it **fails open** on every ambiguity (no `gh`, no
auth, API error, unparseable record), because a gate that blocks merges whenever
GitHub hiccups gets switched off within a day and then protects nothing.

When a stale merge is genuinely intended — the delta is a rebase, a lockfile, a
typo — prefix the command with `CROSS_REVIEW_MERGE_OVERRIDE=1`. That is an
**auditability** mechanism, not a security boundary: an agent could write it
unprompted, but it puts the bypass in the command the user approves instead of
leaving the agent with an instruction no command could express.

**On a `clear` verdict it still asks for one thing:** that the merge carry
`--match-head-commit <sha>`. A verdict is a statement about the head at read
time, and a push landing before GitHub handles the merge would be merged
unreviewed. Binding the merge makes GitHub itself refuse in that case — the
difference between "was true a moment ago" and a guarantee. It is required only
where there is something to bind to; an unreviewed PR is never forced to, or
green-when-absent would quietly become a review mandate.

`gh api ... repos/O/R/pulls/N/merge` is gated the same way. It merges a PR
without ever saying `gh pr merge`, which makes it the first thing a blocked
agent would reach for rather than an exotic edge case.

**What it still cannot see.** It reads the command text, so a merge inside a
shell script it cannot read, a GraphQL `mergePullRequest` mutation (the PR is a
node ID there, with nothing to resolve), and the GitHub web UI all go around
it — as does automerge, which is not an agent command at all.

The hook never rewrites commands. Another `PreToolUse` hook may return
`updatedInput` and two rewriters would fight — verified live here: rtk rewrites
`gh pr merge` to `rtk gh pr merge` and returns `permissionDecision: "allow"`.
Deny still wins over that allow (verified with an always-stale stub), and the
whitespace leading anchor is what keeps `rtk gh …` matching at all.

Those remaining gaps are why the hook should not be the only reader. A GitHub
status check running the same comparison on `pull_request` + `issue_comment`
covers every one of them, binds humans and automerge too, and — unlike a
review-hold label — keeps no state to leak and self-heals (push a commit → red;
re-review → green).

**Modes:**

- **summary** (default): one consolidated PR comment per pass via `gh pr comment`. Cheap (one API call), easy to scan in the PR timeline, good record for future Claude runs.
- **file**: no PR post; rely on the already-written `$run_dir/findings.md`. Zero GitHub cost, only useful locally.
- **none**: nothing posted, nothing saved beyond the in-memory turn. Don't use unless the user explicitly asks.

Inline-per-finding mode was considered and dropped: 5–10× the API calls, harder to scan at a glance, and the information is already in `summary` with file:line references. If you ever want inline, it's a conversation starter, not a default.

If no PR exists yet, `summary` falls back to `file` automatically — don't fail the run.

### 8. Tear down the worktree

After the record is posted (or the fix loop has exited one way or the other), remove the worktree. Run dirs under `~/.cross-review/runs/` are the permanent record and are **not** touched.

```bash
bash ~/.claude/skills/cross-review/scripts/worktree.sh end --worktree "$worktree"
```

Idempotent — safe to call even if something earlier already removed it. If teardown fails, surface the error but don't treat the run as failed; the user can manually `rm -rf /tmp/cr-*` or run the sweeper.

On any subsequent invocation of this skill (new or same session), start by running a sweep to garbage-collect orphaned worktrees from crashed or interrupted earlier runs:

```bash
bash ~/.claude/skills/cross-review/scripts/worktree.sh sweep
# removes /tmp/cr-*/ older than 24h; safe to run any time
```

This keeps `git worktree list` and `/tmp` clean without the user needing to remember cleanup.

### 9. Report back to the caller

Whoever invoked this skill — the user directly, or a parent agent (e.g., a `/pr` wrapper) — needs a decision-ready summary without reading the full `findings.md`. Generate the block deterministically rather than hand-formatting it:

```bash
bash ~/.claude/skills/cross-review/scripts/report_block.sh \
  --findings "$run_dir/findings.verified.json" --pass <N> \
  --verdict <CLEAN|FIXES_APPLIED|NEEDS_DECISION|BLOCKED> \
  --record "$run_dir/findings.md" --next <stop|re-review|ask-user|apply-fixes> \
  [--pr-url <url>] [--notes "<≤1 sentence>"] [--roster-decision "$run_dir/roster_decision.json"]
```

It excludes factcheck-dropped findings from counts, computes `convergent` by distinct provider, and picks `Top` per the selection rule below. At the end of **every pass**, emit its output verbatim as the last thing you say before yielding control:

```
── cross-review pass <N>/3 ──
Verdict: CLEAN | FIXES_APPLIED | NEEDS_DECISION | BLOCKED
Counts:  C:<n> H:<n> M:<n> L:<n>  (convergent: <n>)
Top:     <file:line> — <one-line title> [<severity>][sources, e.g. codex+gemini-pro+kimi | codex+antigravity | gemini-pro | kimi]
Record:  ~/.cross-review/runs/<repo>-<id>-<ts>/findings.md  (posted to PR: <url|—>)
Next:    stop | re-review | ask-user | apply-fixes
Notes:   <≤1 sentence if something non-obvious happened — reviewer disagreement, rate-limit retries, partial failure>
──────────────────────────────
```

**Verdict semantics:**

- **CLEAN** — No Critical/High after this pass. The skill is done; caller can merge.
- **FIXES_APPLIED** — Critical/High found *and auto-fixed* in this pass. Another pass will run to verify; caller should not intervene yet.
- **NEEDS_DECISION** — Critical/High found but requires human judgment (design decision, scope question, semantic ambiguity). Caller must respond before the skill can continue.
- **BLOCKED** — Cannot proceed: all reviewers failed, auth missing, iteration cap hit with findings still outstanding, same finding recurs across passes. Caller needs to investigate.

**Convergent** counts findings that two or more reviewers independently flagged on the same file/area — but weight by *provider*, not raw reviewer count (each profile's `provider` field is the truth). Agreement between `antigravity` and `gemini-pro` alone is one provider agreeing with itself, so discount it toward single-reviewer skepticism. Three-plus distinct-provider convergence (e.g. codex + a Gemini lap + kimi, or codex + kimi + a rotation pick) is the strongest signal of all — treat those findings as near-certain to be real.

**Top** is the single most important finding — Critical > all-provider-convergent High > two-provider convergent High > single-reviewer High. Pick one; surface the rest via the Record link.

**Next** is what the skill intends to do (or wants the caller to do):

- `stop` — clean, done.
- `re-review` — fixes committed, skill will run another pass automatically.
- `ask-user` — NEEDS_DECISION pending; skill yields until the caller responds.
- `apply-fixes` — skill is about to fix; report is mid-pass, not final. (Use only if your flow splits fix & report into separate turns.)

Keep the block exactly this shape — parent agents key off the field names. Anything else (longer analysis, reviewer prose) goes in `findings.md`, not in the report block.

### 9.5 Append runlog entry

After the report block — and before worktree teardown — append a structured JSONL entry to `~/.claude/skills/cross-review/runlog.jsonl`. This is what the Phase 1.5 pre-run check and `/cross-review --self-check` read; without it, the self-improvement loop has no data.

```bash
bash ~/.claude/skills/cross-review/scripts/append_runlog.sh \
  --run-dir "$run_dir" \
  # ↑ The script auto-resolves $run_dir/raw/<reviewer>.meta.json (canonical
  # location, written by run_reviewers.sh step 3) and falls back to
  # $run_dir/<reviewer>.meta.json. Either path works.
  --project "$(basename "$(git -C "$worktree" rev-parse --show-toplevel)")" \
  --base "$base" \
  --pr "${pr:-"-"}" \
  --pass "$N" \
  --verdict "<CLEAN|FIXES_APPLIED|NEEDS_DECISION|BLOCKED>" \
  --convergent "<n>" \
  --top "<file:line — title [severity][sources]>" \
  --diff-files "<n>" --diff-lines "<n>" \
  --notes "<≤1 sentence on anything non-obvious>" \
  --findings "$run_dir/findings.verified.json" \
  --run-id "$run_id" \
  --roster-decision "$run_dir/roster_decision.json"
```

The script reads each `$run_dir/<reviewer>.meta.json` to fill in per-reviewer telemetry — duration, exit code, timed_out, output_bytes, attempt — so you only pass the high-level verdict and one-line summary. Pass `-` for `--pr` on branch-only runs (no GitHub PR).

`--run-id` and `--roster-decision` are both optional and purely additive — pass `--run-id "$run_id"` (minted in step 2) always, and `--roster-decision "$run_dir/roster_decision.json"` whenever that file exists (it will, if step 3 used the `select_roster.sh --json` invocation above). `--run-id` is load-bearing for scoring: `leaderboard.sh` joins the runlog entry to `finding_events.jsonl` by `run_id` and scores that round per-finding (severity-weighted, with unique-discovery credit — solo 1.0 / no-baseline corroboration 0.85 / baseline-corroborated 0.7, unanchored ×0.5, disproven 0). Entries without a `run_id` — or rounds run without `--emit-events` — fall back to the aggregate-count formula. `--roster-decision` isn't read by `leaderboard.sh` yet; it exists so a future pass can see exactly what each round's draw considered.

**Always pass `--findings` with the most-verified findings JSON you have** (note: it hard-rejects any `verdict:"drop"` finding whose `factcheck.reason` is empty — falsification evidence is mandatory, not advisory) (post-anchor, post-factcheck). It enriches each reviewer's entry with `findings_total` / `findings_convergent` / `findings_dropped` — the quality signals `leaderboard.sh` scores on. Skipping it starves the leaderboard: that reviewer's run scores on reliability alone.

Append once per pass (not once per multi-pass run). The runlog is JSONL: one line per pass, append-only, safe under concurrent splitstream rounds.

## Reviewer-specific notes

- **codex**: Uses `codex exec review --base <branch> --full-auto`. Writes review output to stderr (we merge streams with `2>&1`). `--json` mode emits reasoning/command events but does **not** flush the final review summary — use plain-text mode. `--base` and a positional `[PROMPT]` are mutually exclusive; with `--base`, codex uses its own built-in review instructions.
- **antigravity** (Gemini 3.5 Flash, fast lap): Uses `agy --model "Gemini 3.5 Flash (High)" --sandbox -p '<prompt>'`. `--sandbox` plus a "do not edit" prompt instruction keeps it read-only. Needs an explicit review prompt (see `references/review_prompt.txt`). Replaces the retired standalone `gemini` CLI. **Gotcha:** `agy --model` accepts only the exact `agy models` display string and **silently falls back to Flash** on a typo — never errors. Auth: `agy login` once (Google OAuth). **Empty output has two causes, not one**: check `failure_kind` in the meta.json — `quota_exhausted` (shared Google "Individual quota", 429, ~2-day reset; agy exits 0 with empty stdout in ~5s and only the `.agy.log` says why) means the lap is benched until the reset, while `empty_output` usually means expired auth (`agy login`). Don't re-auth for a quota problem. No fallback by policy — the lap just drops out of the round.
- **gemini-pro** (Gemini 3.1 Pro, deep lap): Same `agy` binary, just `--model "Gemini 3.1 Pro (High)"` and a longer default timeout (900s). Pro reasons deeper and slower; for tiny diffs the Flash lap alone is often enough. Migrated off the standalone `gemini` CLI in the 2026-06-18 sunset. **Known upstream bug (agy ≤1.0.15):** a SIGSEGV panic in agy's `RunCommandHandler` — exit 2, ~20–45s, empty output, `panic: runtime error` in the `.agy.log`. Hits the Pro lap far more than Flash (Pro roams files/commands harder). Flaky, not deterministic: the wrapper retries agy once, then the lap drops out (no fallback).
- **OpenRouter pool** (glm / deepseek / mimo / minimax / qwen / devstral / laguna / kat / north / nemotron / spark / seed / grok): No CLI — the wrapper `curl`s the OpenRouter chat-completions API with the diff inlined (8000-line cap, `<diff>` fencing and injection defusal identical to kimi). All thirteen require `$OPENROUTER_API_KEY` or `~/.config/openrouter/key`. Each is its own provider vote: Zhipu, DeepSeek, Xiaomi, MiniMax, Alibaba, Mistral, Poolside, Kuaishou, Cohere, NVIDIA, Meta, ByteDance, xAI. Provenance caveats: glm/deepseek/mimo/minimax/qwen/kat are China-origin providers, devstral is France (Mistral), laguna is US (Poolside), north is Canada (Cohere), nemotron is US (NVIDIA), spark is US (Meta), seed is China (ByteDance), grok is US (xAI) — all routed through OpenRouter (US); surface for security-sensitive repos, same as the kimi caveat. `north` and `nemotron` are `:free` OpenRouter routes — zero marginal cost, but free routes can be rate-limited and may have different data-retention terms than paid. (`fugu` / Sakana Fugu Ultra held a trial seat here 2026-07-01→02; cut after 2 samples on cost: $5/M in, $30/M out — ~100× the pool — with hidden orchestration tokens billed as output. See PR notes. `qwen`/`devstral`/`laguna`/`kat` joined 2026-07-02 as rookies to restore lab diversity. `spark` — Meta Muse Spark 1.1 — joined 2026-07-19, per Gabriel. 2026-08-14 refresh: `seed` (ByteDance Seed 2.0 Code) and `grok` (xAI Grok 4.6) joined as `draw_boost` 2.5 rookies — both labs were unrepresented; `deepseek` moved V4 Flash → V4 Pro after the Flash seat scored 52 with 2 disproven findings, `kat` V2 → V2.5, `nemotron` Ultra 550B → 3.5 Lightning. Pre-2026-08-14 leaderboard rows for deepseek and nemotron describe different models.)
- **kimi27** (Kimi k2.7-code, direct Moonshot): No CLI — same curl chat-completions body as the OpenRouter pool, but against `api.moonshot.ai/v1` with the Moonshot platform key (`MOONSHOT_API_KEY` or `~/.config/moonshot/key`; the same account the kimi baseline bills against — watch the shared balance). A deliberate rotation seat (2026-07-03, per Gabriel), NOT an OpenRouter fallback for the kimi baseline; carries `draw_boost: 1.0` in its profile (retired from 2.5 on 2026-07-12 after 10 sampled runs). **Same provider as kimi**: kimi+kimi27 agreement counts as one provider vote at synthesis. China-origin provider (Moonshot) — same caveat as kimi.
- **kimi3** (Kimi K3, direct Moonshot): Same lane as kimi27 — `api.moonshot.ai/v1`, model id `kimi-k3`, same Moonshot platform key and shared balance. Moonshot's flagship (2.8T MoE, 16/896 experts active, 1M context), released 2026-07-16; added as a rotation seat 2026-07-18 per Gabriel, two days later. Full open weights weren't out yet at add-time (expected 2026-07-27) — this seat hits the hosted API, not local weights. Carries `draw_boost: 2.5` in its profile so it's drawn frequently while earning leaderboard data — retire the boost after ~10 sampled runs, same precedent as kimi27. **Same provider as kimi/kimi27**: kimi+kimi27+kimi3 agreement counts as one provider vote at synthesis. China-origin provider (Moonshot) — same caveat as kimi.
- **kimi** (Moonshot's Kimi Code CLI): Uses `kimi --plan --print --quiet` with the review prompt piped via stdin (NOT `-p`). `--plan` is read-only; `--print` is non-interactive; `--quiet` trims to just the final assistant message. Prompt goes on stdin because argv has a 128KB-per-argument limit on Linux (`MAX_ARG_STRLEN`) and argv-based prompts also leak the diff via `ps` to other local users. Default model is `kimi-k2.5` (256K ctx, thinking mode on) — configured in `~/.kimi/config.toml`. Auth is either the Moonshot platform API key (`openai_legacy` provider against `api.moonshot.ai/v1`) or the native Kimi Coding subscription (`kimi login` OAuth). Note: kimi sends code to a China-origin provider — surface that to the user for security-sensitive repos.

More detail on flags and gotchas lives in [references/cli_flags.md](references/cli_flags.md). Read it if a reviewer is behaving unexpectedly.

## Integration with /pr

If the user's PR workflow invokes a `/pr` skill, this skill should run as a late step in that flow — after the PR is opened, before merge. The `/pr` skill can call cross-review and wait for it to return clean before proceeding to squash merge.

This is not auto-invoked by the harness. To make it fire automatically after every `gh pr create`, a settings.json hook would need to be added via the `update-config` skill.

## Common failure modes

- **"No diff to review"**: branch has no commits past the base. Check `git log base..HEAD` — likely on the wrong branch.
- **Gemini laps both empty in ~5s**: the shared Google "Individual quota" is exhausted (429). The wrapper stamps `failure_kind: "quota_exhausted"` + the reset ETA in meta.json and writes an `agy.quota_exhausted` sentinel that spares retries and the factcheck pass (the concurrent sibling lap usually burns its own ~5s call first — 2s stagger vs ~5s detection). Both laps drop out until the quota resets (~2-day cadence) — no fallback by policy; report that honestly rather than re-running, and let rotation fill the roster. Do NOT `agy login` for this — it's not an auth problem. (The selector also down-weights a lap whose latest run was a quota failure.)
- **gemini-pro exits 2 in ~30s with empty output**: agy's SIGSEGV panic (upstream bug, `panic: runtime error` in the `.agy.log`). The wrapper retries agy once, then the lap drops out. If it recurs across runs, check for a newer agy release.
- **`agy models` hangs for minutes**: agy ignores SIGTERM while stuck in its quota-retry network loop. `select_roster.sh` guards this with a 6h-TTL cache + `timeout -k 5 15` hard-kill; if you probe agy manually, use the same.
- **Reviewer hangs**: any CLI can hang on auth or on first-run config prompts. The wrapper has a per-reviewer timeout (antigravity/kimi/OpenRouter-pool 600s, codex/gemini-pro 900s by default — see `references/reviewer_profiles.json`; codex ran on 300s until 2026-08-14, when an 18-file diff consumed the whole budget in repo exploration and returned no review); if it fires, surface stderr so the user can re-auth. For the two `agy` reviewers, a hang is most often the shared `agy` auth — `agy login` once fixes both. Timeouts are not retried (a reviewer that used its budget will use it again on retry — that's a tuning signal, not a transient failure). If the same reviewer keeps timing out, the analyzer's `--mode warn` will surface a suggested bump on the next run.
- **Durations far past the budget with `status: ok` (or a whole round of timeouts at once)**: the machine slept mid-round. gtimeout/curl timers freeze during system sleep while wall-clock `date +%s` keeps counting — enforcement is intact (verify with `pmset -g log | grep -E "Sleep|Wake"`); observed 2026-07-03 when codex logged 1024s against a 300s budget with rc=0 during Dark Wake thermal churn. meta.json stamps `wall_over_budget: true` on such samples; `analyze_runlog.sh` reports them as `sleep_suspect` and keeps them out of tuning suggestions, and `leaderboard.sh` drops sleep-killed timeouts from reliability. Do NOT bump timeouts, cut reviewers, or trust a same-day degradation cluster on such rounds — re-evaluate on clean data.
- **kimi exits 127 in 0s ("timeout: failed to run command 'kimi': No such file or directory") while `command -v kimi` finds it**: the kimi-cli uv-tool venv's python interpreter is dead — a Homebrew python upgrade emptied the keg its symlink chain points at (`~/.local/bin/kimi` → uv venv shebang → `/opt/homebrew/opt/python@3.13/bin/python3.13`). PATH lookup succeeds (the symlink exists); exec fails with ENOENT (the interpreter doesn't). Repair: `uv tool install --reinstall --python <current> kimi-cli`. Caught 2026-07-03 after kimi logged failed=6 of 10 runs; diagnose with `head -1 $(command -v kimi)` and follow the chain before blaming PATH or the provider.
- **A diff-only reviewer reports a bug that turns out to be a pre-fix bug DESCRIBED in an in-diff investigation/postmortem doc, not a live defect**: devstral replayed 9 of 12 findings, and deepseek 4 of 5, straight from an investigation doc's prose on PR #350 (2026-07-05) — codex and kimi (file-reading tools) weren't fooled since they could check whether the described bug was actually still present. The wrapper now auto-injects a caution into the prompt for every text-only reviewer (kimi + the OpenRouter pool, incl. kimi27 and kimi3) whenever the diff touches a `.md`/`.mdx`/`.rst`/`.adoc` file (`doc_narrative_risk`/`doc_narrative_note` in `run_reviewers.sh`) — but a determined reviewer can still ignore it. Verify any finding sourced from a doc-heavy diff against the actual code hunks before trusting it.
- **Reviewer flags a tokens-vs-hardcoded issue that's actually fine**: Vibrant Punk / NativeWind contexts use tokens that look like hex to the reviewer. Check `constants/theme.ts` before "fixing" a perceived hardcoded color.
- **Same finding keeps coming back**: either the fix is wrong, or the reviewer has a stale mental model (e.g., you moved logic to another file and it still complains about the old location). Don't loop — stop and investigate.
- **Iteration 3 still dirty**: structural issue. Don't push through — ask the user whether to merge with known findings or take a different approach.

## Leaderboard & rotation

Two scripts turn the runlog into a self-tuning roster:

**`leaderboard.sh`** scores every reviewer from the last 40 structured runlog entries:

```bash
bash ~/.claude/skills/cross-review/scripts/leaderboard.sh              # human table
bash ~/.claude/skills/cross-review/scripts/leaderboard.sh --mode json  # for the selector
```

`score = 45% reliability + 35% finding value + 20% fact-check survival`. The finding-value and survival axes have two bases: for runlog entries that carry a `run_id` joinable to `finding_events.jsonl`, the score is computed **per-finding** — severity-weighted (Critical 5 / High 3 / Medium 2 / Low 1) with unique-discovery credit (provider-solo 1.0 > multi-provider-without-a-baseline 0.85 > baseline-corroborated 0.7; anchored `resolved=false` halves credit; `factcheck_dropped` zeroes it and drives survival). This is the fix for the old convergence-popularity loop: a solo-but-real Critical now outscores a pile of corroborated Lows. Reviewers with no window events fall back to the aggregate-count formula (`35% convergent/findings + 20% (1-dropped/findings)`), where the old caveat still applies: convergence rewards agreeing with the crowd, so read a low-signal reviewer's actual findings before cutting it. Each JSON row carries `score_basis` (`events`/`counts`/`telemetry`/`rookie`) so you can see which formula produced it. One events-path trade-off to watch: solo findings fact-check can't actively disprove keep full solo credit — eyeball `ev_solo` vs `ev_dropped` before trusting a solo-heavy score. Reviewers with telemetry but no findings data score `reliability × 0.75` (decaying — see the kat pin in `leaderboard.sh`); never-run reviewers get a rookie prior of 50 (optimistic initialization, so new models get drawn and earn real data). The count/event signals come from `append_runlog.sh --findings` + `--run-id` and the `--emit-events` flags in steps 6.5–7 — which is why step 9.5 says to always pass them.

**`select_roster.sh`** draws each round's roster:

```bash
bash ~/.claude/skills/cross-review/scripts/select_roster.sh            # → "codex,kimi,<pick>,<pick>"
bash ~/.claude/skills/cross-review/scripts/select_roster.sh --extras 3 --json  # more picks + decision record
```

codex + kimi are fixed baselines; `--extras` (default 2) rotation picks are drawn without replacement, weighted by `max(score, 15) × (1 + 0.5/√(attempts+1)) / (1 + p50/240) / (1 + avg_cost/$0.50) × draw_boost` (per-reviewer `draw_boost` from `reviewer_profiles.json`, default 1 — a manual seat-priority knob that shapes the DRAW only, never synthesis weighting; kimi27 rides 2.5 while it earns leaderboard data) — exploit the leaderboard, explore the under-sampled, prefer the fast and the cheap, never starve anyone. The cost divisor is the fugu lesson made structural: OR calls carry `usage: {include: true}`, per-call `cost_usd` lands in meta → runlog → leaderboard (`avg_cost_usd`), and a $0.50-per-run reviewer draws at half weight while first-party/free lanes divide by 1. A future 100×-priced model gets sampled occasionally but can never dominate the roster or the bill. **Latency, cost, and draw_boost only shape the draw** — at synthesis time a slow reviewer's findings weigh exactly the same. A reviewer whose latest run was a quota failure gets its weight ×0.1 (benched but occasionally probed so recovery is noticed). `--fast` drops candidates with recent p50 > 180s entirely (rookies pass) — use it for re-passes and quick loops. The roster is always ≥3; a missing baseline raises the draw count. `run_reviewers.sh` calls this automatically when `--reviewers` is omitted.

**Reading the leaderboard over time:** rookies enter at 50 and converge to their real score within ~10 sampled runs. Promote a consistently top-scoring rotation member to more frequent duty by raising its `synthesis_weight`/priors in `reviewer_profiles.json`; cut a consistent bottom-dweller by removing it from the pool in `select_roster.sh` and `run_reviewers.sh`.

## Self-check mode

When invoked as `/cross-review --self-check`, skip the review pipeline and emit a health snapshot of the reviewer fleet, plus the current leaderboard:

```bash
bash ~/.claude/skills/cross-review/scripts/analyze_runlog.sh --recent 20 --mode report
bash ~/.claude/skills/cross-review/scripts/leaderboard.sh
```

The report shows per-reviewer reliability %, ok/timeout/empty/failed counts, p50/p95 duration, current timeout budget, and a list of suggested edits to `references/reviewer_profiles.json` (e.g. "bump gemini-pro.timeout_s from 900 → 1100 because timeout rate 25% over window"). Suggestions never apply themselves — the user (or Claude) edits the profile file with eyes on, the same way splitstream's pre-flight table needs explicit approval.

Use it: weekly, after a noticeably degraded round, before changing reviewer profiles, or when investigating "why did cross-review miss X?"

## Importing / consolidating runlogs

The runlog lives at `$skill_dir/runlog.jsonl` — a path relative to wherever the skill is installed. So the repo copy, the `~/.claude/skills` install, and the plugin cache each keep their **own** history, and a reinstall or sync starts from an empty log. To fold an old or sibling runlog into the current one without losing telemetry:

```bash
bash ~/.claude/skills/cross-review/scripts/import_runlog.sh \
  --from <old-runlog.jsonl | dir-containing-one> \
  [--from <another> ...] \
  [--into <dest runlog.jsonl>]   # defaults to this skill's runlog
  [--dry-run]
```

The merge is **idempotent** (exact-object dedup — re-importing the same source adds nothing), JSON-validated (non-JSON lines are counted and skipped, not written), chronologically sorted by `ts` (legacy entries without `ts` sort to the front), and written atomically under `flock`. Always safe to run before `--self-check` after a reinstall: `import_runlog.sh --from ~/.claude/skills/cross-review/runlog.jsonl --dry-run` shows what would be pulled in. This is the supported way to preserve history when syncing the skill between the repo and an install.

## Per-reviewer behavioral profiles

`references/reviewer_profiles.json` is the canonical source for per-reviewer config: timeout, retry policy, severity priors, synthesis weight, specialization. Three places read it:

- The wrapper (`run_reviewers.sh`) sources `timeout_s` and `retry_policy` from it. CLI flags override.
- The synthesis step (4) consults `severity_priors` and `synthesis_weight` when ranking findings. See "Apply per-reviewer priors..." in step 4.
- The analyzer (`analyze_runlog.sh`) reads the current `timeout_s` to suggest tuning bumps.

When tuning a reviewer's behavior — e.g. "kimi nits are wasting time, downweight them" — edit `reviewer_profiles.json`, not the wrapper or SKILL.md prose. Centralizing the config keeps the self-improvement loop honest: the analyzer's suggestions land in the same file humans edit by hand.

## Tests

`tests/run_tests.sh` is an offline fixture suite — no network, no reviewer CLIs (PATH shims), no tokens. It pins every behavior a real review round flagged on PR #18: leaderboard scoring branches, runlog status classification (`skipped`/`quota`) and findings enrichment, seeded selector determinism + the `--fast` floor fallback, kimi budget scaling + explicit-cap precedence, rc-137 timeout semantics, anchor resolution, and import idempotency. **Run it before editing any script**; in the skills repo, CI runs it on every PR plus a dual-copy identity check (root `cross-review/` must stay byte-identical to `plugins/cross-review/skills/cross-review/`).

## What this skill does not do

- It does not run lint/type/test suites as the reviewer. Those are Claude's own pre-PR checks — this skill layers on top.
- It does not replace human review. The goal is to raise the floor, not to auto-merge.
- It does not invent findings. If reviewers have nothing to say, report that honestly and stop.
