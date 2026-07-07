{{- define "inference-gateway.name" -}}
{{- printf "%s-gateway" .Release.Name -}}
{{- end -}}

{{- define "inference-gateway.adminSecretName" -}}
{{- if .Values.adminApiKey.secret -}}{{- .Values.adminApiKey.secret -}}{{- else -}}{{- printf "%s-gateway-admin" .Release.Name -}}{{- end -}}
{{- end -}}

{{- define "inference-gateway.pgHost" -}}
{{- if .Values.postgresql.host -}}{{- .Values.postgresql.host -}}{{- else -}}{{- printf "%s-postgresql" .Release.Name -}}{{- end -}}
{{- end -}}

{{- define "inference-gateway.pgSecret" -}}
{{- if .Values.postgresql.passwordSecret -}}{{- .Values.postgresql.passwordSecret -}}{{- else -}}{{- printf "%s-postgresql" .Release.Name -}}{{- end -}}
{{- end -}}

{{- define "inference-gateway.redisHost" -}}
{{- if .Values.redis.host -}}{{- .Values.redis.host -}}{{- else -}}{{- printf "%s-redis" .Release.Name -}}{{- end -}}
{{- end -}}

{{- define "inference-gateway.labels" -}}
app.kubernetes.io/name: inference-gateway
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: gateway
{{- end -}}
