#!/usr/bin/env bash
# Lint charts the way CI does: `helm lint` once per file in the chart's ci/
# directory, plus once with the chart defaults.
#
# `helm template` is NOT enough — it concatenates output without parsing it,
# so a template that renders invalid YAML still "succeeds". `helm lint` parses
# each rendered file, which is what `ct lint` does.
#
# Usage:
#   scripts/lint-charts.sh              # every chart
#   scripts/lint-charts.sh example-app  # one chart
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ $# -gt 0 ]]; then
  charts=("charts/$1")
else
  charts=(charts/*/)
fi

failed=0
for chart in "${charts[@]}"; do
  chart="${chart%/}"
  [[ -f "$chart/Chart.yaml" ]] || continue

  echo "==> $chart (defaults)"
  helm lint "$chart" || failed=1

  for values in "$chart"/ci/*.yaml; do
    [[ -e "$values" ]] || continue
    echo "==> $chart (-f $values)"
    helm lint "$chart" -f "$values" || failed=1
  done
done

if [[ $failed -ne 0 ]]; then
  echo "FAILED" >&2
  exit 1
fi
echo "All charts linted successfully."
