{{/*
The pod spec shared by the web Deployment, every extra process Deployment and
the migration Job. All three run the same image with a different command, so
they differ only in the fields taken from `process`.

Takes a dict:
  root       the root context
  component  container name and the value of app.kubernetes.io/component
  process    a process dict from values — `web`, an `extraProcesses` entry, or
             `migrations`. Every field is optional and falls back to the
             matching shared default at the top level of values.
  serviceAccountName
             optional; defaults to the release's ServiceAccount.

Emitted at column 0; callers indent it with nindent.
*/}}
{{- define "django.podSpec" -}}
{{- $root := .root -}}
{{- $process := .process -}}
{{- $component := .component -}}
{{- $serviceAccountName := .serviceAccountName | default (include "django.serviceAccountName" $root) -}}
{{- with $root.Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
serviceAccountName: {{ $serviceAccountName }}
{{- with $root.Values.podSecurityContext }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
containers:
  - name: {{ $component }}
    image: {{ include "django.image" $root | quote }}
    imagePullPolicy: {{ $root.Values.image.pullPolicy }}
    {{- with $process.command }}
    command:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $process.args }}
    args:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $root.Values.securityContext }}
    securityContext:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $process.ports }}
    ports:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with include "django.envFrom" $root }}
    envFrom:
      {{- . | nindent 6 }}
    {{- end }}
    {{- with include "django.env" (dict "root" $root "process" $process) }}
    env:
      {{- . | nindent 6 }}
    {{- end }}
    {{- with $process.livenessProbe }}
    livenessProbe:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $process.readinessProbe }}
    readinessProbe:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $process.startupProbe }}
    startupProbe:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with (default $root.Values.resources $process.resources) }}
    resources:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with (concat ($root.Values.volumeMounts | default list) ($process.volumeMounts | default list)) }}
    volumeMounts:
      {{- toYaml . | nindent 6 }}
    {{- end }}
{{- with (concat ($root.Values.volumes | default list) ($process.volumes | default list)) }}
volumes:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with (default $root.Values.nodeSelector $process.nodeSelector) }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with (default $root.Values.affinity $process.affinity) }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with (default $root.Values.tolerations $process.tolerations) }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Pod template metadata shared by every workload. Same dict as django.podSpec.
Emitted at column 0; callers indent it with nindent.
*/}}
{{- define "django.podMetadata" -}}
{{- $root := .root -}}
{{- $process := .process -}}
{{- $component := .component -}}
{{- $annotations := merge (dict) ($process.podAnnotations | default dict) ($root.Values.podAnnotations | default dict) -}}
{{- if $root.Values.config }}
{{- $_ := set $annotations "checksum/config" (toYaml $root.Values.config | sha256sum) -}}
{{- end }}
{{- with $annotations }}
annotations:
  {{- toYaml . | nindent 2 }}
{{- end }}
labels:
  {{- include "django.componentLabels" (dict "root" $root "component" $component) | nindent 2 }}
  {{- with (merge (dict) ($process.podLabels | default dict) ($root.Values.podLabels | default dict)) }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end }}
