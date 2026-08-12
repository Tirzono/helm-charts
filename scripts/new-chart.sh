#!/usr/bin/env bash
# Scaffold a new chart in charts/<name> by copying the example-app starter
# and renaming its template helpers.
#
# Usage: scripts/new-chart.sh my-new-chart
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
template="example-app"

name="${1:-}"
if [[ -z "$name" ]]; then
  echo "usage: $(basename "$0") <chart-name>" >&2
  exit 1
fi

if [[ ! "$name" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
  echo "error: chart name must be lowercase alphanumeric with dashes" >&2
  exit 1
fi

dest="$repo_root/charts/$name"
if [[ -e "$dest" ]]; then
  echo "error: $dest already exists" >&2
  exit 1
fi

cp -R "$repo_root/charts/$template" "$dest"

# Rename the "<template>." template helpers to "<name>." throughout.
find "$dest" -type f -print0 | xargs -0 sed -i.bak "s/${template}\./${name}./g"
find "$dest" -name '*.bak' -delete

# Reset chart metadata that should not be inherited.
sed -i.bak \
  -e "s/^name: .*/name: ${name}/" \
  -e "s/^description: .*/description: A Helm chart for ${name}/" \
  -e "s/^version: .*/version: 0.1.0/" \
  -e "s/^  - example$/  - ${name}/" \
  "$dest/Chart.yaml"
rm -f "$dest/Chart.yaml.bak"

# The starter's tree/ source URL points at the template chart.
sed -i.bak "s#/charts/${template}#/charts/${name}#g" "$dest/Chart.yaml"
rm -f "$dest/Chart.yaml.bak"

printf '# %s\n\nA Helm chart for %s.\n' "$name" "$name" > "$dest/README.md"

echo "Created charts/$name"
echo "Next: edit charts/$name/Chart.yaml, values.yaml and templates/, then open a PR."
