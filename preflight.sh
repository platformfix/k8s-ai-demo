#!/usr/bin/env bash
# Run immediately before you walk on stage.
#
# Arms both failures, proves each is real, rehearses both fixes via the
# exact same tool call the AI will make live, then restores the broken
# state so the real run starts clean. Pattern:
# second-brain/events/bit-summit-2026/talk/demo/preflight.sh.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=env.sh
source ./env.sh
# shellcheck source=util.sh
source ./util.sh

fail() {
  echo
  echo "Pre-flight FAILED: $1"
  echo "Use the fallback slide."
  exit 1
}

echo "==> Checking required tools"
for bin in kind kubectl python3 pv jq; do
  command -v "$bin" >/dev/null 2>&1 || fail "missing tool: $bin"
done

echo "==> Checking cluster and namespace"
kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME" || fail "kind cluster '$CLUSTER_NAME' not found - run ./setup.sh first"
kubectl get namespace "$DEMO_NAMESPACE" >/dev/null 2>&1 || fail "namespace '$DEMO_NAMESPACE' not found - run ./setup.sh first"

echo "==> Checking kubectl-mcp-server"
[ -x "$DEMO_VENV/bin/kubectl-mcp-serve" ] || fail "kubectl-mcp-server not installed - run ./setup.sh first"
"$DEMO_VENV/bin/kubectl-mcp-serve" doctor 2>&1 | grep -q "All checks passed" || fail "kubectl-mcp-server doctor reported a problem"

echo "==> Confirming broken-state #1 is real (checkout-api should be failing)"
reason="$(kubectl -n "$DEMO_NAMESPACE" get pod -l app=checkout-api -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || true)"
[ "$reason" = "CreateContainerConfigError" ] || fail "checkout-api is not in the expected broken state (got: '$reason')"

echo "==> Rehearsing fix #1 (Secret key mismatch)"
out="$(mcp_patch deployment "$CHECKOUT_DEPLOYMENT" "$DEMO_NAMESPACE" '[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/valueFrom/secretKeyRef/key","value":"db-password"}]')"
echo "$out" | grep -qi '"success":true\|success.*true' || fail "fix #1 did not report success: $out"
kubectl -n "$DEMO_NAMESPACE" wait --for=condition=Available deployment/"$CHECKOUT_DEPLOYMENT" --timeout=60s || fail "checkout-api did not become Available after fix #1"

echo "==> Confirming broken-state #2 is real (NetworkPolicy should block storefront)"
if kubectl -n "$DEMO_NAMESPACE" exec deploy/"$STOREFRONT_DEPLOYMENT" -- wget -q -T 4 -O- "http://$CHECKOUT_SERVICE" >/dev/null 2>&1; then
  fail "storefront could already reach checkout-api - broken-state #2 (NetworkPolicy) is not actually blocking traffic. Is Calico Running (kubectl -n kube-system get pods)?"
fi

echo "==> Rehearsing fix #2 (NetworkPolicy selector)"
out="$(mcp_patch networkpolicy "$CHECKOUT_NETPOL" "$DEMO_NAMESPACE" '[{"op":"replace","path":"/spec/ingress/0/from/0/podSelector/matchLabels/app","value":"storefront"}]')"
echo "$out" | grep -qi '"success":true\|success.*true' || fail "fix #2 did not report success: $out"
kubectl -n "$DEMO_NAMESPACE" exec deploy/"$STOREFRONT_DEPLOYMENT" -- wget -q -T 5 -O- "http://$CHECKOUT_SERVICE" >/dev/null 2>&1 || fail "storefront still could not reach checkout-api after fix #2"

echo "==> Restoring broken state for the real run"
kubectl apply -f resources/ >/dev/null

echo
echo "Pre-flight PASSED. Both failures are real, both fixes work. Go."
