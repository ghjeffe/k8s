#!/usr/bin/env bash
set -euo pipefail

# This script installs and configures a GitHub Actions self-hosted runner for this repository.
# Usage: ./scripts/setup-github-runner.sh <github-owner> <repo-name> <runner-name>
# Example: ./scripts/setup-github-runner.sh my-org pyapp local-runner

OWNER=${1:-}
REPO=${2:-}
RUNNER_NAME=${3:-local-runner}
GITHUB_URL="https://github.com/$OWNER/$REPO"
RUNNER_DIR="./github-runner"

if [[ -z "$OWNER" || -z "$REPO" ]]; then
  echo "Usage: $0 <github-owner> <repo-name> [runner-name]"
  exit 1
fi

mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

echo "Downloading latest GitHub Actions runner..."
RUNNER_TAR="actions-runner-linux-x64-2.308.0.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v2.308.0/$RUNNER_TAR"

curl -fsSL "$RUNNER_URL" -o "$RUNNER_TAR"

tar xzf "$RUNNER_TAR"
rm "$RUNNER_TAR"

cat > config.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${RUNNER_TOKEN:-}" ]]; then
  echo "Please set RUNNER_TOKEN with a repository registration token."
  exit 1
fi

./config.sh --unattended \
  --url "$GITHUB_URL" \
  --token "$RUNNER_TOKEN" \
  --name "$RUNNER_NAME" \
  --work _work
EOF
chmod +x config.sh

echo "Runner files downloaded into $RUNNER_DIR."
echo "Next steps:"
echo "  1) Create a repository registration token in GitHub settings -> Actions -> Runners -> New self-hosted runner."
echo "  2) export RUNNER_TOKEN=<token>"
echo "  3) cd $RUNNER_DIR && ./config.sh"
echo "  4) ./run.sh to start the runner"
