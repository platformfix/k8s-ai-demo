#!/usr/bin/env bash
# Single place to change identifiers - never touched by demo.sh itself.
# Pattern: second-brain/events/bit-summit-2026/talk/demo.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT

export CLUSTER_NAME="k8s-ai-demo"
export DEMO_NAMESPACE="k8s-ai-demo"
export CHECKOUT_DEPLOYMENT="checkout-api"
export CHECKOUT_SERVICE="checkout-api"
export CHECKOUT_CONFIGMAP="checkout-api-config"
export CHECKOUT_SECRET="checkout-api-secrets"
export STOREFRONT_DEPLOYMENT="storefront"
export CHECKOUT_NETPOL="checkout-api-allow-storefront"

export DEMO_VENV="$REPO_ROOT/.venv"
export DEMO_KUBECONFIG="$REPO_ROOT/.kubeconfig"
export CALICO_MANIFEST="$REPO_ROOT/vendor/calico-v3.32.2.yaml"

# Every script in this repo talks to the demo cluster only - never the
# presenter's default kubeconfig/context.
export KUBECONFIG="$DEMO_KUBECONFIG"
