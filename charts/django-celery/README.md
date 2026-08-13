# django-celery

Django with a Celery stack: a worker, Beat, and optionally Flower — on top of
the [base Django chart](../django), against an external Postgres and an external
broker.

```console
helm install myapp oci://ghcr.io/tirzono/charts/django-celery --version 0.1.0 -f values.yaml
```

Everything the base chart does, this chart does — web Deployment, extra
processes, Service, Ingress, ConfigMaps, migration hook, external Postgres
wiring. See [the base chart's README](../django/README.md) for all of it; only
the `celery` block is documented here.

## The minimum

```yaml
image:
  repository: ghcr.io/example/myapp
  tag: "2026.08.12-1"

database:
  existingSecret: cluster-myapp-app
  host: pooler-myapp-rw

celery:
  app: config
  broker:
    existingSecret: rabbitmqcluster-myapp-default-user
    existingSecretKey: connection_string
```

That renders a web Deployment, a `worker` Deployment (2 replicas, with an
`inspect ping` liveness probe), a `beat` Deployment (1 replica, `Recreate`
strategy), the migration hook, and `CELERY_APP` + `CELERY_BROKER_URL` on every
process — the web pod included, since it is what publishes the tasks.

## The celery block

| Key | Default | Notes |
| --- | ------- | ----- |
| `celery.app` | `config` | The `-A` target. Also exported as `CELERY_APP`. |
| `celery.logLevel` | `info` | `--loglevel` for worker and Beat. |
| `celery.broker` | — | `envVar`, and either `url` or `existingSecret` + `existingSecretKey`. |
| `celery.resultBackend` | — | Same shape. Omit it if the app does not use one. |
| `celery.worker` | enabled, 2 replicas | `queues`, `concurrency`, `extraArgs`, `command`. |
| `celery.beat` | enabled, 1 replica | `Recreate` strategy, `extraArgs`, `command`. |
| `celery.flower` | disabled | `port`, `extraArgs`, `command`. |

`worker`, `beat` and `flower` each accept everything an `extraProcesses` entry
accepts — `replicas`, `resources`, `env`, `annotations`, `nodeSelector`,
`tolerations`, `affinity`, `volumes`, `volumeMounts`, `strategy`, the probes —
because that is what they become.

## Generated commands

```
worker   celery -A <app> worker --loglevel <level> [--queues a,b] [--concurrency N] [extraArgs]
beat     celery -A <app> beat --loglevel <level> [extraArgs]
flower   celery -A <app> flower --port=<port> [extraArgs]
```

Set `command` on any of them to replace the generated one — the case for an
image whose entrypoint already knows how to start a worker:

```yaml
celery:
  worker:
    command: ["worker"]
```

## Probes

The worker ships a liveness probe that round-trips through the broker:

```
celery -A $CELERY_APP inspect ping -d celery@$HOSTNAME
```

Timings are slack on purpose (60s delay, 120s period, 30s timeout) — a worker
busy with long tasks answers slowly and should not be restarted for it. Turn it
off with `celery.worker.livenessProbe: null`; an empty map merges into the
default rather than replacing it, which is how Helm treats every default map
here.

## Flower

Off by default, and no Service is created for it when on — reach it with a
port-forward:

```console
kubectl port-forward deploy/<release>-django-celery-flower 5555:5555
```

## Beat and replicas

`celery.beat.replicas` is 1 for a reason: two Beats mean every scheduled task
fires twice. The chart does not stop you raising it, because an app using a
locking scheduler such as redbeat legitimately can.

## Extra processes

`extraProcesses` still works and renders after the Celery ones, for a process
Celery knows nothing about:

```yaml
extraProcesses:
  - name: bot
    command: ["python", "manage.py", "run_bot"]
```

## Examples

- [`examples/full-stack-values.yaml`](examples/full-stack-values.yaml) — worker,
  Beat, Flower, an external RabbitMQ and Redis, ingress and a static-files
  sidecar.
