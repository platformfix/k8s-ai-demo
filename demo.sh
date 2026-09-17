#!/usr/bin/env bash
# The literal on-stage script. Do not improvise here.
#
# DEMO_AUTO_RUN=1 replaces the two live-AI pauses with the exact same
# kubectl_patch calls a diagnosing AI would make (via mcp_patch, util.sh) -
# used by CI's e2e.yml and by rehearsal, since there's no live Claude Code
# session to drive the fix in either of those. On stage, DEMO_AUTO_RUN is
# unset and the AI genuinely does the diagnosis and the fix.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=env.sh
source ./env.sh
# shellcheck source=util.sh
source ./util.sh

FIX1_PATCH='[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/valueFrom/secretKeyRef/key","value":"db-password"}]'
FIX2_PATCH='[{"op":"replace","path":"/spec/ingress/0/from/0/podSelector/matchLabels/app","value":"storefront"}]'

desc "Checkout is down. Here's the cluster right now:"
run "kubectl -n $DEMO_NAMESPACE get pods"

desc "In Claude Code, with the 'kubernetes' MCP server connected, ask:"
desc '  "Show me which pods are failing in the k8s-ai-demo namespace, and why - then fix it."'
if [ "${DEMO_AUTO_RUN:-0}" = "1" ]; then
  echo "[DEMO_AUTO_RUN=1: applying the same fix a diagnosing AI would make]"
  mcp_patch deployment "$CHECKOUT_DEPLOYMENT" "$DEMO_NAMESPACE" "$FIX1_PATCH"
else
  pause_for_presenter "[press any key once the AI has diagnosed and fixed checkout-api]"
fi

desc "Confirming checkout-api is healthy now:"
run "kubectl -n $DEMO_NAMESPACE wait --for=condition=Available deployment/$CHECKOUT_DEPLOYMENT --timeout=60s"

desc "checkout-api is up - but is it actually reachable from storefront?"
run_expect_fail "kubectl -n $DEMO_NAMESPACE exec deploy/$STOREFRONT_DEPLOYMENT -- wget -q -T 4 -O- http://$CHECKOUT_SERVICE"

desc "Back in Claude Code, ask:"
desc '  "storefront can reach the checkout-api Service but every request times out. Diagnose and fix it."'
if [ "${DEMO_AUTO_RUN:-0}" = "1" ]; then
  echo "[DEMO_AUTO_RUN=1: applying the same fix a diagnosing AI would make]"
  mcp_patch networkpolicy "$CHECKOUT_NETPOL" "$DEMO_NAMESPACE" "$FIX2_PATCH"
else
  pause_for_presenter "[press any key once the AI has diagnosed and fixed the NetworkPolicy]"
fi

desc "Confirming storefront can now reach checkout-api:"
run "kubectl -n $DEMO_NAMESPACE exec deploy/$STOREFRONT_DEPLOYMENT -- wget -q -T 5 -O- http://$CHECKOUT_SERVICE"

desc "Checkout is back. That's the whole demo."
