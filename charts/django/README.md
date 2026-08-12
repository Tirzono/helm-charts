# django

A base chart for a Django application: one web Deployment, any number of extra
process Deployments, and a migration hook — against a Postgres that lives
outside the chart.

The chart deliberately knows nothing about task frameworks. A Celery worker, a
Procrastinate worker, a scheduler, a websocket process and a Telegram bot are
all the same thing from here: the same image, a different command. They are
entries in a list, not templates.

```console
helm install myapp oci://ghcr.io/tirzono/charts/django --version 0.1.0 -f values.yaml
```

## What it renders

| Resource | When |
| -------- | ---- |
| Deployment (web) | always |
| Deployment (one per extra process) | for each entry in `extraProcesses` |
| Service | always, `ClusterIP` by default |
| Ingress | `ingress.enabled: true` |
| ConfigMap (settings) | `config` is non-empty |
| ConfigMap (mounted files) | `configFiles` is non-empty |
| Job (`manage.py migrate`) | `migrations.enabled: true`, as a `pre-install,pre-upgrade` hook |
| ServiceAccount | `serviceAccount.create: true` |
| Test Pod | `helm test`, when `tests.enabled: true` |

What it never renders: a database, a broker, or a cache. Postgres is managed by
CloudNativePG, RabbitMQ by its operator, Redis separately — the chart only
consumes connections.

## Values

| Block | What it covers |
| ----- | -------------- |
| `image` | The one image every process runs. |
| `web` | The web process: command, replicas, port, probes, strategy. |
| `extraProcesses` | A list; one Deployment per entry. Empty renders nothing. |
| `service`, `ingress` | Networking. Both modes below are supported. |
| `config` | Non-secret env, rendered into a ConfigMap. |
| `configFiles` | Files rendered into a ConfigMap for mounting — a proxy config, for example. |
| `existingSecrets`, `existingConfigMaps` | Existing objects wired up with `envFrom`. |
| `database` | Host and name from values, credentials from an existing Secret. |
| `env` | Extra env for every process, `valueFrom` included. |
| `migrations` | The migration hook. |
| Shared defaults | `resources`, `podSecurityContext`, `securityContext`, `nodeSelector`, `tolerations`, `affinity`, `volumes`, `volumeMounts`, `podAnnotations`, `podLabels` — applied to every process, overridable per process. |

Every key is commented in [values.yaml](values.yaml).

## Extra processes

Only `name` and `command` are required. Anything else falls back to the shared
default at the top level of values.

```yaml
extraProcesses:
  - name: worker
    command: ["python", "manage.py", "procrastinate", "worker"]
    replicas: 2
    resources:
      requests:
        cpu: 200m
        memory: 512Mi

  - name: beat
    command: ["celery", "-A", "config", "beat"]
    # One scheduler at a time, so it must not overlap itself during a rollout.
    strategy:
      type: Recreate

  - name: bot
    command: ["python", "manage.py", "run_bot"]
    env:
      - name: BOT_MODE
        value: polling
```

Each entry accepts `name`, `command`, `args`, `replicas`, `strategy`, `ports`,
`resources`, `env`, `podAnnotations`, `podLabels`, `volumes`, `volumeMounts`,
`nodeSelector`, `tolerations`, `affinity`, and the three probes.

The chart does not create a Service for an extra process that declares `ports`.
Nothing has needed one yet; it is a small addition when something does.

## Sidecars and static files

A Django deployment usually wants something in front of the app to serve static
and media files. That is a container spec, a config file and a Service target —
so the chart provides those three things rather than a "static files" feature.

```yaml
web:
  # The port the application itself listens on, now behind the proxy.
  containerPort: 5000

  extraContainers:
    - name: proxy
      image: caddy:2.10.2-alpine
      ports:
        - name: proxy
          containerPort: 8000
      volumeMounts:
        - name: proxy-config
          mountPath: /etc/caddy/Caddyfile
          subPath: Caddyfile

  volumes:
    - name: proxy-config
      configMap:
        name: '{{ include "django.filesConfigMapName" . }}'

# The Service fronts the proxy instead of the application.
service:
  targetPort: proxy

configFiles:
  Caddyfile: |
    :8000 {
      handle_path /media/* {
        reverse_proxy https://objectstorage.example.com
      }
      reverse_proxy localhost:5000
    }
```

`extraContainers`, `volumes` and `volumeMounts` are rendered through `tpl`, so
values can name chart-generated objects — which is how the volume above finds
the ConfigMap without knowing the release name. Contents of `configFiles` go
through `tpl` as well; Caddy's single-brace placeholders (`{uri}`) pass through
untouched, but a literal `{{` in a config file would need escaping.

Pods roll when a mounted file changes: `configFiles` is hashed into a
`checksum/files` pod annotation, the same way `config` is.

`extraContainers` works on any process, not just `web` — the same field on an
`extraProcesses` entry adds a sidecar to that process.

A worked example is in
[`examples/caddy-static-values.yaml`](examples/caddy-static-values.yaml), and
`ci/sidecar-values.yaml` installs the pattern on every CI run so the wiring
stays covered.

Two things to watch:

- A named port in a probe resolves within the container that declares it, so a
  probe on the app cannot name the sidecar's port.
- Port names are unique per pod: the app keeps `http`, the sidecar needs its own
  name.

## Database

Postgres is always external. The chart takes credentials from a Secret that
already exists — normally the one CloudNativePG generates for a cluster's app
user — and the host from values, because the host is often deliberately not the
one in the secret (a Pooler service rather than the cluster service):

```yaml
database:
  existingSecret: cluster-myapp-app
  host: pooler-myapp-rw
```

That renders `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USER`,
`DATABASE_PASSWORD`, and a `DATABASE_URL` assembled from them with `$(VAR)`
references, so the password is expanded in the container and never appears in a
manifest. The default `database.keys` match CNPG's secret; override them for a
secret with different keys.

Every process gets the same wiring — extra processes hit the same database as
the web process.

Connections other than Postgres arrive as ordinary env:

```yaml
env:
  - name: RABBITMQ_URL
    valueFrom:
      secretKeyRef:
        name: rabbitmqcluster-myapp-default-user
        key: connection_string
```

## Secrets

One mode: reference a Secret that already exists in the namespace.

```yaml
existingSecrets:
  - myapp-secrets
```

The chart never creates or generates a Secret. Chart-created secrets from
values, and secrets generated by a random-secret controller, are deliberately
left for a later iteration.

## Networking

Two modes, both values-only:

```yaml
# Behind an ingress controller — set the class to whatever the cluster runs.
ingress:
  enabled: true
  className: traefik
  hosts:
    - host: app.example.com
      paths:
        - path: /
          pathType: Prefix
```

```yaml
# No ingress controller at all.
ingress:
  enabled: false
service:
  type: LoadBalancer
```

## Migrations

`python manage.py migrate` runs as a `pre-install,pre-upgrade` hook at weight
`-5`, so it finishes before any Deployment rolls. Argo CD reads the same
annotations and treats it as a PreSync hook, so `helm install` and an Argo sync
behave the same way.

An app that needs a second step chains it rather than getting its own template:

```yaml
migrations:
  command: ["sh", "-c", "python manage.py migrate && python manage.py <step>"]
```

Set `migrations.enabled: false` to run migrations by hand — worth doing when a
migration is long enough that blocking the release is the bigger problem.

The hook runs before the release's own ServiceAccount exists, so the Job uses
the namespace `default` ServiceAccount when the chart creates the
ServiceAccount. With `serviceAccount.create: false` the named account already
exists and the Job uses it.

## Examples

[`examples/`](examples/) holds complete values files:

- [`procrastinate-worker-values.yaml`](examples/procrastinate-worker-values.yaml)
  — one web process and one Procrastinate worker.
- [`celery-stack-values.yaml`](examples/celery-stack-values.yaml) — Celery
  workers, Celery Beat, a websocket process and a bot, with an external broker
  and cache.
- [`caddy-static-values.yaml`](examples/caddy-static-values.yaml) — a Caddy
  sidecar serving `/media/` from object storage in front of the app.

They are linted like the `ci/` files but never installed, so they can reference
Secrets that only exist in a real cluster.

## Development

```console
../../scripts/lint-charts.sh django
```
