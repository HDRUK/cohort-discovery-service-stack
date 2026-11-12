{{- define "cohort-discovery.name" -}}
{{ .root.Release.Name }}-{{ .component }}
{{- end -}}

{{- define "cohort-discovery.labels" -}}
app.kubernetes.io/name: {{ .root.Chart.Name }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
helm.sh/chart: {{ .root.Chart.Name }}-{{ .root.Chart.Version }}
{{- end -}}

{{- define "cohort-discovery.selectorLabels" -}}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "cohort-discovery.image" -}}
{{ .repository }}:{{ .tag }}
{{- end -}}

{{- define "cohort-discovery.secretName" -}}
{{ .Release.Name }}-secrets
{{- end -}}

{{- define "cohort-discovery.secretEnv" -}}
- name: {{ .name }}
  valueFrom:
    secretKeyRef:
      name: {{ include "cohort-discovery.secretName" .root }}
      key: {{ .key }}
{{- end -}}

{{- define "cohort-discovery.apiSecretEnv" -}}
{{ include "cohort-discovery.secretEnv" (dict "root" . "name" "APP_KEY" "key" "app-key") }}
{{ include "cohort-discovery.secretEnv" (dict "root" . "name" "DB_PASSWORD" "key" "mysql-password") }}
{{ include "cohort-discovery.secretEnv" (dict "root" . "name" "JWT_SECRET" "key" "jwt-secret") }}
{{ include "cohort-discovery.secretEnv" (dict "root" . "name" "COLLECTION_HOSTS_KEY_SALT_1" "key" "collection-hosts-key-salt-1") }}
{{ include "cohort-discovery.secretEnv" (dict "root" . "name" "COLLECTION_HOSTS_KEY_SALT_2" "key" "collection-hosts-key-salt-2") }}
{{ include "cohort-discovery.secretEnv" (dict "root" . "name" "PASSPORT_PRIVATE_KEY" "key" "passport-private-key") }}
{{ include "cohort-discovery.secretEnv" (dict "root" . "name" "PASSPORT_PUBLIC_KEY" "key" "passport-public-key") }}
{{- end -}}

{{- define "cohort-discovery.waitForBootstrap" -}}
- name: wait-for-api-init
  image: {{ include "cohort-discovery.image" .Values.images.mysql }}
  imagePullPolicy: {{ .Values.imagePullPolicy }}
  command:
    - sh
    - -c
    - |
      until mysql --host="$DB_HOST" --user="$DB_USERNAME" --batch --skip-column-names \
        --execute="SELECT 1 FROM service_accounts WHERE name = '$SCHEDULER_SERVICE_ACCOUNT_NAME'" "$DB_DATABASE" 2>/dev/null | grep -q 1; do
        echo "Waiting for api-init to finish bootstrapping ${DB_DATABASE}..."
        sleep 5
      done
  env:
    - name: DB_HOST
      value: {{ include "cohort-discovery.name" (dict "root" . "component" "mysql") }}
    - name: DB_USERNAME
      value: {{ .Values.mysql.username | quote }}
    - name: DB_DATABASE
      value: {{ .Values.mysql.appDatabase | quote }}
    - name: SCHEDULER_SERVICE_ACCOUNT_NAME
      value: {{ .Values.scheduler.serviceAccountName | quote }}
    {{- include "cohort-discovery.secretEnv" (dict "root" . "name" "MYSQL_PWD" "key" "mysql-password") | nindent 4 }}
{{- end -}}
