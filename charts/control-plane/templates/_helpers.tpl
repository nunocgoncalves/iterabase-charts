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
{{- $ssl := "disable" -}}
{{- if (or .Values.tls.enabled (dig "internalTLS" "enabled" false (.Values.global | default (dict)))) -}}{{- $ssl = printf "verify-full&sslrootcert=%s" .Values.tls.caMountPath -}}{{- end -}}
postgres://{{ .Values.postgresql.auth.username }}:$(PGPASSWORD)@{{ include "control-plane.pgHost" . }}:{{ .Values.postgresql.port }}/{{ .Values.postgresql.auth.database }}?sslmode={{ $ssl }}
{{- end -}}

{{- define "control-plane.apiTLSSecretName" -}}
{{- printf "%s-control-plane-api-tls" .Release.Name -}}
{{- end -}}

{{- /* The internal CA root Secret name. Local override -> global -> the
     <release>-internal-ca-root convention (what cert-issuers creates), so the
     overlay never hardcodes the release name. */ -}}
{{- define "control-plane.tlsCASecretName" -}}
{{- .Values.tls.caSecretName | default (dig "internalTLS" "caSecretName" "" (.Values.global | default (dict))) | default (printf "%s-internal-ca-root" .Release.Name) -}}
{{- end -}}

{{- define "control-plane.labels" -}}
app.kubernetes.io/name: control-plane
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
