#!/usr/bin/env bash
# Leaves the cluster empty and ready - deletes only demo-created state and
# re-applies the broken-state baseline. Never re-runs setup.sh (kind
# cluster + Calico stay up), matching
# second-brain/events/bit-summit-2026/talk/demo/reset.sh's split.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=env.sh
source ./env.sh

echo "==> Deleting demo-created resources"
kubectl delete -f resources/ --ignore-not-found >/dev/null

echo "==> Re-applying the broken-state baseline"
kubectl apply -f resources/ >/dev/null

echo "==> Reset complete."
