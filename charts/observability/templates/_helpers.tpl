{{/*
Common labels for the observability chart's own resources (not the upstream
kube-prometheus-stack / loki deps, which carry their own labels).
*/}}
{{- define "observability.labels" -}}
app.kubernetes.io/name: observability
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: iterabase-platform
helm.sh/chart: {{ printf "observability-%s" .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
The Loki Service URL for the Grafana datasource. The loki subchart (single-binary)
exposes the HTTP port on `<release>-loki`; all subcharts share the umbrella
release name.
*/}}
{{- define "observability.lokiURL" -}}
{{- printf "http://%s-loki:3100" .Release.Name -}}
{{- end -}}
