{{/*
The install notes. A chart's NOTES.txt is one line calling this, optionally
with its own text before or after. Takes the root context.
*/}}
{{- define "django.notes" -}}
Thanks for installing {{ .Chart.Name }} {{ .Chart.Version }}.

Web process: {{ include "django.fullname" . }}-web ({{ .Values.web.replicas }} replica{{ if ne (int .Values.web.replicas) 1 }}s{{ end }})
{{- with .Values.extraProcesses }}
Extra processes:
{{- range . }}
  - {{ include "django.fullname" $ }}-{{ .name }} ({{ dig "replicas" 1 . }} replica{{ if ne (int (dig "replicas" 1 .)) 1 }}s{{ end }})
{{- end }}
{{- end }}

Get the application URL by running:
{{- if .Values.ingress.enabled }}
{{- range $host := .Values.ingress.hosts }}
{{- range .paths }}
  http{{ if $.Values.ingress.tls }}s{{ end }}://{{ $host.host }}{{ .path }}
{{- end }}
{{- end }}
{{- else if contains "NodePort" .Values.service.type }}
  export NODE_PORT=$(kubectl get --namespace {{ .Release.Namespace }} -o jsonpath="{.spec.ports[0].nodePort}" services {{ include "django.fullname" . }})
  export NODE_IP=$(kubectl get nodes --namespace {{ .Release.Namespace }} -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT
{{- else if contains "LoadBalancer" .Values.service.type }}
  NOTE: it may take a few minutes for the LoadBalancer IP to be available.
  export SERVICE_IP=$(kubectl get svc --namespace {{ .Release.Namespace }} {{ include "django.fullname" . }} --template "{{"{{ range (index .status.loadBalancer.ingress 0) }}{{ . }}{{ end }}"}}")
  echo http://$SERVICE_IP:{{ .Values.service.port }}
{{- else if contains "ClusterIP" .Values.service.type }}
  kubectl --namespace {{ .Release.Namespace }} port-forward svc/{{ include "django.fullname" . }} 8080:{{ .Values.service.port }}
  echo "Visit http://127.0.0.1:8080"
{{- end }}
{{- if not .Values.database.existingSecret }}

NOTE: no database is configured. Set database.existingSecret and database.host
to wire this release up to its Postgres, or provide the connection yourself
through env / existingSecrets.
{{- end }}
{{- if not .Values.migrations.enabled }}

NOTE: the migration hook is disabled. Run `python manage.py migrate` yourself
before the new code serves traffic.
{{- end }}
{{- end }}
