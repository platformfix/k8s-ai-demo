#!/usr/bin/env bash
# Run after the conference. Deletes the kind cluster entirely.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=env.sh
source ./env.sh

kind delete cluster --name "$CLUSTER_NAME"
rm -f "$DEMO_KUBECONFIG"

echo "==> Cleanup complete. The kind cluster is gone."
echo "    Note: this does not remove the 'kubernetes' entry from $MCP_CONFIG_FILE"
echo "    or the .venv - re-run ./setup.sh before the next event."
