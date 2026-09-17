# Contributing

Thanks for considering a contribution to k8s-ai-demo.

## Before you start

Open an issue for anything beyond a small fix, so we can agree on the approach before you put time into it.

## Commits and pull requests

- Commit messages must follow [Conventional Commits](https://www.conventionalcommits.org/). This is enforced by CI (`commit-lint`).
- Pull request titles must also follow Conventional Commits. CI (`pr-lint`) checks this too, since a squash merge takes its message from the PR title.
- Keep commits small and focused; a pull request with five commits that each do one thing is easier to review than one commit that does five things.

Run `make initialise` once after cloning to install the pre-commit hooks (including a local conventional-commit check, so you find out before you push).

## Testing changes locally

```bash
make setup      # creates the kind cluster and the broken-state resources
make preflight  # rehearses both failure/fix cycles, then restores the broken state
make demo       # runs the on-stage script (add DEMO_AUTO_RUN=1 DEMO_RUN_FAST=1 to run it non-interactively)
make reset      # returns the cluster to the broken-state baseline
make cleanup    # deletes the kind cluster entirely
```

`.github/workflows/e2e.yml` runs this exact sequence against a real `kind` cluster on every push/PR - see it for the non-interactive invocation.

## Reporting issues

Open an issue on GitHub with what you expected, what happened instead, and how to reproduce it.
