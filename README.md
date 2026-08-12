# helm-charts

A multi-chart Helm repository. Every directory under [`charts/`](charts/) is an
independently versioned chart, published two ways on every merge to `master`:

- **HTTP repository** (GitHub Pages) — `https://tirzono.github.io/helm-charts`
- **OCI registry** (GHCR) — `oci://ghcr.io/tirzono/charts/<chart>`

## Using the charts

```console
helm repo add tirzono https://tirzono.github.io/helm-charts
helm repo update
helm search repo tirzono
helm install my-release tirzono/example-app
```

Or pull straight from the OCI registry, no `helm repo add` needed:

```console
helm install my-release oci://ghcr.io/tirzono/charts/example-app --version 0.1.0
```

## Available charts

| Chart | Description |
| ----- | ----------- |
| [example-app](charts/example-app) | Starter chart showing the layout every chart here follows |

## Adding a chart

```console
./scripts/new-chart.sh my-new-chart
```

That copies `charts/example-app` into `charts/my-new-chart` and rewrites the
template helpers and `Chart.yaml` metadata. Replace the templates and values
with your own, add a row to the table above, and open a PR.

Charts are fully independent — they have their own `Chart.yaml`, version, and
release tags. Nothing needs to be registered centrally; the workflows discover
whatever is in `charts/`.

## Releasing

Releases are driven entirely by the `version` field in each chart's
`Chart.yaml`:

1. Bump `version` in `charts/<chart>/Chart.yaml` (semver).
2. Merge to `master`.
3. [`release.yaml`](.github/workflows/release.yaml) packages the chart, creates
   a GitHub release tagged `<chart>-<version>`, refreshes `index.yaml` on the
   `gh-pages` branch, and pushes the same package to GHCR.

Chart versions that already exist are skipped, so a merge that touches only
templates without bumping `version` publishes nothing. CI enforces this — the
`ct lint` step fails a PR that changes a chart without incrementing its
version.

`appVersion` tracks the upstream application and does not affect what gets
released.

## CI

| Workflow | Trigger | What it does |
| -------- | ------- | ------------ |
| [lint-test.yaml](.github/workflows/lint-test.yaml) | PRs touching `charts/**` | `ct lint` on changed charts, then `ct install` against a kind cluster |
| [release.yaml](.github/workflows/release.yaml) | push to `master` touching `charts/**` | chart-releaser → GitHub Pages + GHCR |

Only charts changed relative to `master` are linted and installed, so adding a
tenth chart doesn't slow down PRs to the first nine.

Each chart's `ci/*.yaml` files are extra value sets that
[chart-testing](https://github.com/helm/chart-testing) installs one by one —
use them to cover optional templates such as Ingress or autoscaling.

## One-time repository setup

The publishing pipeline needs three things enabled on the GitHub repository.
This only has to be done once.

**1. Create the `gh-pages` branch.** chart-releaser writes `index.yaml` there
and will fail if the branch does not exist:

```console
git checkout --orphan gh-pages
git rm -rf .
echo "# Helm chart repository" > README.md
git add README.md
git commit -m "Initialize gh-pages"
git push -u origin gh-pages
git checkout master
```

**2. Turn on GitHub Pages.** Settings → Pages → Source: *Deploy from a branch*,
branch `gh-pages`, folder `/ (root)`.

**3. Allow Actions to write.** Settings → Actions → General → Workflow
permissions: *Read and write permissions*. The release workflow needs this to
create tags, releases, and push to `gh-pages`.

No secrets to configure — the workflows use the built-in `GITHUB_TOKEN` for
both GitHub Pages and GHCR.

The first release publishes its GHCR packages as private. Make them public at
Packages → `<chart>` → Package settings → Change visibility, or consumers will
need to `helm registry login` before pulling.

## Local development

```console
helm lint charts/<chart>
helm template test charts/<chart>
helm install test charts/<chart> --dry-run

# Same checks CI runs, if you have chart-testing installed:
ct lint --config ct.yaml
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full workflow.
