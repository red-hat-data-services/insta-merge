#!/usr/bin/env bash

try_merge_pr() {
  local pr_url="$1"
  local merge_output merge_status failure_status pr_details pr_state mergeable

  if merge_output=$(gh pr merge --merge --admin "$pr_url"); then
    [[ -z "$merge_output" ]] || printf '%s\n' "$merge_output"
    echo "Merged the PR!!"
    return 0
  else
    merge_status=$?
    failure_status=$merge_status
    if [[ "$failure_status" -eq 2 ]]; then
      # Status 2 is reserved for the confirmed-conflict fallback below.
      failure_status=1
    fi
    [[ -z "$merge_output" ]] || printf '%s\n' "$merge_output"
  fi

  echo "::warning::gh pr merge failed with exit status ${merge_status}; checking the PR state." >&2
  if ! pr_details=$(gh pr view "$pr_url" --json state,mergeable --jq '[.state, .mergeable] | @tsv'); then
    echo "::error::Could not verify the PR state after gh pr merge failed." >&2
    return "$failure_status"
  fi

  IFS=$'\t' read -r pr_state mergeable <<< "$pr_details"
  if [[ "$pr_state" == "MERGED" ]]; then
    echo "Merged the PR!!"
    return 0
  fi

  if [[ "$pr_state" == "OPEN" && "$mergeable" == "CONFLICTING" ]]; then
    echo "PR has merge conflicts; continuing with configured conflict-resolution fallback."
    return 2
  fi

  echo "::error::gh pr merge failed with exit status ${merge_status}; PR state=${pr_state}, mergeable=${mergeable}." >&2
  return "$failure_status"
}
