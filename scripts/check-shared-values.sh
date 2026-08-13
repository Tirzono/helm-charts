#!/usr/bin/env bash
# Every chart built on django-common carries the base chart's values verbatim,
# so `helm show values <flavour>` documents the whole API rather than only the
# flavour's own block.
#
# That copy has to stay a copy. This checks that everything below the marker in
# each flavour's values.yaml is byte-identical to charts/django/values.yaml.
#
# Usage:
#   scripts/check-shared-values.sh          # check
#   scripts/check-shared-values.sh --fix    # rewrite the copies from the base
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

base="charts/django/values.yaml"
marker_text="# BASE VALUES — shared verbatim with charts/django/values.yaml"
flavours=(django-celery django-procrastinate)

fix=0
[[ "${1:-}" == "--fix" ]] && fix=1

# The base file's leading `---` is dropped: the copy is spliced into the middle
# of another document, where a second `---` would start a new one.
base_body="$(tail -n +2 "$base")"

failed=0
for flavour in "${flavours[@]}"; do
  file="charts/$flavour/values.yaml"

  if ! grep -qF "$marker_text" "$file"; then
    echo "error: $file has no base-values marker" >&2
    failed=1
    continue
  fi

  # The marker block is four lines: a rule, the two lines of text, a rule.
  # Everything after it is the copy.
  marker_line="$(grep -nF "$marker_text" "$file" | head -1 | cut -d: -f1)"
  own="$(head -n $((marker_line + 2)) "$file")"
  copied="$(tail -n +$((marker_line + 3)) "$file")"

  if [[ "$copied" == "$base_body" ]]; then
    echo "==> $file in sync with $base"
    continue
  fi

  if [[ $fix -eq 1 ]]; then
    printf '%s\n%s\n' "$own" "$base_body" > "$file"
    echo "==> $file rewritten from $base"
  else
    echo "==> $file has drifted from $base" >&2
    diff <(echo "$base_body") <(echo "$copied") | head -20 >&2 || true
    failed=1
  fi
done

if [[ $failed -ne 0 ]]; then
  echo "FAILED — run scripts/check-shared-values.sh --fix" >&2
  exit 1
fi
echo "Shared values are in sync."
