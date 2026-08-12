# example-app

A starter chart that shows the layout every chart in this repository follows.
Copy the directory, rename it, and replace the templates with your own.

## Installing

```console
helm repo add tirzono https://tirzono.github.io/helm-charts
helm repo update
helm install my-release tirzono/example-app
```

Or straight from the OCI registry:

```console
helm install my-release oci://ghcr.io/tirzono/charts/example-app --version 0.1.0
```

## Uninstalling

```console
helm uninstall my-release
```

## Values

| Key | Type | Default | Description |
| --- | ---- | ------- | ----------- |
| `replicaCount` | int | `1` | Number of replicas (ignored when `autoscaling.enabled` is true) |
| `image.repository` | string | `nginxinc/nginx-unprivileged` | Container image repository |
| `image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `image.tag` | string | `""` | Image tag, defaults to the chart `appVersion` |
| `imagePullSecrets` | list | `[]` | Secrets for pulling from a private registry |
| `nameOverride` | string | `""` | Override the chart name portion of resource names |
| `fullnameOverride` | string | `""` | Override the full resource name |
| `serviceAccount.create` | bool | `true` | Create a ServiceAccount |
| `serviceAccount.annotations` | object | `{}` | Annotations for the ServiceAccount |
| `serviceAccount.name` | string | `""` | Name of the ServiceAccount to use |
| `podAnnotations` | object | `{}` | Extra pod annotations |
| `podLabels` | object | `{}` | Extra pod labels |
| `podSecurityContext` | object | runs as non-root with `RuntimeDefault` seccomp | Pod-level security context |
| `securityContext` | object | drops all capabilities, no privilege escalation | Container-level security context |
| `service.type` | string | `ClusterIP` | Service type |
| `service.port` | int | `8080` | Service port (also the container port) |
| `ingress.enabled` | bool | `false` | Create an Ingress |
| `ingress.className` | string | `""` | IngressClass name |
| `ingress.annotations` | object | `{}` | Ingress annotations |
| `ingress.hosts` | list | one `chart-example.local` host | Ingress host rules |
| `ingress.tls` | list | `[]` | Ingress TLS configuration |
| `resources` | object | `{}` | Container resource requests and limits |
| `livenessProbe` | object | HTTP GET on `/` | Liveness probe |
| `readinessProbe` | object | HTTP GET on `/` | Readiness probe |
| `autoscaling.enabled` | bool | `false` | Create a HorizontalPodAutoscaler |
| `autoscaling.minReplicas` | int | `1` | HPA minimum replicas |
| `autoscaling.maxReplicas` | int | `10` | HPA maximum replicas |
| `autoscaling.targetCPUUtilizationPercentage` | int | `80` | HPA target CPU utilization |
| `volumes` | list | `[]` | Extra volumes on the Deployment |
| `volumeMounts` | list | `[]` | Extra volume mounts on the container |
| `nodeSelector` | object | `{}` | Node selector |
| `tolerations` | list | `[]` | Tolerations |
| `affinity` | object | `{}` | Affinity rules |
