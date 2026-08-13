{{/*
Turns the `celery` values block into what the library chart already knows how
to render: a list of processes and a few env entries.

Nothing here renders a resource. That is deliberate — the flavour's whole job
is to write the boilerplate a Celery stack would otherwise repeat in every
app's values file.
*/}}

{{/*
The processes a Celery stack runs: worker, beat, flower. Emitted as a YAML list
of entries shaped exactly like `extraProcesses`, so anything an extraProcesses
entry accepts works in `celery.worker` and friends too.
*/}}
{{- define "django-celery.processes" -}}
{{- $celery := .Values.celery -}}
{{- $processes := list -}}

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
{{- $_ := set $worker "name" $celery.worker.name -}}
{{- $_ := set $worker "command" (default $command $celery.worker.command) -}}
{{- $processes = append $processes $worker -}}
{{- end }}

{{- if $celery.beat.enabled }}
{{- $command := list "celery" "-A" $celery.app "beat" "--loglevel" $celery.logLevel -}}
{{- $command = concat $command ($celery.beat.extraArgs | default list) -}}
{{- $beat := merge (dict) (omit $celery.beat "enabled" "name" "command" "extraArgs") -}}
{{- $_ := set $beat "name" $celery.beat.name -}}
{{- $_ := set $beat "command" (default $command $celery.beat.command) -}}
{{- $processes = append $processes $beat -}}
{{- end }}

{{- if $celery.flower.enabled }}
{{- $command := list "celery" "-A" $celery.app "flower" (printf "--port=%v" $celery.flower.port) -}}
{{- $command = concat $command ($celery.flower.extraArgs | default list) -}}
{{- $flower := merge (dict) (omit $celery.flower "enabled" "name" "command" "port" "extraArgs") -}}
{{- $_ := set $flower "name" $celery.flower.name -}}
{{- $_ := set $flower "command" (default $command $celery.flower.command) -}}
{{- $_ := set $flower "ports" (list (dict "name" "flower" "containerPort" ($celery.flower.port | int) "protocol" "TCP")) -}}
{{- $processes = append $processes $flower -}}
{{- end }}

{{- with $processes }}
{{- toYaml . }}
{{- end }}
{{- end }}

{{/*
Broker and result backend env, added to every process — the web pod publishes
tasks, so it needs the broker as much as the workers do.

Each is either a literal URL or a key in a Secret that already exists, matching
how the base chart consumes every other connection.
*/}}
{{- define "django-celery.env" -}}
{{- $env := list -}}
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
{{- with $env }}
{{- toYaml . }}
{{- end }}
{{- end }}
