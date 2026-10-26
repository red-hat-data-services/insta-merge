#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$SCRIPT_DIR/merge-pr.sh"

TEST_BIN=$(mktemp -d)
trap 'rm -rf "$TEST_BIN"' EXIT

cat > "$TEST_BIN/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1 $2" == "pr merge" ]]; then
  case "$GH_SCENARIO" in
    merged-empty-output)
      exit 0
      ;;
    connection-error)
      echo "error connecting to api.github.com" >&2
      exit 1
      ;;
    connection-error-pr-open)
      echo "error connecting to api.github.com" >&2
      exit 1
      ;;
    conflicting-pr)
      echo "Pull request is not mergeable" >&2
      exit 1
      ;;
  esac
fi

if [[ "$1 $2" == "pr view" ]]; then
  case "$GH_SCENARIO" in
    connection-error)
      echo "error connecting to api.github.com" >&2
      exit 1
      ;;
    connection-error-pr-open)
      printf 'OPEN\tMERGEABLE\n'
      exit 0
      ;;
    conflicting-pr)
      printf 'OPEN\tCONFLICTING\n'
      exit 0
      ;;
  esac
fi

echo "Unexpected gh invocation: $*" >&2
exit 99
EOF
chmod +x "$TEST_BIN/gh"
PATH="$TEST_BIN:$PATH"

export GH_SCENARIO=connection-error
if try_merge_pr https://github.com/example/repo/pull/1; then
  echo "Expected a failed merge with an API connection error to fail." >&2
  exit 1
fi

export GH_SCENARIO=connection-error-pr-open
if try_merge_pr https://github.com/example/repo/pull/1; then
  echo "Expected a failed merge to fail when GitHub confirms the PR is still open." >&2
  exit 1
fi

export GH_SCENARIO=merged-empty-output
if ! try_merge_pr https://github.com/example/repo/pull/1; then
  echo "Expected a successful merge with empty stdout to succeed." >&2
  exit 1
fi

export GH_SCENARIO=conflicting-pr
if try_merge_pr https://github.com/example/repo/pull/1; then
  echo "Expected a conflicting PR to request the conflict-resolution fallback." >&2
  exit 1
else
  status=$?
  if [[ "$status" -ne 2 ]]; then
    echo "Expected conflict fallback status 2; got $status." >&2
    exit 1
  fi
fi

echo "merge-pr regression checks passed."
