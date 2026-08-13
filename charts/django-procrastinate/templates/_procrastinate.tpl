{{/*
Turns the `procrastinate` values block into the process list the library chart
already knows how to render.

Procrastinate wired through Django has no broker and no separate schema step:
jobs live in the same Postgres the app already uses, and its tables ship as
Django migrations. So this flavour is thinner than the Celery one — it is a
worker command, a health check, and the fact that nothing else is needed.
*/}}

{{/*
The worker process, shaped exactly like an `extraProcesses` entry.
*/}}
{{- define "django-procrastinate.processes" -}}
{{- $procrastinate := .Values.procrastinate -}}
{{- $processes := list -}}

{{- if $procrastinate.worker.enabled }}
{{- $command := concat $procrastinate.manageCommand (list "procrastinate" "worker") -}}
{{- with $procrastinate.worker.queues }}
{{- $command = concat $command (list "--queues" (join "," .)) -}}
{{- end }}
{{- with $procrastinate.worker.concurrency }}
{{- $command = concat $command (list "--concurrency" (. | toString)) -}}
{{- end }}
{{- $command = concat $command ($procrastinate.worker.extraArgs | default list) -}}
{{- $worker := merge (dict) (omit $procrastinate.worker "enabled" "name" "command" "queues" "concurrency" "extraArgs") -}}
{{- $_ := set $worker "name" $procrastinate.worker.name -}}
{{- $_ := set $worker "command" (default $command $procrastinate.worker.command) -}}
{{- $processes = append $processes $worker -}}
{{- end }}

{{- with $processes }}
{{- toYaml . }}
{{- end }}
{{- end }}
