# Contributing

## Repository layout

```
charts/
  <chart-name>/
    Chart.yaml           # name, version, appVersion, metadata
    values.yaml          # documented defaults
    README.md            # install instructions + values table
    .helmignore
    templates/
      _helpers.tpl
      ...
      tests/             # `helm test` hooks, run by `ct install`
    ci/
      *-values.yaml      # extra value sets CI installs one by one
.github/workflows/
  lint-test.yaml         # PR checks
  release.yaml           # publish on merge to master
ct.yaml                  # chart-testing config
.yamllint.yaml           # YAML style rules used by ct lint
scripts/new-chart.sh     # scaffold a new chart
```

Charts are independent. Adding one means adding a directory — no central
registry to update.

## Adding a chart

```console
./scripts/new-chart.sh my-new-chart
```

Then edit `charts/my-new-chart/`:

- `Chart.yaml` — set `description`, `appVersion`, `keywords`, and `sources`.
  Leave `version` at `0.1.0` for the first release.
- `values.yaml` — every key should have a sensible default and a comment.
- `README.md` — install snippet and a values table.
- `ci/` — at least one values file; add more for optional templates so CI
  actually renders and installs them.

## Changing an existing chart

Bump `version` in `Chart.yaml` on every change that affects the packaged chart.
CI fails the PR otherwise (`check-version-increment` in `ct.yaml`).

Use semver:

| Change | Bump |
| ------ | ---- |
| Bug fix, doc-only change to templates | patch |
| New value or template, backwards compatible | minor |
| Renamed/removed value, changed default that breaks upgrades | major |

Bumping `appVersion` to track a new upstream release still needs a `version`
bump — usually patch or minor.

## Before opening a PR

```console
helm lint charts/<chart>
helm template test charts/<chart>
for f in charts/<chart>/ci/*.yaml; do helm template test charts/<chart> -f "$f" >/dev/null; done
```

If you have [chart-testing](https://github.com/helm/chart-testing) and
[kind](https://kind.sigs.k8s.io/) locally, this is exactly what CI runs:

```console
ct lint --config ct.yaml
kind create cluster
ct install --config ct.yaml
```

## What happens on merge

Merging to `master` triggers [release.yaml](.github/workflows/release.yaml),
which publishes any chart whose version is not already released — as a GitHub
release tagged `<chart>-<version>`, an entry in `index.yaml` on `gh-pages`, and
an OCI artifact at `ghcr.io/tirzono/charts/<chart>`.

Releases are never rewritten. To fix a bad release, publish a new version.
