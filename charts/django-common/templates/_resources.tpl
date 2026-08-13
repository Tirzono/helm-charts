{{/*
The resources every chart built on this library renders.

Each define takes a context dict:
  root            the root context ($) — required
  extraProcesses  optional list of process dicts a flavour chart computed from
                  its own values, rendered ahead of .Values.extraProcesses
  extraEnv        optional env entries a flavour chart computed, added to every
                  process ahead of the user's own env so the user still wins

A plain chart passes `(dict "root" .)` and nothing else.
*/}}

{{/*
ServiceAccount.
*/}}
{{- define "django.serviceAccount" -}}
{{- $root := .root -}}
{{- if $root.Values.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "django.serviceAccountName" $root }}
  labels:
    {{- include "django.labels" $root | nindent 4 }}
  {{- with $root.Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
ConfigMap holding non-secret settings, mounted with envFrom.
*/}}
{{- define "django.configMap" -}}
{{- $root := .root -}}
{{- if $root.Values.config }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "django.configMapName" $root }}
  labels:
    {{- include "django.labels" $root | nindent 4 }}
data:
  {{- range $key, $value := $root.Values.config }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
ConfigMap holding files to mount — a proxy config, a logging config. Kept
separate from the settings ConfigMap because these are mounted, not loaded.
*/}}
{{- define "django.configMapFiles" -}}
{{- $root := .root -}}
{{- if $root.Values.configFiles }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "django.filesConfigMapName" $root }}
  labels:
    {{- include "django.labels" $root | nindent 4 }}
data:
  {{- range $name, $content := $root.Values.configFiles }}
  {{ $name }}: |
    {{- tpl $content $root | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Service, fronting the web process.
*/}}
{{- define "django.service" -}}
{{- $root := .root -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "django.fullname" $root }}
  labels:
    {{- include "django.componentLabels" (dict "root" $root "component" "web") | nindent 4 }}
  {{- with $root.Values.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ $root.Values.service.type }}
  ports:
    - port: {{ $root.Values.service.port }}
      targetPort: {{ $root.Values.service.targetPort }}
      protocol: TCP
      name: http
  selector:
    {{- include "django.componentSelectorLabels" (dict "root" $root "component" "web") | nindent 4 }}
{{- end }}

{{/*
Ingress, rendered only when enabled.
*/}}
{{- define "django.ingress" -}}
{{- $root := .root -}}
{{- if $root.Values.ingress.enabled }}
{{- $svcName := include "django.fullname" $root }}
{{- $svcPort := $root.Values.service.port }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "django.fullname" $root }}
  labels:
    {{- include "django.componentLabels" (dict "root" $root "component" "web") | nindent 4 }}
  {{- with $root.Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with $root.Values.ingress.className }}
  ingressClassName: {{ . }}
  {{- end }}
  {{- with $root.Values.ingress.tls }}
  tls:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  rules:
    {{- range $root.Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ $svcName }}
                port:
                  number: {{ $svcPort }}
          {{- end }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
The web Deployment.
*/}}
{{- define "django.deployment.web" -}}
{{- $root := .root -}}
{{- $extraEnv := .extraEnv | default list -}}
{{- $web := deepCopy $root.Values.web -}}
{{- $_ := set $web "ports" (list (dict "name" "http" "containerPort" ($root.Values.web.containerPort | int) "protocol" "TCP")) -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "django.fullname" $root }}-web
  labels:
    {{- include "django.componentLabels" (dict "root" $root "component" "web") | nindent 4 }}
  {{- with (merge (dict) ($web.annotations | default dict) ($root.Values.annotations | default dict)) }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  replicas: {{ $root.Values.web.replicas }}
  revisionHistoryLimit: {{ $root.Values.revisionHistoryLimit }}
  {{- with $root.Values.web.strategy }}
  strategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "django.componentSelectorLabels" (dict "root" $root "component" "web") | nindent 6 }}
  template:
    metadata:
      {{- include "django.podMetadata" (dict "root" $root "component" "web" "process" $web) | trim | nindent 6 }}
    spec:
      {{- include "django.podSpec" (dict "root" $root "component" "web" "process" $web "extraEnv" $extraEnv) | trim | nindent 6 }}
{{- end }}

{{/*
One Deployment per extra process. Flavour-computed processes come first, then
whatever the user listed in extraProcesses. Nothing renders when both are empty.
*/}}
{{- define "django.deployments.processes" -}}
{{- $root := .root -}}
{{- $extraEnv := .extraEnv | default list -}}
{{- $processes := concat (.extraProcesses | default list) ($root.Values.extraProcesses | default list) -}}
{{- $seen := dict -}}
{{- range $process := $processes }}
{{- $name := required "each extraProcesses entry needs a name" $process.name }}
{{- if has $name (list "web" "migrate") }}
{{- fail (printf "extraProcesses name %q is reserved by the chart's own workloads" $name) }}
{{- end }}
{{- if hasKey $seen $name }}
{{- fail (printf "extraProcesses has more than one entry named %q" $name) }}
{{- end }}
{{- $_ := set $seen $name true }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "django.fullname" $root }}-{{ $name }}
  labels:
    {{- include "django.componentLabels" (dict "root" $root "component" $name) | nindent 4 }}
  {{- with (merge (dict) ($process.annotations | default dict) ($root.Values.annotations | default dict)) }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  replicas: {{ dig "replicas" 1 $process }}
  revisionHistoryLimit: {{ $root.Values.revisionHistoryLimit }}
  {{- with $process.strategy }}
  strategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "django.componentSelectorLabels" (dict "root" $root "component" $name) | nindent 6 }}
  template:
    metadata:
      {{- include "django.podMetadata" (dict "root" $root "component" $name "process" $process) | trim | nindent 6 }}
    spec:
      {{- include "django.podSpec" (dict "root" $root "component" $name "process" $process "extraEnv" $extraEnv) | trim | nindent 6 }}
{{- end }}
{{- end }}

{{/*
The migration Job, as a Helm hook that runs before the Deployments roll. Argo
CD reads the same annotations and treats it as a PreSync hook.

The hook runs before the release's own resources are created, which includes
the ServiceAccount this chart creates — so the Job falls back to the namespace
`default` ServiceAccount in that case. When the ServiceAccount is managed
outside the chart (serviceAccount.create: false) it already exists, and the Job
uses it, which is the case where the identity actually matters.
*/}}
{{- define "django.job.migrate" -}}
{{- $root := .root -}}
{{- $extraEnv := .extraEnv | default list -}}
{{- if $root.Values.migrations.enabled }}
{{- $serviceAccountName := ternary "default" (include "django.serviceAccountName" $root) $root.Values.serviceAccount.create -}}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "django.fullname" $root }}-migrate
  labels:
    {{- include "django.componentLabels" (dict "root" $root "component" "migrate") | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-5"
    # A failed Job is kept so its logs can be read; the next release deletes it
    # before creating the new one.
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  backoffLimit: {{ $root.Values.migrations.backoffLimit }}
  {{- with $root.Values.migrations.activeDeadlineSeconds }}
  activeDeadlineSeconds: {{ . }}
  {{- end }}
  template:
    metadata:
      {{- include "django.podMetadata" (dict "root" $root "component" "migrate" "process" $root.Values.migrations) | trim | nindent 6 }}
    spec:
      restartPolicy: Never
      {{- include "django.podSpec" (dict "root" $root "component" "migrate" "process" $root.Values.migrations "extraEnv" $extraEnv "serviceAccountName" $serviceAccountName) | trim | nindent 6 }}
{{- end }}
{{- end }}

{{/*
`helm test` Pod that fetches the web Service.
*/}}
{{- define "django.test" -}}
{{- $root := .root -}}
{{- if $root.Values.tests.enabled }}
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "django.fullname" $root }}-test-connection"
  labels:
    {{- include "django.labels" $root | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  restartPolicy: Never
  containers:
    - name: wget
      image: busybox:1.36
      command: ['wget']
      args: ['{{ include "django.fullname" $root }}:{{ $root.Values.service.port }}']
{{- end }}
{{- end }}
