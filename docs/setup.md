# Local setup

Mac toolchain for Sluice. Versions below are the Homebrew installs on the machine that wrote this file (macOS 26, Apple silicon).

| Tool | Version | What it's for in Sluice |
| --- | --- | --- |
| az | 2.91.0 | Log in to Azure and manage AKS, Key Vault, and the identity CI will use. |
| terraform | 1.16.6 | Describe that Azure infrastructure as code so it can be created and torn down the same way every time. |
| kubectl | 1.37.1 | Talk to a cluster's API server: pods, logs, and manifests. |
| helm | 4.3.1 | Install and upgrade the platform charts (vLLM, the gateway, monitoring). |
| k3d | 5.9.0 | Run a local Kubernetes cluster inside Docker before spending money on AKS. |
| k9s | 0.51.0 | Look around that cluster from the terminal. |
| argocd | 3.5.5 | Tell the cluster to match what is committed in Git, including later canaries. |
| docker | 29.8.2 | Run containers. k3d uses this as its runtime. |
| uv | 0.13.1 | Install Python 3.12 and lock the project's Python dependencies. |
| python | 3.12.12 | Language for the gateway, evals, and agents. Pinned in `.python-version`. |
| pre-commit | 4.7.0 | Run secret-scan and lint checks before a commit is recorded. |
| jq | 1.8.2 | Read JSON from `az`, `kubectl`, and `terraform` in the shell. |
| yq | 4.54.1 | Read and edit YAML manifests the same way. |

## Install

```bash
brew update
brew install azure-cli terraform kubectl helm k3d argocd k9s uv pre-commit jq yq
```

If Homebrew says the `terraform` formula is deprecated:

```bash
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
```

Container runtime (one of these, not both). This repo's check used Docker Desktop. Give it about 4 CPUs and 8 GB RAM if the Mac has them, then start the app.

```bash
brew install --cask docker-desktop
docker run --rm hello-world
```

Python:

```bash
uv python install 3.12
uv python pin 3.12
uv run python --version
```

`which terraform kubectl jq` should point at `/opt/homebrew/bin`. On this Mac, OpenJDK's `terraform` and Docker's `kubectl` come first on `PATH`, and `/usr/bin/jq` comes before Homebrew's `jq`. Those older copies are not the versions in the table.
