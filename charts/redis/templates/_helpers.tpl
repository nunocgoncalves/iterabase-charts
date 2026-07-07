{{- define "redis.name" -}}
{{- printf "%s-redis" .Release.Name -}}
{{- end -}}

{{- define "redis.labels" -}}
app.kubernetes.io/name: redis
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: cache
{{- end -}}
