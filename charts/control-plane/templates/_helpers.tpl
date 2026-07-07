{{- define "control-plane.name" -}}
{{- printf "%s-control-plane" .Release.Name -}}
{{- end -}}

{{- define "control-plane.managerName" -}}
{{- printf "%s-control-plane-manager" .Release.Name -}}
{{- end -}}

{{- define "control-plane.apiName" -}}
{{- printf "%s-control-plane-api" .Release.Name -}}
{{- end -}}

{{- define "control-plane.serviceAccountName" -}}
{{- printf "%s-control-plane-manager" .Release.Name -}}
{{- end -}}

{{- define "control-plane.jwtSecretName" -}}
{{- if .Values.jwt.secret -}}{{- .Values.jwt.secret -}}{{- else -}}{{- printf "%s-control-plane-jwt" .Release.Name -}}{{- end -}}
{{- end -}}

{{- define "control-plane.pgHost" -}}
{{- if .Values.postgresql.host -}}{{- .Values.postgresql.host -}}{{- else -}}{{- printf "%s-postgresql" .Release.Name -}}{{- end -}}
{{- end -}}

{{- define "control-plane.pgSecret" -}}
{{- if .Values.postgresql.passwordSecret -}}{{- .Values.postgresql.passwordSecret -}}{{- else -}}{{- printf "%s-postgresql" .Release.Name -}}{{- end -}}
{{- end -}}

{{- define "control-plane.databaseURL" -}}
postgres://{{ .Values.postgresql.auth.username }}:$(PGPASSWORD)@{{ include "control-plane.pgHost" . }}:{{ .Values.postgresql.port }}/{{ .Values.postgresql.auth.database }}?sslmode=disable
{{- end -}}

{{- define "control-plane.labels" -}}
app.kubernetes.io/name: control-plane
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
