{{/*
Opinionated defaults for the task frameworks Django apps usually run.

Each block renders into the same `extraProcesses` entries and env the chart
already understands — there is no separate code path, and nothing a block does
is out of reach of writing the processes by hand. `celery.enabled: true` is a
shorthand for the four or five entries an app would otherwise repeat in every
values file.

Both blocks are off by default. Turning one on is what makes this chart
"the Celery one" for that release.
*/}}

{{/*
Processes the enabled flavours contribute, as a map keyed by process name —
the same shape as extraProcesses.
*/}}
{{- define "django.flavourProcesses" -}}
{{- $processes := dict -}}

{{- if .Values.celery.enabled }}
{{- $celery := .Values.celery -}}

{{- if $celery.worker.enabled }}
{{- $command := list "celery" "-A" $celery.app "worker" "--loglevel" $celery.logLevel -}}
{{- with $celery.worker.queues }}
{{- $command = concat $command (list "--queues" (join "," .)) -}}
{{- end }}
{{- with $celery.worker.concurrency }}
{{- $command = concat $command (list "--concurrency" (. | toString)) -}}
{{- end }}
{{- $command = concat $command ($celery.worker.extraArgs | default list) -}}
{{- $worker := merge (dict) (omit $celery.worker "enabled" "name" "command" "queues" "concurrency" "extraArgs") -}}
{{- $_ := set $worker "command" (default $command $celery.worker.command) -}}
{{- $_ := set $processes $celery.worker.name $worker -}}
{{- end }}

{{- if $celery.beat.enabled }}
{{- $command := list "celery" "-A" $celery.app "beat" "--loglevel" $celery.logLevel -}}
{{- $command = concat $command ($celery.beat.extraArgs | default list) -}}
{{- $beat := merge (dict) (omit $celery.beat "enabled" "name" "command" "extraArgs") -}}
{{- $_ := set $beat "command" (default $command $celery.beat.command) -}}
{{- $_ := set $processes $celery.beat.name $beat -}}
{{- end }}

{{- if $celery.flower.enabled }}
{{- $command := list "celery" "-A" $celery.app "flower" (printf "--port=%v" $celery.flower.port) -}}
{{- $command = concat $command ($celery.flower.extraArgs | default list) -}}
{{- $flower := merge (dict) (omit $celery.flower "enabled" "name" "command" "port" "extraArgs") -}}
{{- $_ := set $flower "command" (default $command $celery.flower.command) -}}
{{- $_ := set $flower "ports" (list (dict "name" "flower" "containerPort" ($celery.flower.port | int) "protocol" "TCP")) -}}
{{- $_ := set $processes $celery.flower.name $flower -}}
{{- end }}

{{- end }}

{{- if .Values.procrastinate.enabled }}
{{- $procrastinate := .Values.procrastinate -}}
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
{{- $_ := set $worker "command" (default $command $procrastinate.worker.command) -}}
{{- $_ := set $processes $procrastinate.worker.name $worker -}}
{{- end }}
{{- end }}

{{- with $processes }}
{{- toYaml . }}
{{- end }}
{{- end }}

{{/*
Env the enabled flavours contribute to every process — the web pod publishes
tasks, so it needs the broker as much as the workers do.

Added after the database env and before the shared `env`, so a user override
always wins.
*/}}
{{- define "django.flavourEnv" -}}
{{- $env := list -}}
{{- if .Values.celery.enabled }}
{{- with .Values.celery.app }}
{{- $env = append $env (dict "name" "CELERY_APP" "value" .) -}}
{{- end }}
{{- range $connection := (list .Values.celery.broker .Values.celery.resultBackend) }}
{{- if $connection.existingSecret }}
{{- $key := required "celery broker/resultBackend existingSecretKey is required when existingSecret is set" $connection.existingSecretKey -}}
{{- $env = append $env (dict "name" $connection.envVar "valueFrom" (dict "secretKeyRef" (dict "name" $connection.existingSecret "key" $key))) -}}
{{- else if $connection.url }}
{{- $env = append $env (dict "name" $connection.envVar "value" $connection.url) -}}
{{- end }}
{{- end }}
{{- end }}
{{- with $env }}
{{- toYaml . }}
{{- end }}
{{- end }}
