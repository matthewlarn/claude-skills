#!/usr/bin/env bash
# post_comment.sh — post the synthesized findings to a PR, or save locally.
#
# Usage:
#   post_comment.sh --pr <n> --mode <summary|file|none> --findings <path> [--pass <n>]
#                   [--head-sha <sha>]
#
# --head-sha stamps the record with the commit that was actually reviewed, and
# compares it against the PR's live head at post time. Without it a review
# comment reads as authoritative about whatever the PR contains *now*, which is
# how a confirmed finding got silently discarded: on kindred-mama-ai#3207 the
# head moved four times in one session, one push reverted a two-provider P1 fix
# and deleted its regression test, and the posted record never said which
# commit it covered. The same PR was merged 19 minutes BEFORE its review
# posted, so this also flags an already-merged PR.
#
# - summary:  one consolidated `gh pr comment` on the PR conversation
# - file:     write only; no GitHub call (findings already on disk at --findings path)
# - none:     no-op
#
# If no PR number is given or `gh` can't reach it, falls back to `file` mode.

set -uo pipefail

pr=""
repo=""
mode="summary"
findings=""
pass="1"
head_sha=""

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
    --pr)       need_val --pr       "$#"; pr="$2";       shift 2 ;;
    --repo)     need_val --repo     "$#"; repo="$2";     shift 2 ;;
    --mode)     need_val --mode     "$#"; mode="$2";     shift 2 ;;
    --findings) need_val --findings "$#"; findings="$2"; shift 2 ;;
    --pass)     need_val --pass     "$#"; pass="$2";     shift 2 ;;
    --head-sha) need_val --head-sha "$#"; head_sha="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$findings" ]]; then
  echo "usage: $0 --pr <n> --mode <summary|file|none> --findings <path> [--pass <n>] [--head-sha <sha>] [--repo owner/name]" >&2
  exit 2
fi

if [[ ! -f "$findings" ]]; then
  echo "findings file not found: $findings" >&2
  exit 2
fi

# Every terminal path below records what happened to the record, in the run dir
# next to findings.md. Absence of posted.json then means something specific and
# useful: the run never reached post_comment.sh at all. That is the exact state
# six kindred-mama-ai PRs were in on 2026-08-11 (#3214, #3252, #3264, #3269,
# #3276, #3280) — real reviewer output on disk, nothing on GitHub, and no way to
# tell them apart from PRs nobody reviewed. A reconciliation pass needs "meant
# to post and didn't" to be distinguishable from "deliberately file-only", so
# the reason is recorded rather than inferred.
#
# Fails open: an unwritable run dir must never cost the user a posted review.
run_dir="$(dirname "$findings")"
jsonesc() { printf '%s' "${1:-}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\000-\037'; }
# Without --repo, `gh pr view 3280` resolves the number against whatever
# repository the CALLER happens to be standing in. reconcile.sh scans a runs
# root spanning many repos, so a reconciled post could land on a same-numbered
# PR in the wrong project entirely. (codex P1, PR #53.)
gh_repo=()
[[ -n "$repo" ]] && gh_repo=(--repo "$repo")

write_posted() {  # <true|false> <reason> [comment_url]
  if [[ ! -d "$run_dir" || ! -w "$run_dir" ]]; then
    # Say so. A silently absent marker is indistinguishable from "never tried
    # to post", which is exactly what reconcile.sh reads as droppable — so an
    # unwritable run dir could make it re-post a comment that already exists.
    # (qwen M, codex P2, PR #53.)
    echo "WARN: cannot write $run_dir/posted.json — this run's posting outcome will not be recorded" >&2
    return 0
  fi
  printf '{"posted": %s, "reason": "%s", "pr": "%s", "repo": "%s", "pass": "%s", "head_sha": "%s", "mode": "%s", "comment_url": "%s", "posted_at": "%s"}\n' \
    "$1" "$(jsonesc "$2")" "$(jsonesc "$pr")" "$(jsonesc "$repo")" "$(jsonesc "$pass")" "$(jsonesc "$head_sha")" \
    "$(jsonesc "$mode")" "$(jsonesc "${3:-}")" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    >"$run_dir/posted.json" 2>/dev/null || true
}

if [[ "$mode" == "none" ]]; then
  write_posted false "mode-none"
  exit 0
fi

# Fall back to file mode when there's no PR or no gh auth.
# Remember WHY: a review that was meant to post and couldn't is a different
# thing from one the caller asked to keep local, and only the first is worth
# reconciling later.
file_reason="file-mode"
if [[ "$mode" == "summary" ]]; then
  if [[ -z "$pr" ]] || ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
    echo "gh unavailable or no PR number — falling back to file mode" >&2
    mode="file"
    file_reason="gh-unavailable-or-no-pr"
  fi
fi

# --head-sha is REQUIRED to post. It used to be optional, which meant the
# stamp was optional, which meant it was not a stamp: half the sampled review
# comments on 2026-08-14 carried no sha at all, and a review record that cannot
# say which commit it covered is indistinguishable from no review. Refusing to
# post is the right failure — the findings are still on disk at $findings, and
# the caller re-runs with the sha rather than leaving an unverifiable record on
# a PR someone will merge past.
#
# Scoped to `summary`. `file` and `none` modes write nothing to GitHub, so they
# create no unstampable record and keep working exactly as before.
if [[ "$mode" == "summary" && -z "$head_sha" ]]; then
  write_posted false "no-head-sha"
  echo "ERROR: --head-sha is required to post a review comment." >&2
  echo "  A record with no commit stamp cannot be verified by scripts/cross-review-currency.sh," >&2
  echo "  and reads as authoritative about whatever the PR contains later." >&2
  echo "  Re-run with: --head-sha \"\$(git rev-parse HEAD)\"" >&2
  echo "  Findings preserved at: $findings" >&2
  exit 2
fi

# The marker contract is a full 40-char sha. Callers that pass an abbreviation
# are not wrong — the prose stamp has always accepted one, and the gate still
# does — so expand it when git can, and degrade to prose-only rather than
# refusing to post. Backward compatibility matters here: this script is shared
# by concurrent sessions and an abbreviated sha must not start failing runs.
if [[ -n "$head_sha" && ! "$head_sha" =~ ^[0-9a-f]{40}$ ]]; then
  expanded="$(git rev-parse "$head_sha" 2>/dev/null || true)"
  if [[ "$expanded" =~ ^[0-9a-f]{40}$ ]]; then
    head_sha="$expanded"
  else
    echo "WARN: --head-sha '$head_sha' is not a full 40-char sha and could not be expanded — posting with the prose stamp only" >&2
  fi
fi

case "$mode" in
  summary)
    # Template + rc check (issue #7 nit): BSD/GNU mktemp default templates
    # differ, and an unchecked failure would send an empty --body-file.
    body_file="$(mktemp -t cr-comment.XXXXXX)" || { echo "mktemp failed" >&2; exit 1; }
    # Ensure the body file is always cleaned up, even if gh call fails or the
    # script is interrupted. Previous version only rm'd on the happy path.
    trap 'rm -f "$body_file"' EXIT
    # Derive the roster from the run dir's meta files — under rotation the
    # fleet varies per round, so a hardcoded list is frequently wrong (fugu
    # finding, PR #18 pass 1). findings.md lives at $run_dir/findings.md and
    # the wrapper writes $run_dir/raw/<reviewer>.meta.json per reviewer ran.
    roster_line=""
    raw_dir="$(dirname "$findings")/raw"
    if [[ -d "$raw_dir" ]]; then
      for m in "$raw_dir"/*.meta.json; do
        [[ -f "$m" ]] || continue
        n="$(basename "$m" .meta.json)"
        [[ "$n" == *.agy-failed ]] && continue
        # Same exclusion merge_raw_findings.sh makes, for the same reason: a
        # retried agy lap leaves <slug>.attempt<N>.meta.json beside <slug>'s as
        # forensic evidence, and counting both inflates the roster with a
        # reviewer that never existed. PR #41 fixed this in the findings
        # merger; the roster line kept the bug and credited PR #50's review to
        # "antigravity.attempt1 + antigravity + codex + glm + kimi" — five
        # names for four reviewers.
        [[ "$n" == *.attempt[0-9]* ]] && continue
        roster_line="${roster_line:+$roster_line + }$n"
      done
    fi
    [[ -z "$roster_line" ]] && roster_line="external reviewers"

    # Provenance + staleness. A review record is read long after it is posted,
    # so it must say what it covered. Every query below fails OPEN: if `gh` or
    # `jq` is unavailable the comment still posts, just without the banner.
    provenance=""
    [[ -n "$head_sha" ]] && provenance="Reviewed \`${head_sha:0:9}\`."

    # THE MACHINE-WRITTEN STAMP.
    #
    # The provenance line above is for people, and for a while it was also the
    # only thing scripts/cross-review-currency.sh could read. Prose drifts: on
    # 2026-08-14 four open PRs (#3376, #3374, #3371, #3362) carried "Reviewed
    # at `<sha>`" — composed by a model rather than by this script — and the
    # gate rejected all four over the word "at", while each one was reviewed at
    # its exact current head. Four more (#3369, #3367, #3363, #3073) carried no
    # sha at all.
    #
    # So the record now also carries a marker no one writes by hand. One line,
    # full 40-char sha, invisible in rendered markdown. The gate reads this
    # first and falls back to the prose only for comments posted before it
    # existed. Keep the shape byte-stable: CR_MARKER_RE in
    # scripts/cross-review-currency.sh matches it literally.
    # Only a full-width sha earns a marker; an unexpandable abbreviation was
    # warned about above and rides on the prose stamp, which the gate still
    # accepts. Emitting a short sha here would produce a marker the gate's
    # regex rejects, which is worse than not emitting one.
    marker=""
    [[ "$head_sha" =~ ^[0-9a-f]{40}$ ]] && marker="<!-- cross-review: sha=${head_sha} pass=${pass} -->"
    staleness=""
    if command -v jq >/dev/null 2>&1; then
      pr_meta="$(gh pr view "$pr" ${gh_repo[@]+"${gh_repo[@]}"} --json headRefOid,state 2>/dev/null || true)"
      if [[ -n "$pr_meta" ]]; then
        cur_sha="$(printf '%s' "$pr_meta" | jq -r '.headRefOid // ""' 2>/dev/null || true)"
        pr_state="$(printf '%s' "$pr_meta" | jq -r '.state // ""' 2>/dev/null || true)"
        if [[ "$pr_state" == "MERGED" ]]; then
          staleness+="> [!WARNING]"$'\n'"> **This PR was already merged before the review finished.** Any finding below is describing code that is already on the base branch — it needs a follow-up PR, not a change here."$'\n\n'
        elif [[ "$pr_state" == "CLOSED" ]]; then
          staleness+="> [!WARNING]"$'\n'"> **This PR was closed before the review finished.**"$'\n\n'
        fi
        if [[ -n "$head_sha" && -n "$cur_sha" && "$cur_sha" != "$head_sha" ]]; then
          staleness+="> [!WARNING]"$'\n'"> **Stale: the head moved during this review.** Reviewed \`${head_sha:0:9}\`, current head is \`${cur_sha:0:9}\`. Findings below may describe code that no longer exists, and fixes confirmed here may have been overwritten. Re-review before trusting this record."$'\n\n'
        fi
      fi
    fi

    {
      printf '## Cross-review — pass %s\n\n' "$pass"
      [[ -n "$marker" ]] && printf '%s\n\n' "$marker"
      [[ -n "$staleness" ]] && printf '%s' "$staleness"
      printf '_Automated review by %s.%s See the "Findings" collapsible for specifics._\n\n' "$roster_line" "${provenance:+ $provenance}"
      printf '<details><summary>Findings</summary>\n\n'
      cat "$findings"
      printf '\n</details>\n'
    } >"$body_file"
    # If `gh pr comment` itself fails (network blip, rate limit, PR closed
    # mid-run, transient GitHub outage), degrade gracefully to file mode
    # rather than failing the whole review run. The findings.md is already
    # on disk at $findings — the user still has the record.
    # Capture the URL gh prints so posted.json can point at the actual comment;
    # stderr still passes through untouched, and the URL is re-echoed so the
    # caller sees exactly what it saw before.
    comment_url="$(gh pr comment "$pr" ${gh_repo[@]+"${gh_repo[@]}"} --body-file "$body_file")"
    rc=$?
    [[ -n "$comment_url" ]] && printf '%s\n' "$comment_url"
    if [[ "$rc" -eq 0 ]]; then
      # gh prints the comment URL on success. Record it only if it looks like
      # one — a garbled value sends anyone reading posted.json to a link that
      # isn't there. Deliberately NOT a downgrade to posted=false: the comment
      # did post, and calling that a failure would make reconcile.sh post it a
      # second time. A missing URL costs a click; a duplicate review comment
      # costs trust in the record. (kimi, PR #53 — accepted in weaker form.)
      [[ "$comment_url" =~ ^https://[^[:space:]]+$ ]] || comment_url=""
      write_posted true "posted" "$comment_url"
      exit 0   # posted OK
    else
      # Non-zero exit (issue #7 nit): a silent 0 here masked real auth/rate
      # problems. The findings file is the fallback record either way.
      write_posted false "gh-comment-failed"
      echo "ACTION REQUIRED: gh pr comment failed (auth? rate limit? closed PR?) — findings preserved at: $findings" >&2
      exit 1
    fi
    ;;
  inline)
    # Removed in favor of summary: 5–10× API calls for little extra signal.
    # If reintroduced, post via `gh api repos/{owner}/{repo}/pulls/{pr}/comments`
    # per finding, keyed off <!-- file:... line:... --> sentinels in findings.md.
    echo "'inline' mode was removed — use 'summary' instead. File:line refs already live in the summary body." >&2
    exit 2
    ;;
  file)
    # Findings file already exists at $findings — nothing to do.
    write_posted false "$file_reason"
    echo "findings saved to: $findings" >&2
    exit 0
    ;;
  *)
    echo "unknown mode: $mode" >&2
    exit 2
    ;;
esac