{{- define "backend-base.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "backend-base.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "backend-base.name" . -}}
{{- end -}}
{{- end -}}

{{- define "backend-base.labels" -}}
app: {{ include "backend-base.name" . }}
app.kubernetes.io/name: {{ include "backend-base.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "backend-base.selectorLabels" -}}
app: {{ include "backend-base.name" . }}
{{- end -}}
