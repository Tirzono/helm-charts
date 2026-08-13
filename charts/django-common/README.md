# django-common

A `type: library` chart. It renders nothing on its own and cannot be installed —
it holds the templates that every Django chart in this repo is built from:

| Chart | What it adds |
| ----- | ------------ |
| [django](../django) | Nothing. The base: you write the processes yourself. |
| [django-celery](../django-celery) | A `celery` block that renders worker, Beat and Flower processes plus broker env. |
| [django-procrastinate](../django-procrastinate) | A `procrastinate` block that renders the worker process. |

The split exists so a Celery app does not re-type the same four process
definitions in every values file, while the workload, service, ingress, config
and migration logic stays in one place.

## What it defines

Resource templates, each taking a context dict:

| Define | Renders |
| ------ | ------- |
| `django.deployment.web` | the web Deployment |
| `django.deployments.processes` | one Deployment per extra process |
| `django.service` | the Service |
| `django.ingress` | the Ingress, when enabled |
| `django.configMap` | settings ConfigMap, when `config` is set |
| `django.configMapFiles` | mounted-files ConfigMap, when `configFiles` is set |
| `django.job.migrate` | the migration hook Job |
| `django.serviceAccount` | the ServiceAccount |
| `django.test` | the `helm test` Pod |
| `django.notes` | the install notes (takes the root context directly) |

Plus the helpers behind them: `django.fullname`, `django.labels`,
`django.componentLabels`, `django.componentSelectorLabels`, `django.image`,
`django.env`, `django.envFrom`, `django.databaseEnv`, `django.podSpec`,
`django.podMetadata`.

## The context dict

Every resource define takes:

```
root            the root context ($) — required
extraProcesses  processes a flavour computed, rendered ahead of .Values.extraProcesses
extraEnv        env a flavour computed, added to every container ahead of the user's own
```

A chart with no opinions passes only `root`:

```yaml
{{- include "django.service" (dict "root" .) }}
```

A flavour computes its additions first:

```yaml
{{- $extraEnv := include "django-celery.env" . | fromYamlArray }}
{{- $extraProcesses := include "django-celery.processes" . | fromYamlArray }}
{{- include "django.deployments.processes" (dict "root" . "extraProcesses" $extraProcesses "extraEnv" $extraEnv) }}
```

`extraEnv` lands after the database env and before the user's own `env`, so a
user override always wins.

## Building a new flavour

1. `Chart.yaml` — `type: application`, with this chart as a `file://../django-common`
   dependency.
2. `values.yaml` — the flavour block, then the base chart's values verbatim
   below the marker (`scripts/check-shared-values.sh --fix` writes that half).
3. `templates/_<flavour>.tpl` — defines that turn the flavour block into
   `extraProcesses` entries and `extraEnv` entries. Entries are shaped exactly
   like `extraProcesses` entries, so everything the base supports per process
   works for free.
4. `templates/*.yaml` — one line per resource, calling the defines above.
5. `ci/` — at least one values file that installs on kind.

The flavour should stay a values-to-values translation. Anything that needs a
new resource or a new field on a workload belongs in this library, where all
three charts get it.

## Versioning

Charts vendor this library at package time, so a change here reaches consumers
only when:

1. this chart's `version` is bumped,
2. each dependent chart's `dependencies[].version` is updated to match, and
3. each dependent chart's own `version` is bumped.

That is the cost of the split. CI enforces step 3 (`check-version-increment`),
and `helm dependency build` fails on a `Chart.lock` that has fallen behind.
