# Security Policy

## Supported versions

k8s-ai-demo has no releases or long-term-support branch to track - it's a single scripted demo kept working against `main`.

## Reporting a vulnerability

Please report security issues privately rather than opening a public GitHub issue: use [GitHub's private vulnerability reporting](https://github.com/platformfix/k8s-ai-demo/security/advisories/new) for this repository (Security tab -> Report a vulnerability).

Include what you'd include in any good bug report: the affected commit, what you found, and how to reproduce it. We'll acknowledge new reports within 5 business days and aim to have a fix or mitigation plan within 30 days, depending on severity.

## Scope

This repo creates a local, disposable `kind` cluster and grants the bundled `kubectl-mcp-server` unrestricted access to it (see README's "Why no safety flags" section) - that's the intended design for a local, throwaway demo cluster, not a finding on its own. Reports about the setup/teardown scripts, the vendored manifests, the CI pipeline, or the MCP server registration `setup.sh` creates via `claude mcp add-json` are in scope.
