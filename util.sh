#!/usr/bin/env bash
# Shared demo harness. Pattern originated in Christian Posta's
# scripted-solo-demos, adapted via platformfix/solo-scripted-demos and
# second-brain/events/bit-summit-2026/talk/demo.

TYPE_SPEED=25
if [ "${DEMO_RUN_FAST:-0}" = "1" ]; then
  TYPE_SPEED=1000
fi

desc() {
  echo
  echo "# $*"
}

run() {
  local cmd="$*"
  printf '%s' "$cmd" | pv -qL "$TYPE_SPEED"
  echo
  if [ "${DEMO_AUTO_RUN:-0}" != "1" ]; then
    read -rsn1 -p "[press any key to run]"
    echo
  fi
  eval "$cmd"
}

# Flags loudly only if the command unexpectedly succeeds - used for the
# one step that's supposed to fail (proving a broken state is real).
run_expect_fail() {
  local cmd="$*"
  if run "$cmd"; then
    echo "!! Expected '$cmd' to fail, but it succeeded. !!"
    return 1
  fi
  return 0
}

pause_for_presenter() {
  if [ "${DEMO_AUTO_RUN:-0}" != "1" ]; then
    read -rsn1 -p "$1"
    echo
  fi
}

# Calls kubectl-mcp-server's kubectl_patch tool directly - used to prove a
# fix mechanically (preflight's rehearsal, and demo.sh's DEMO_AUTO_RUN=1
# path for CI, where there's no live AI to drive the patch). The payload
# is built with python3's json.dumps so a JSON-string-inside-JSON patch
# body never has to be hand-escaped at a shell call site. Prints the raw
# tool response; the caller checks for success.
mcp_patch() {
  local resource_type="$1" name="$2" namespace="$3" patch_json="$4"
  # kubectl-mcp-server logs its own startup/registration chatter to
  # stderr on every invocation - real, but not something a presenter (or
  # preflight's own PASS/FAIL output) needs to see. Routed to a log file
  # instead of /dev/null so it's still there to check after a failure.
  python3 - "$resource_type" "$name" "$namespace" "$patch_json" <<'PYEOF' | "$DEMO_VENV/bin/kubectl-mcp-serve" call kubectl_patch 2>>"$REPO_ROOT/.mcp-call.log"
import json, sys
resource_type, name, namespace, patch = sys.argv[1:5]
print(json.dumps({
    "resource_type": resource_type,
    "name": name,
    "namespace": namespace,
    "patch_type": "json",
    "patch": patch,
}))
PYEOF
}
