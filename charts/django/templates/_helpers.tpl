{{/*
Expand the name of the chart.
*/}}
{{- define "django.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this
(by the DNS naming spec). Resource names append a component suffix to this, so
we leave room for it.
*/}}
{{- define "django.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 48 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 48 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 48 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "django.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "django.labels" -}}
helm.sh/chart: {{ include "django.chart" . }}
{{ include "django.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels shared by every workload in the release.
*/}}
{{- define "django.selectorLabels" -}}
app.kubernetes.io/name: {{ include "django.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels for one component — the web process, an extra process, or the
migration Job. Each workload needs its own selector, so the component name is
part of it. Takes a dict of `root` and `component`.
*/}}
{{- define "django.componentSelectorLabels" -}}
{{ include "django.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Common labels plus the component. Takes a dict of `root` and `component`.
*/}}
{{- define "django.componentLabels" -}}
{{ include "django.labels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "django.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "django.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Name of the ConfigMap holding the non-secret settings.
*/}}
{{- define "django.configMapName" -}}
{{- printf "%s-config" (include "django.fullname" .) }}
{{- end }}

{{/*
The application image. One image runs every process in the chart.
*/}}
{{- define "django.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}

{{/*
envFrom sources shared by every process: the chart's own ConfigMap, then any
existing ConfigMaps, then any existing Secrets. Order matters — later sources
win on duplicate keys, so a Secret always beats non-secret config.
*/}}
{{- define "django.envFrom" -}}
{{- $sources := list -}}
{{- if .Values.config }}
{{- $sources = append $sources (dict "configMapRef" (dict "name" (include "django.configMapName" .))) -}}
{{- end }}
{{- range .Values.existingConfigMaps }}
{{- $sources = append $sources (dict "configMapRef" (dict "name" .)) -}}
{{- end }}
{{- range .Values.existingSecrets }}
{{- $sources = append $sources (dict "secretRef" (dict "name" .)) -}}
{{- end }}
{{- with $sources }}
{{- toYaml . }}
{{- end }}
{{- end }}

{{/*
Database env, assembled from the referenced Secret plus the non-secret host and
database name. Renders nothing when no secret is referenced.

DATABASE_URL is built with $(VAR) references so Kubernetes expands it in the
container from the other variables, which keeps the password out of the
manifest. Takes the root context.
*/}}
{{- define "django.databaseEnv" -}}
{{- $db := .Values.database -}}
{{- if $db.existingSecret }}
{{- $secret := $db.existingSecret -}}
{{- $host := required "database.host is required when database.existingSecret is set" $db.host -}}
{{- $env := list -}}
{{- $env = append $env (dict "name" "DATABASE_HOST" "value" $host) -}}
{{- if $db.port }}
{{- $env = append $env (dict "name" "DATABASE_PORT" "value" ($db.port | toString)) -}}
{{- else }}
{{- $env = append $env (dict "name" "DATABASE_PORT" "valueFrom" (dict "secretKeyRef" (dict "name" $secret "key" $db.keys.port))) -}}
{{- end }}
{{- if $db.name }}
{{- $env = append $env (dict "name" "DATABASE_NAME" "value" $db.name) -}}
{{- else }}
{{- $env = append $env (dict "name" "DATABASE_NAME" "valueFrom" (dict "secretKeyRef" (dict "name" $secret "key" $db.keys.database))) -}}
{{- end }}
{{- $env = append $env (dict "name" "DATABASE_USER" "valueFrom" (dict "secretKeyRef" (dict "name" $secret "key" $db.keys.username))) -}}
{{- $env = append $env (dict "name" "DATABASE_PASSWORD" "valueFrom" (dict "secretKeyRef" (dict "name" $secret "key" $db.keys.password))) -}}
{{- $url := printf "%s://$(DATABASE_USER):$(DATABASE_PASSWORD)@$(DATABASE_HOST):$(DATABASE_PORT)/$(DATABASE_NAME)" $db.urlScheme -}}
{{- $env = append $env (dict "name" $db.urlEnvVar "value" $url) -}}
{{- toYaml $env }}
{{- end }}
{{- end }}

{{/*
Full env for one process: database env, then the shared env, then the process's
own. Takes a dict of `root` and `process`.
*/}}
{{- define "django.env" -}}
{{- $root := .root -}}
{{- $process := .process -}}
{{- $env := list -}}
{{- with (include "django.databaseEnv" $root) }}
{{- $env = concat $env (. | fromYamlArray) -}}
{{- end }}
{{- $env = concat $env ($root.Values.env | default list) -}}
{{- $env = concat $env ($process.env | default list) -}}
{{- with $env }}
{{- toYaml . }}
{{- end }}
{{- end }}
