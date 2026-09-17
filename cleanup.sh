#!/usr/bin/env bash
# Run after the conference. Deletes the kind cluster entirely and drops any
# local commits that never got pushed - e.g. an on-stage AI session
# "fixing" the broken-by-design fixtures under resources/ and committing
# that, which would silently defang the demo for the next event if it
# survived (caught for real, 2026-09-17).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=env.sh
source ./env.sh

kind delete cluster --name "$CLUSTER_NAME"
rm -f "$DEMO_KUBECONFIG"

echo "==> Checking for local commits never pushed upstream"
git fetch origin --quiet
upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo "origin/main")"
if [ -n "$(git status --porcelain)" ]; then
  echo "    working tree has uncommitted changes - leaving git history alone."
  echo "    Commit or discard them yourself, then re-run cleanup.sh."
else
  ahead="$(git rev-list --count "$upstream"..HEAD)"
  if [ "$ahead" -gt 0 ]; then
    echo "    found $ahead commit(s) not on $upstream - discarding them"
    git reset --hard "$upstream"
  else
    echo "    none found"
  fi
fi

echo "==> Cleanup complete. The kind cluster is gone."
echo "    Note: this does not remove the 'kubernetes' MCP server registration"
echo "    ('claude mcp remove kubernetes --scope user' does) or the .venv -"
echo "    re-run ./setup.sh before the next event."
