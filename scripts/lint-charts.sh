#!/usr/bin/env bash
# Lint charts the way CI does: `helm lint` once per file in the chart's ci/
# directory, plus once with the chart defaults. Also lints every file in the
# chart's examples/ directory, which CI does not touch at all.
#
# `helm template` is NOT enough — it concatenates output without parsing it,
# so a template that renders invalid YAML still "succeeds". `helm lint` parses
# each rendered file, which is what `ct lint` does.
#
# Usage:
#   scripts/lint-charts.sh              # every chart
#   scripts/lint-charts.sh django       # one chart
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

  # Charts built on the django-common library need it vendored into charts/
  # before they render; ct does this itself in CI. `build` fails when Chart.lock
  # is older than a bumped dependency version, so fall back to regenerating it —
  # commit the updated Chart.lock when that happens.
  if grep -q '^dependencies:' "$chart/Chart.yaml"; then
    helm dependency build "$chart" >/dev/null 2>&1 \
      || helm dependency update "$chart" >/dev/null
  fi

  echo "==> $chart (defaults)"
  helm lint "$chart" || failed=1

  # ci/ files are installed against a real cluster by `ct install`, so they can
  # only reference objects that exist there. examples/ files are lint-only, so
  # they can cover paths that need a Secret from a real namespace.
  for values in "$chart"/ci/*.yaml "$chart"/examples/*.yaml; do
    [[ -e "$values" ]] || continue
    echo "==> $chart (-f $values)"
    helm lint "$chart" -f "$values" || failed=1
  done
done

# Flavour charts carry the base chart's values verbatim; make sure the copies
# have not drifted.
"$repo_root/scripts/check-shared-values.sh" || failed=1

if [[ $failed -ne 0 ]]; then
  echo "FAILED" >&2
  exit 1
fi
echo "All charts linted successfully."
