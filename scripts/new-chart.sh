#!/usr/bin/env bash
# Scaffold a new chart in charts/<name> from `helm create`, then apply this
# repo's conventions: repository metadata in Chart.yaml, a ci/ values file, and
# a README stub.
#
# Usage: scripts/new-chart.sh my-new-chart
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

name="${1:-}"
if [[ -z "$name" ]]; then
  echo "usage: $(basename "$0") <chart-name>" >&2
  exit 1
fi

if [[ ! "$name" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
  echo "error: chart name must be lowercase alphanumeric with dashes" >&2
  exit 1
fi

if ! command -v helm >/dev/null 2>&1; then
  echo "error: helm is not installed" >&2
  exit 1
fi

dest="$repo_root/charts/$name"
if [[ -e "$dest" ]]; then
  echo "error: $dest already exists" >&2
  exit 1
fi

helm create "$dest" >/dev/null

# Subchart dependencies are not how charts here are composed.
rm -rf "${dest:?}/charts"

# `helm create` writes its own Chart.yaml; replace it with one carrying this
# repository's metadata. Template helpers are already named after the chart.
cat > "$dest/Chart.yaml" <<EOF
---
apiVersion: v2
name: ${name}
description: A Helm chart for ${name}
type: application

# version is the chart version. Bump this on every change — the release
# workflow only publishes versions that do not exist yet.
version: 0.1.0

# appVersion is the version of the application this chart deploys.
appVersion: "1.0.0"

home: https://github.com/tirzono/helm-charts
sources:
  - https://github.com/tirzono/helm-charts/tree/master/charts/${name}
keywords:
  - ${name}
maintainers:
  - name: tirzono
    url: https://github.com/tirzono
EOF

# chart-testing installs the chart once per file in ci/.
mkdir -p "$dest/ci"
cat > "$dest/ci/default-values.yaml" <<'EOF'
---
# chart-testing installs the chart once per file in ci/.
# This one exercises the defaults; add more files to cover other paths.
resources:
  requests:
    cpu: 10m
    memory: 32Mi
EOF

# CI values are only used by chart-testing, not by consumers.
printf '\n# CI values are only used by chart-testing, not by consumers.\nci/\n' >> "$dest/.helmignore"

printf '# %s\n\nA Helm chart for %s.\n' "$name" "$name" > "$dest/README.md"

echo "Created charts/$name"
echo "Next: edit charts/$name/Chart.yaml, values.yaml and templates/, then open a PR."
