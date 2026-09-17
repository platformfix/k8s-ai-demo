#!/usr/bin/env bash
# Run once, in the green room. Idempotent - safe to re-run.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=env.sh
source ./env.sh

echo "==> Checking required tools"
for bin in kind kubectl python3 pip3 pv; do
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

echo "==> Wiring the kubernetes MCP server into Claude Code"
# Registered via `claude mcp add-json` (user scope), not by hand-editing a
# config file - `claude mcp` is the tool's own supported interface, and it
# is the only thing that reliably knows where that config actually lives.
# ~/.config/claude-code/mcp.json is NOT a real Claude Code config path;
# the CLI's real, checkable config lives under ~/.claude.json's own
# mcpServers key. Confirmed live 2026-09-17 after Steve reported the
# server missing from /mcp - the first version of this script wrote to
# the wrong path and Claude Code never read it.
#
# Not present in CI (the GitHub Actions runner has no `claude` CLI at
# all) - skipped there deliberately, since e2e.yml verifies the cluster
# and kubectl-mcp-server itself, not Claude Code's own config wiring.
if command -v claude >/dev/null 2>&1; then
  claude mcp remove kubernetes --scope user >/dev/null 2>&1 || true
  claude mcp add-json kubernetes \
    "{\"type\":\"stdio\",\"command\":\"$DEMO_VENV/bin/kubectl-mcp-serve\",\"args\":[\"serve\"],\"env\":{\"KUBECONFIG\":\"$DEMO_KUBECONFIG\"}}" \
    --scope user
else
  echo "    claude CLI not found on PATH - skipping (expected in CI)"
fi

echo
echo "==> Setup complete. Run ./preflight.sh immediately before you walk on stage."
