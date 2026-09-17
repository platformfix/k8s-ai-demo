# k8s-ai-demo

![lint](https://github.com/platformfix/k8s-ai-demo/actions/workflows/lint.yml/badge.svg)
![commit-lint](https://github.com/platformfix/k8s-ai-demo/actions/workflows/commit-lint.yaml/badge.svg)
![pr-lint](https://github.com/platformfix/k8s-ai-demo/actions/workflows/pr-lint.yml/badge.svg)
![e2e](https://github.com/platformfix/k8s-ai-demo/actions/workflows/e2e.yml/badge.svg)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/platformfix/k8s-ai-demo/badge)](https://securityscorecards.dev/viewer/?uri=github.com/platformfix/k8s-ai-demo)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A 15-minute, fully local conference demo: [`kubectl-mcp-server`](https://github.com/rohitg00/kubectl-mcp-server)
gives Claude Code a real, scoped connection to a real Kubernetes cluster, and
an AI genuinely diagnoses and fixes two real, chained failures live on stage -
no slides pretending to show output that was never actually run.

## Why this exists

[`platformfix/podium`](https://github.com/platformfix/podium) already ships
`kubectl-mcp-server` baked into its image, for exactly this kind of demo.
That path runs the MCP server inside a remote pod over `kubectl exec` - which
depends on a live cluster, credentials, and venue wifi. Fine for a workshop
where the room already has a cluster; too fragile for a 15-minute conference
slot with nothing to fall back on if the network blinks.

This repo takes the same tool and makes it fully local and self-contained:
one `./setup.sh` in the green room creates a disposable `kind` cluster,
installs a correctly-pinned `kubectl-mcp-server`, and wires it into Claude
Code - no remote dependency of any kind once the images are cached.

## Quick start

```bash
make setup      # once, in the green room - creates the kind cluster
make preflight  # immediately before you walk on stage
make demo       # on stage
make reset      # leaves the cluster empty and ready (run between rehearsals)
make cleanup    # after the conference - deletes the kind cluster
```

Each target is a thin wrapper around the matching `./*.sh` script - run the
scripts directly if you'd rather not use `make`.

## The scenario

`checkout-api` is down, and the AI is asked to bring it back - two real,
chained failures, fixed live:

1. **A Secret key mismatch.** `checkout-api`'s Deployment reads a database
   password from a key that doesn't exist in the Secret - a
   `CreateContainerConfigError`, the container never starts. Ask the AI to
   find out why the pod is failing and fix it.
2. **A NetworkPolicy that blocks the real traffic.** Once the pod is
   healthy, a `NetworkPolicy` still only allows ingress from a pod label
   that doesn't exist in the namespace, so `storefront` gets nothing but
   timeouts talking to a perfectly healthy Service. Ask the AI to find out
   why the request never arrives, and fix that too.

Both failures are real Kubernetes state, not scripted output - `preflight.sh`
proves this immediately before every run by rehearsing both fixes for real
and then restoring the broken baseline.

## Why Calico

`kind`'s default CNI (`kindnet`) does not enforce `NetworkPolicy` at all - a
NetworkPolicy-based failure would silently do nothing on a vanilla `kind`
cluster. `setup.sh` installs a pinned, vendored Calico manifest
(`vendor/calico-v3.32.2.yaml`) so the second failure is real and the fix is
observable.

## Why no `--read-only` / `--disable-destructive`

Both of kubectl-mcp-server 1.24.0's safety flags are implemented as one flat
check (`non_destructive = get_safety_mode() != SafetyMode.NORMAL`) that
blocks *every* write tool, `scale_deployment` included - not just deletes,
despite what `--disable-destructive`'s own `--help` text claims. There is no
flag combination that would let this demo patch a Deployment or a
NetworkPolicy while still blocking a delete. This was found and confirmed
independently in `platformfix/k8s-training`'s own `kubectl-mcp-server`
dry-run (`slides/ai-demo/ai-demo.migration-notes.md`) before this repo was
built. The server here runs unrestricted; the actual safety boundary is the
same one that dry-run landed on - two scripted, reviewed prompts that never
ask the AI to delete anything.

## What `setup.sh` writes to your MCP config

`setup.sh` merges (never overwrites) a `kubernetes` entry into
`~/.config/claude-code/mcp.json`, pointed at this repo's own pinned install
and its own dedicated kubeconfig - it never touches your default kubeconfig,
current context, or any other MCP server entry already in that file:

```json
{
  "mcpServers": {
    "kubernetes": {
      "command": "<this repo>/.venv/bin/kubectl-mcp-serve",
      "args": ["serve"],
      "env": { "KUBECONFIG": "<this repo>/.kubeconfig" }
    }
  }
}
```

## Repo layout

```
env.sh, util.sh     - shared config and the desc/run/run_expect_fail harness
setup.sh            - green room: kind cluster, Calico, broken-state resources, pinned kubectl-mcp-server, MCP config
preflight.sh        - immediately before stage: proves both failures and both fixes, restores the broken baseline
demo.sh             - the on-stage script; DEMO_AUTO_RUN=1 drives the same fixes CI does, for rehearsal and e2e
reset.sh            - between rehearsals: re-applies the broken-state baseline without recreating the cluster
cleanup.sh          - after the conference: deletes the kind cluster
resources/          - the broken-by-design Kubernetes manifests
vendor/             - the pinned Calico manifest
```

The `desc`/`run`/`run_expect_fail` harness pattern originated in Christian
Posta's `scripted-solo-demos`, adapted via `platformfix/solo-scripted-demos`
and `second-brain/events/bit-summit-2026/talk/demo`.

## Security and supply chain

This repo follows `platformfix/podium`'s standards: SHA-pinned GitHub
Actions, Dependabot on both the `github-actions` and `pip` ecosystems,
Conventional Commits enforced on both commit messages and PR titles, a
weekly OpenSSF Scorecard scan, and an `e2e.yml` that runs this repo's own
full lifecycle - `setup` -> `preflight` -> `demo` -> `reset` -> `cleanup` -
against a real `kind` cluster on every push and pull request. See
[`SECURITY.md`](SECURITY.md) for how to report a vulnerability and
[`CONTRIBUTING.md`](CONTRIBUTING.md) for the contribution workflow.

## License

MIT - see [`LICENSE`](LICENSE).
