# Prior art: does a Django chart already exist that we could use?

Written before the `django` chart was implemented, as a build-vs-adopt check.
Conclusion: **build our own**, but borrow from two of the charts below.

## What's out there

| Project | State | Shape |
| ------- | ----- | ----- |
| [sanoguzhan/django-helm-chart](https://github.com/sanoguzhan/django-helm-chart) | ~27 stars, single-author, no releases | Hardcoded `celery-worker`, `celery-beat` and `flower` Deployments; bundles Bitnami Redis as a subchart; migrations and `collectstatic` as init containers; Caddy sidecar for static files. No external-Postgres wiring at all. |
| [apexlabs-ai/django-helm-charts](https://github.com/apexlabs-ai/django-helm-charts) | 5 stars, ~22 commits, no forks/issues | Derived from the GlitchTip chart, aimed at Django Cookiecutter. Fixed `web` and `worker` keys. Optional bundled Postgres *and* Redis subcharts. Values carry one company's app specifics (`odooURL`, `asteriskURL`, Stripe keys), so it is an app chart wearing a generic name. |
| [itswcg/django-helm](https://github.com/itswcg/django-helm) | Tiny, dormant | Minimal single-Deployment example. |
| [APSL/kubernetes-charts](https://github.com/APSL/kubernetes-charts) | Historical | Still documents Helm 2 and Tiller. Not usable as-is. |
| GlitchTip Helm chart | Actively maintained, but for GlitchTip | Real production Django chart: web + worker Deployments and a `migrate` Job wired as a Helm lifecycle hook, with an option to turn the automatic pre-install migration off because it can mean long downtime on big databases. Bundles Postgres/Redis optionally. |
| [bjw-s-labs/helm-charts `app-template`](https://github.com/bjw-s-labs/helm-charts/tree/main/charts/other/app-template) | Actively maintained (v4.6.2, early 2026) | The strongest generic alternative — a `controllers:` map renders n workloads from one definition, which is exactly our extra-processes problem solved by someone else. |
| Bitnami `common` | Maintained | Library-chart reference for the layering question, not a Django chart. Bitnami's public catalog terms changed during 2025, so check what depending on it costs before it becomes a dependency. |

## Does any of them cover what we need?

Requirements: external-only Postgres consumed from a CNPG-generated secret,
generic extra processes, values-driven ingress class, migrations as a hook.

- Every Django-specific chart above **bundles or offers to bundle a database**,
  which is the one thing we specifically do not want, and none wires up a
  CNPG-style credentials secret.
- All of them model companion processes as **named Celery roles**, not as a
  list. Adding a Procrastinate worker, a websocket process or a Telegram bot
  means editing their templates, which is precisely the coupling we're trying
  to avoid.
- The maintained ones are maintained *for their own app* (GlitchTip), not as a
  general base.

`app-template` is the one honest "don't build it" candidate: it is generic,
maintained, and would render our web + extra process Deployments today. It was
rejected because it knows nothing about Django — no migration hook, no
assembling `DATABASE_URL` from a CNPG secret, no opinionated defaults — so every
consuming app would re-specify the same boilerplate, which is the cost this
chart exists to remove. Its values API also changed shape between majors (v3 →
v4), and it is a much larger surface than we need.

So: the Django chart landscape is a scattering of individual projects rather
than one maintained standard, several are stale, and the ones that are alive are
shaped around a specific app or a specific task framework. Building a small
chart of our own is justified.

## What we borrowed

- **Migrations as a Helm `pre-install,pre-upgrade` hook** — GlitchTip's approach,
  including its lesson: make it possible to turn off (`migrations.enabled`),
  because a long migration on a large database blocks the release.
- **One workload definition rendered n times** — the idea behind `app-template`'s
  `controllers:` map, cut down to the fields a Django process actually needs.
- **Values layout, helper naming and the `ci/` lint matrix** — from this repo's
  own `example-app`, which already follows Helm's standard conventions.

## What we deliberately did not copy

- Bundled Postgres/Redis/RabbitMQ subcharts. These are always external here —
  CloudNativePG, the RabbitMQ operator, and a separately-managed Redis.
- The Caddy static-files sidecar (`sanoguzhan`, and our own whaleportal
  deployment). Real need, but not in this iteration's scope; it is the most
  likely first addition.
- `collectstatic` init containers — an image-build concern for our apps.
