{{- define "minio.name" -}}
{{- printf "%s-minio" .Release.Name -}}
{{- end -}}

{{- define "minio.secretName" -}}
{{- printf "%s-minio" .Release.Name -}}
{{- end -}}

{{- define "minio.labels" -}}
app.kubernetes.io/name: minio
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: object-store
{{- end -}}
