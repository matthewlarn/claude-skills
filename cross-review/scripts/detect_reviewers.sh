#!/usr/bin/env bash
# detect_reviewers.sh — report which review CLIs are available.
# Prints JSON to stdout:
#   {"codex": bool, "antigravity": bool, "gemini-pro": bool, "kimi": bool,
#    "glm": bool, "deepseek": bool, "mimo": bool, "minimax": bool, "qwen": bool,
#    "devstral": bool, "laguna": bool, "kat": bool,
#    "north": bool, "nemotron": bool, "spark": bool,
#    "seed": bool, "grok": bool, "kimi27": bool,
#    "kimi3": bool, "openrouter": bool}
#
# As of the 2026-06-18 Gemini-CLI consumer sunset, BOTH Gemini-family reviewers
# run on Google's `agy` (Antigravity) CLI:
#   - antigravity → agy --model "Gemini 3.5 Flash (High)"   (fast lap)
#   - gemini-pro  → agy --model "Gemini 3.1 Pro (High)"     (deep lap)
# So their availability both track the single `agy` binary. The standalone
# `gemini` CLI is no longer used (it stopped serving consumer requests on
# 2026-06-18). codex and kimi are unchanged.
#
# The OpenRouter pool (glm, deepseek, mimo, minimax, qwen, devstral, laguna,
# kat, north, nemotron, spark, seed, grok)
# runs via the OpenRouter API — no CLI; all thirteen track the same condition:
# an OpenRouter key ($OPENROUTER_API_KEY or ~/.config/openrouter/key) + curl.
# `openrouter` reports that shared condition. NOTE: there is NO OpenRouter
# fallback for the first-party reviewers (policy, 2026-07-01) — a failed agy
# lap drops out of the round and roster rotation covers the gap.

set -euo pipefail

# Same PATH guard as run_reviewers.sh / select_roster.sh: without it, `has agy`
# succeeds via the direct ~/.local/bin fallback below but the bare `agy models`
# probe fails (127) and gemini-pro false-negatives — detection disagreeing with
# execution. codex+fugu convergent finding, PR #18 pass 1.
if [[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  PATH="$HOME/.local/bin:$PATH"
fi

# Same class of bug, second location. codex and kimi are npm-global CLIs, and
# nvm installs those under $NVM_DIR/versions/node/<version>/bin — a directory
# that is NOT on $PATH for non-interactive shells, because nvm is a shell
# function sourced from .zshrc and it never runs here. This bit us for real:
# `codex` fell off $PATH and NINE consecutive review rounds ran without their
# fixed baseline while reporting healthy (2026-08-14, kindred-mama-ai).
nvm_bin=""
_nvm_root="${NVM_DIR:-$HOME/.nvm}"
if [[ -d "$_nvm_root/versions/node" ]]; then
  # alias/default may hold a bare major ("22") or a full version ("v22.22.2").
  _nvm_default="$(cat "$_nvm_root/alias/default" 2>/dev/null || true)"
  if [[ -n "$_nvm_default" ]]; then
    for _d in "$_nvm_root/versions/node/${_nvm_default}/bin" \
              "$_nvm_root/versions/node/v${_nvm_default}".*/bin; do
      if [[ -d "$_d" ]]; then nvm_bin="$_d"; break; fi
    done
  fi
  if [[ -z "$nvm_bin" ]]; then
    # No usable default alias — fall back to the highest installed version.
    _d="$(ls -d "$_nvm_root"/versions/node/*/bin 2>/dev/null | sort -V | tail -1 || true)"
    if [[ -n "$_d" ]]; then nvm_bin="$_d"; fi
  fi
fi
if [[ -n "$nvm_bin" && ":$PATH:" != *":$nvm_bin:"* ]]; then
  PATH="$nvm_bin:$PATH"
fi

has() {
  command -v "$1" >/dev/null 2>&1 && return 0
  # Antigravity's installer drops `agy` in $HOME/.local/bin, which is often not
  # on $PATH for non-interactive shells. Fall back to a direct check so we don't
  # false-negative when the user installed via the official script and just
  # hasn't restarted their shell.
  [[ -x "$HOME/.local/bin/$1" ]] && return 0
  # Same fallback for nvm-installed npm globals (codex, kimi).
  [[ -n "$nvm_bin" && -x "$nvm_bin/$1" ]]
}

codex=false
antigravity=false
gemini_pro=false
kimi=false
openrouter=false
kimi27=false
kimi3=false

has codex && codex=true
# Both Gemini reviewers ride the same agy binary — but `agy --model` silently
# falls back to Flash on an unrecognized model string. So only report gemini-pro
# (the Pro lap) available if `agy models` actually lists a Gemini 3.1 Pro entry.
# The probe MUST be bounded and cached: an unhealthy agy (quota/auth) can hang
# `agy models` for minutes and it ignores SIGTERM (codex P2, PR #18 pass 2).
# Shares select_roster.sh's 6h cache; with no timeout binary available the
# probe is skipped and Pro is assumed available (matches execution — the
# wrapper pins the exact model string either way).
if has agy; then
  antigravity=true
  models_cache="$HOME/.cross-review/cache/agy_models.txt"
  if [[ ! -s "$models_cache" || -n "$(find "$models_cache" -mmin +360 2>/dev/null)" ]]; then
    TIMEOUT_BIN=""
    command -v timeout  >/dev/null 2>&1 && TIMEOUT_BIN="timeout"
    if [[ -z "$TIMEOUT_BIN" ]] && command -v gtimeout >/dev/null 2>&1; then TIMEOUT_BIN="gtimeout"; fi
    if [[ -z "$TIMEOUT_BIN" ]]; then
      for _tb in /opt/homebrew/bin/gtimeout /usr/local/bin/gtimeout; do
        if [[ -x "$_tb" ]]; then TIMEOUT_BIN="$_tb"; break; fi
      done
    fi
    if [[ -n "$TIMEOUT_BIN" ]]; then
      mkdir -p "$(dirname "$models_cache")"
      models_tmp="$models_cache.tmp.$$"
      if "$TIMEOUT_BIN" -k 5 15 agy models >"$models_tmp" 2>/dev/null; then
        mv "$models_tmp" "$models_cache"
      else
        rm -f "$models_tmp"
      fi
    fi
  fi
  if [[ -s "$models_cache" ]]; then
    # agy 1.1.10 changed `agy models` output from display names
    # ("Gemini 3.1 Pro (High)") to slugs ("gemini-3.1-pro-high"), which
    # false-negatived gemini-pro out of every roster. Match either shape.
    if grep -Eqi 'gemini[ ._-]?3\.1[ ._-]?pro' "$models_cache"; then gemini_pro=true; fi
  else
    gemini_pro=true
  fi
fi
has kimi && kimi=true

# OpenRouter key + curl → the whole OpenRouter reviewer pool lights up.
if command -v curl >/dev/null 2>&1; then
  if [[ -n "${OPENROUTER_API_KEY:-}" || -s "$HOME/.config/openrouter/key" ]]; then
    openrouter=true
  fi
  # kimi27 (k2.7-code rotation seat) rides the DIRECT Moonshot API — its own
  # key, independent of both the kimi CLI baseline and the OpenRouter pool.
  if [[ -n "${MOONSHOT_API_KEY:-}" || -s "$HOME/.config/moonshot/key" ]]; then
    kimi27=true
    # kimi3 (K3 rotation seat, added 2026-07-18) shares the exact same
    # direct-Moonshot key — same billing rail as kimi27 and the kimi baseline.
    kimi3=true
  fi
fi

# WARNING: the format-string keys and the positional args below are coupled
# by POSITION ONLY — inserting a reviewer in one without the other silently
# shifts every later value (kimi+kat convergent nit, PR #29 pass 1). Keep the
# order: 4 named CLIs, 13x $openrouter for the OR pool, $kimi27, $kimi3, $openrouter.
printf '{"codex": %s, "antigravity": %s, "gemini-pro": %s, "kimi": %s, "glm": %s, "deepseek": %s, "mimo": %s, "minimax": %s, "qwen": %s, "devstral": %s, "laguna": %s, "kat": %s, "north": %s, "nemotron": %s, "spark": %s, "seed": %s, "grok": %s, "kimi27": %s, "kimi3": %s, "openrouter": %s}\n' \
  "$codex" "$antigravity" "$gemini_pro" "$kimi" \
  "$openrouter" "$openrouter" "$openrouter" "$openrouter" "$openrouter" "$openrouter" "$openrouter" "$openrouter" "$openrouter" "$openrouter" "$openrouter" "$openrouter" "$openrouter" \
  "$kimi27" "$kimi3" "$openrouter"

# --- baseline enforcement ---------------------------------------------------
# codex and kimi are FIXED BASELINES, not rotating reviewers: every round is
# supposed to include both. Before 2026-08-14 a missing baseline simply reported
# `false` and the round proceeded a reviewer short while looking healthy — a
# missing verifier was indistinguishable from a passing verification. Nine
# rounds ran that way before anyone noticed.  Baselines now fail CLOSED.
#
# The JSON above is still printed first, so a caller that captures stdout gets
# its data either way; the EXIT CODE is the binding signal.
#
# Deliberately degraded runs are still allowed, but they have to be explicit:
#   CROSS_REVIEW_ALLOW_MISSING_BASELINE=1
# which makes it a visible choice at the call site instead of a silent default.
missing_baselines=""
[[ "$codex" == true ]] || missing_baselines="$missing_baselines codex"
[[ "$kimi"  == true ]] || missing_baselines="$missing_baselines kimi"
missing_baselines="${missing_baselines# }"

if [[ -n "$missing_baselines" ]]; then
  if [[ "${CROSS_REVIEW_ALLOW_MISSING_BASELINE:-0}" == "1" ]]; then
    printf 'WARNING: baseline reviewer(s) unavailable: %s — proceeding because CROSS_REVIEW_ALLOW_MISSING_BASELINE=1\n' \
      "$missing_baselines" >&2
  else
    printf 'FATAL: baseline reviewer(s) unavailable: %s\n' "$missing_baselines" >&2
    printf '  These are fixed baselines. A round without them is not a cross-review.\n' >&2
    printf '  Searched $PATH plus %s and %s\n' \
      "$HOME/.local/bin" "${nvm_bin:-<no nvm bin found>}" >&2
    printf '  Fix the install or PATH, or set CROSS_REVIEW_ALLOW_MISSING_BASELINE=1\n' >&2
    printf '  to run degraded on purpose.\n' >&2
    exit 1
  fi
fi
