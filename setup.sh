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

# kubectl-mcp-server 1.24.0 imports `ToolAnnotations` from `fastmcp.tools`,
# a symbol fastmcp dropped from that module across its whole 4.x series (it
# now lives in mcp_types). Without it, kubectl_mcp_tool's own ImportError
# fallback reaches for `from mcp.server.fastmcp import FastMCP`, which
# fastmcp 4.x's own mcp>=2.0 dependency removed too - so kubectl-mcp-serve
# can't start at all (confirmed against every published 4.0.x release,
# 2026-09-25). Re-export the symbol into the installed fastmcp package so
# kubectl-mcp-server's primary import path keeps working until it ships a
# fastmcp 4.x-compatible release. Safe to re-run: skips itself once
# fastmcp.tools already has the symbol.
"$DEMO_VENV/bin/python" - <<'PYEOF'
import inspect

import fastmcp.tools

if not hasattr(fastmcp.tools, "ToolAnnotations"):
    init_file = inspect.getsourcefile(fastmcp.tools)
    with open(init_file, "a") as f:
        f.write(
            "\nfrom mcp_types import ToolAnnotations  "
            "# k8s-ai-demo compat shim, see setup.sh\n"
        )
PYEOF

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
