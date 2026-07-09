{{- define "awx.name" -}}
{{- default "awx" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "awx.namespace" -}}
{{- .Values.global.namespace | default "cloud" }}
{{- end }}

{{- define "awx.image" -}}
{{- .Values.global.imageRegistry }}/{{ .Values.images.awx }}
{{- end }}

{{- define "awx.operatorImage" -}}
{{- .Values.global.imageRegistry }}/{{ .Values.images.awxOperator }}
{{- end }}

{{- define "awx.eeImage" -}}
{{- .Values.global.imageRegistry }}/{{ .Values.images.awxEE }}
{{- end }}

{{- define "awx.redisImage" -}}
{{- .Values.global.imageRegistry }}/{{ .Values.images.redis }}
{{- end }}

{{- define "awx.postgresImage" -}}
{{- .Values.global.imageRegistry }}/{{ .Values.images.postgresql }}
{{- end }}
