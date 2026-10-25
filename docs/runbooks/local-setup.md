# Local setup (macOS)

## Tools

```sh
brew tap hashicorp/tap
brew install hashicorp/tap/terraform pre-commit gitleaks checkov azure-cli gh powershell
```

tflint has no Homebrew formula. Install the release binary and verify its checksum:

```sh
mkdir -p ~/.local/bin && cd "$(mktemp -d)"
V=0.65.0
curl -sSLO "https://github.com/terraform-linters/tflint/releases/download/v${V}/tflint_darwin_arm64.zip"
curl -sSLO "https://github.com/terraform-linters/tflint/releases/download/v${V}/checksums.txt"
shasum -a 256 -c --ignore-missing checksums.txt   # expect: tflint_darwin_arm64.zip: OK
unzip -o tflint_darwin_arm64.zip -d ~/.local/bin   # ~/.local/bin must be on PATH
```

Check versions against CI (`.github/workflows/_pr.yml`):

```sh
terraform version     # 1.17.0
tflint --version      # 0.65.0
gitleaks version      # 8.30.1
checkov --version     # 3.3.30
```

## Hooks

```sh
pre-commit install
pre-commit run --all-files
```

The `no-commit-to-branch` hook blocks commits on `main`. Work on a branch and open a pull request.

## Sign in

```sh
terraform login                          # HCP Terraform user token, stored in ~/.terraform.d/
az login --tenant <lab-tenant-id>        # Terraform providers use this session locally
```

## Run the offline checks for one root

```sh
cd tfc
terraform init -backend=false
terraform validate
tflint --init --config="$(git rev-parse --show-toplevel)/.tflint.hcl"
tflint --config="$(git rev-parse --show-toplevel)/.tflint.hcl"
terraform test
```

`terraform test` uses mock providers, so it needs no sign-in.
