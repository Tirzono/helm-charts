# Contributing

## Repository layout

```
charts/
  <chart-name>/
    Chart.yaml           # name, version, appVersion, metadata
    values.yaml          # documented defaults
    README.md            # install instructions + values table
    .helmignore
    templates/            # no leading `---`; Helm emits its own separators
      _helpers.tpl
      ...
      tests/             # `helm test` hooks, run by `ct install`
    ci/
      *-values.yaml      # extra value sets CI installs one by one
    examples/            # optional: complete values files, linted but never
      *-values.yaml      # installed, so they can reference real-cluster objects
.github/workflows/
  lint-test.yaml         # PR checks
  release.yaml           # publish on merge to master
ct.yaml                  # chart-testing config (lint)
ct-install.yaml          # chart-testing config (install; excludes library charts)
.yamllint.yaml           # YAML style rules used by ct lint
scripts/new-chart.sh     # scaffold a new chart
scripts/lint-charts.sh   # run CI's lint matrix locally
scripts/check-shared-values.sh  # keep the Django charts' shared values in sync
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
  actually renders and installs them. These run against a real cluster, so they
  can only reference objects that exist there.
- `examples/` — optional. Values files that document real usage. The local lint
  script renders them, but CI never installs them, so this is where a values set
  that references an existing Secret belongs.

## Chart families

Some charts share templates through a `type: library` chart — the Django charts
are the current example:

```
django-common           library: every template
  django                base: no opinions
  django-celery         adds a celery values block
  django-procrastinate  adds a procrastinate values block
```

Rules for working in a family like that:

- **Templates go in the library.** An application chart in the family should be
  a values file plus one-line calls into the library. A flavour may add defines
  that translate its own values block into what the library already renders,
  and nothing more.
- **The library is a dependency by relative path**
  (`repository: file://../django-common`), so a PR's CI tests that PR's library
  rather than the last published one. Consumers get a vendored copy at package
  time.
- **A library change ships only when its dependents are bumped too**: bump the
  library's `version`, update `dependencies[].version` in each dependent, and
  bump each dependent's own `version`. `helm dependency build` fails on a stale
  `Chart.lock` — run `helm dependency update <chart>` and commit the result.
- **Shared values stay byte-identical.** Flavour charts carry the base chart's
  `values.yaml` verbatim below a marker, so `helm show values` documents the
  whole API. Edit `charts/django/values.yaml`, then run
  `scripts/check-shared-values.sh --fix`. CI runs the check.
- **Library charts are excluded from `ct install`** (`ct-install.yaml`) because
  Helm cannot install them. They are still linted.

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
./scripts/lint-charts.sh <chart>    # omit <chart> to lint all of them
```

That runs `helm lint` once with the chart defaults and once per file in the
chart's `ci/` directory — the same matrix `ct lint` uses in CI.

Lint with each `ci/` values file, not just the defaults. A template guarded by
`{{- if }}` is not rendered at all under the defaults, so a broken optional
template passes a bare `helm lint` and fails in CI.

Do not substitute `helm template` for `helm lint`. `helm template` concatenates
rendered output without parsing it and inserts its own `---` separators, so a
template that produces invalid YAML still exits 0. `helm lint` parses each
rendered file on its own, which is what CI does.

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
