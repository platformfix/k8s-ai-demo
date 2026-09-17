#!/usr/bin/env bash
# Run once, in the green room. Idempotent - safe to re-run.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=env.sh
source ./env.sh

echo "==> Checking required tools"
for bin in kind kubectl python3 pip3 jq pv; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "Missing required tool: $bin"
    exit 1
  }
done

echo "==> Creating kind cluster ($CLUSTER_NAME)"
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "    already exists, skipping"
else
  kind_config="$(mktemp)"
  cat >"$kind_config" <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: "192.168.0.0/16"
EOF
  kind create cluster --name "$CLUSTER_NAME" --kubeconfig "$DEMO_KUBECONFIG" --config "$kind_config"
  rm -f "$kind_config"
fi

echo "==> Installing Calico (kind's default CNI does not enforce NetworkPolicies)"
kubectl apply -f "$CALICO_MANIFEST"
kubectl -n kube-system rollout status daemonset/calico-node --timeout=180s
kubectl -n kube-system rollout status deployment/calico-kube-controllers --timeout=180s

echo "==> Applying broken-state resources"
kubectl apply -f resources/

echo "==> Installing pinned kubectl-mcp-server into $DEMO_VENV"
if [ ! -d "$DEMO_VENV" ]; then
  python3 -m venv "$DEMO_VENV"
fi
"$DEMO_VENV/bin/pip" install --quiet --no-cache-dir -r requirements.txt
"$DEMO_VENV/bin/kubectl-mcp-serve" doctor

echo "==> Wiring the kubernetes MCP server into $MCP_CONFIG_FILE"
mkdir -p "$(dirname "$MCP_CONFIG_FILE")"
if [ ! -f "$MCP_CONFIG_FILE" ]; then
  echo '{"mcpServers":{}}' >"$MCP_CONFIG_FILE"
fi
mcp_tmp="$(mktemp)"
jq --arg cmd "$DEMO_VENV/bin/kubectl-mcp-serve" \
  --arg kubeconfig "$DEMO_KUBECONFIG" \
  '.mcpServers.kubernetes = {command: $cmd, args: ["serve"], env: {KUBECONFIG: $kubeconfig}}' \
  "$MCP_CONFIG_FILE" >"$mcp_tmp"
mv "$mcp_tmp" "$MCP_CONFIG_FILE"

echo
echo "==> Setup complete. Run ./preflight.sh immediately before you walk on stage."
