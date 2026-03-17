#!/usr/bin/env bash
# setup-env.sh — bootstrap the phoneinfoga development environment
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GOPATH_BIN="$(go env GOPATH)/bin"
export PATH="$PATH:$GOPATH_BIN"

echo "==> Installing Go dev tools..."
go install gotest.tools/gotestsum@v1.6.3
go install github.com/vektra/mockery/v2@v2.38.0
go install github.com/swaggo/swag/cmd/swag@v1.16.3
if ! command -v golangci-lint &>/dev/null; then
  curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh \
    | bash -s -- -b "$GOPATH_BIN" v1.46.2
fi

echo "==> Downloading Go module dependencies..."
GOPROXY=https://goproxy.io,direct GONOSUMDB='*' go mod download

echo "==> Creating placeholder web client dist (if not already built)..."
if [ ! -d "$REPO_ROOT/web/client/dist" ]; then
  mkdir -p "$REPO_ROOT/web/client/dist"
  cat > "$REPO_ROOT/web/client/dist/index.html" <<'HTML'
<!DOCTYPE html>
<html>
<head><title>PhoneInfoga</title></head>
<body><p>Web UI not built. Run <code>yarn install &amp;&amp; yarn build</code> in web/client/ to enable it.</p></body>
</html>
HTML
fi

echo "==> Generating Swagger docs and building binary..."
GOPROXY=https://goproxy.io,direct GONOSUMDB='*' go generate ./...
GOPROXY=https://goproxy.io,direct GONOSUMDB='*' go build \
  -ldflags="-s -w -X 'github.com/sundowndev/phoneinfoga/v2/build.Version=dev' \
             -X 'github.com/sundowndev/phoneinfoga/v2/build.Commit=$(git rev-parse --short HEAD 2>/dev/null || echo local)'" \
  -o "$REPO_ROOT/bin/phoneinfoga" .

echo ""
echo "==> Environment ready!"
echo "    Binary : $REPO_ROOT/bin/phoneinfoga"
echo "    Version: $($REPO_ROOT/bin/phoneinfoga version)"
echo ""
echo "Usage examples:"
echo "  $REPO_ROOT/bin/phoneinfoga scan -n \"+1 555 444 3333\""
echo "  $REPO_ROOT/bin/phoneinfoga serve   # starts REST API + web UI on :5000"
echo ""
echo "Run tests:"
echo "  PATH=\"\$PATH:$GOPATH_BIN\" GOPROXY=https://goproxy.io,direct GONOSUMDB='*' \\"
echo "    gotestsum --format testname -- -mod=readonly -race ./..."
