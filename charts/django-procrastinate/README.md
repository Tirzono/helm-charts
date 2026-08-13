# django-procrastinate

Django with a [Procrastinate](https://procrastinate.readthedocs.io/) worker, on
top of the [base Django chart](../django).

```console
helm install myapp oci://ghcr.io/tirzono/charts/django-procrastinate --version 0.1.0 -f values.yaml
```

Everything the base chart does, this chart does — see
[the base chart's README](../django/README.md). Only the `procrastinate` block
is documented here.

## Why this one is thin

Procrastinate wired through Django needs no broker: jobs live in the Postgres
the app already has. And its tables ship as Django migrations, so the base
chart's `migrate` hook applies them — there is no second schema step to run.

So this flavour is a worker command and a health check. That is genuinely all
the difference there is, which is worth knowing before reaching for it.

## The minimum

```yaml
image:
  repository: ghcr.io/example/myapp
  tag: "2026.08.12-1"

database:
  existingSecret: cluster-myapp-app
  host: pooler-myapp-rw
```

That renders a web Deployment, a `worker` Deployment running
`python manage.py procrastinate worker` with a healthcheck liveness probe, and
the migration hook.

## The procrastinate block

| Key | Default | Notes |
| --- | ------- | ----- |
| `procrastinate.manageCommand` | `["python", "manage.py"]` | How this image invokes Django management commands. |
| `procrastinate.worker.enabled` | `true` | |
| `procrastinate.worker.name` | `worker` | Deployment suffix and container name. |
| `procrastinate.worker.replicas` | `1` | |
| `procrastinate.worker.queues` | `[]` | `--queues`. Empty consumes all of them. |
| `procrastinate.worker.concurrency` | `""` | `--concurrency`. |
| `procrastinate.worker.extraArgs` | `[]` | Appended to the generated command. |
| `procrastinate.worker.command` | `[]` | Replaces the generated command entirely. |

The worker accepts everything an `extraProcesses` entry accepts — `resources`,
`env`, `annotations`, `nodeSelector`, `strategy`, the probes — because that is
what it becomes.

## Generated command

```
python manage.py procrastinate worker [--queues a,b] [--concurrency N] [extraArgs]
```

## Probe

The worker's liveness probe is Procrastinate's own health check:

```
python manage.py procrastinate healthchecks
```

It verifies the database connection, that migrations are applied, and that the
app imports. It starts a Django process each time, so the period is 120s by
default. Turn it off with `procrastinate.worker.livenessProbe: null` — an empty
map merges into the default rather than replacing it.

## Extra processes

`extraProcesses` still works and renders after the worker:

```yaml
extraProcesses:
  - name: bot
    command: ["python", "manage.py", "run_bot"]
```

## Examples

- [`examples/single-worker-values.yaml`](examples/single-worker-values.yaml) —
  a complete deployment: CNPG database, existing secret, ingress.
