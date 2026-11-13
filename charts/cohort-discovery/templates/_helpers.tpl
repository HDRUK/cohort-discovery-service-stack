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
{{- if .Values.keycloak.enabled }}
{{ include "cohort-discovery.secretEnv" (dict "root" . "name" "SSO_DEFAULT_CLIENT_SECRET" "key" "keycloak-client-secret") }}
{{- end }}
{{- end -}}

{{- define "cohort-discovery.keycloakUrl" -}}
http://localhost:{{ .Values.keycloak.port }}
{{- end -}}

{{- define "cohort-discovery.keycloakIssuer" -}}
{{ include "cohort-discovery.keycloakUrl" . }}/realms/cohort-discovery-service
{{- end -}}

{{- define "cohort-discovery.keycloakClientId" -}}
cohort-discovery-service-api
{{- end -}}

{{- define "cohort-discovery.keycloakPasswordEnvName" -}}
CDS_{{ . | snakecase | upper }}
{{- end -}}

{{- define "cohort-discovery.keycloakPasswordSecretKey" -}}
keycloak-user-{{ . | kebabcase }}
{{- end -}}

{{- define "cohort-discovery.keycloakPasswordKeys" -}}
{{- $keys := dict -}}
{{- range .Values.keycloak.users -}}
{{- $_ := set $keys (required (printf "keycloak.users: %s has no passwordKey" (.username | default .email)) .passwordKey) true -}}
{{- end -}}
{{ keys $keys | sortAlpha | toJson }}
{{- end -}}

{{- define "cohort-discovery.keycloakRealm" -}}
{{- $realm := required "keycloak.enabled needs keycloak.realmJson, the realm to import. Pass customisations/keycloak/realm.json, for example with -f generated/customisations.values.yaml from scripts/customisations-values.sh" .Values.keycloak.realmJson | fromJson -}}
{{- $groups := .Values.keycloak.groups -}}
{{- $roles := .Values.keycloak.roles -}}
{{- $defaultGroup := .Values.keycloak.defaultGroup -}}
{{- if and $defaultGroup (not (has $defaultGroup $groups)) -}}
{{- fail (printf "keycloak.defaultGroup %q is not in keycloak.groups" $defaultGroup) -}}
{{- end -}}
{{- $users := list -}}
{{- range .Values.keycloak.users -}}
{{- $email := required "keycloak.users: every user needs an email" .email -}}
{{- $username := .username | default $email -}}
{{- $groupPaths := list -}}
{{- range .groups -}}
{{- if not (has . $groups) -}}
{{- fail (printf "keycloak.users: %s is in group %q, which is not in keycloak.groups" $username .) -}}
{{- end -}}
{{- $groupPaths = append $groupPaths (printf "/%s" .) -}}
{{- end -}}
{{- if and $defaultGroup (not (has (printf "/%s" $defaultGroup) $groupPaths)) -}}
{{- $groupPaths = append $groupPaths (printf "/%s" $defaultGroup) -}}
{{- end -}}
{{- range .realmRoles -}}
{{- if not (has . $roles) -}}
{{- fail (printf "keycloak.users: %s has realm role %q, which is not in keycloak.roles" $username .) -}}
{{- end -}}
{{- end -}}
{{- $idHash := sha256sum (printf "%s/%s" $realm.realm $username) -}}
{{- $id := printf "%s-%s-%s-%s-%s" (substr 0 8 $idHash) (substr 8 12 $idHash) (substr 12 16 $idHash) (substr 16 20 $idHash) (substr 20 32 $idHash) -}}
{{- $password := printf "${%s}" (include "cohort-discovery.keycloakPasswordEnvName" .passwordKey) -}}
{{- $users = append $users (dict
  "id" $id
  "username" $username
  "email" $email
  "emailVerified" true
  "firstName" (.firstName | default "")
  "lastName" (.lastName | default "")
  "enabled" true
  "realmRoles" (.realmRoles | default list)
  "groups" $groupPaths
  "credentials" (list (dict "type" "password" "value" $password "temporary" false))
) -}}
{{- end -}}
{{- $groupEntries := list -}}
{{- range $groups -}}
{{- $groupEntries = append $groupEntries (dict "name" .) -}}
{{- end -}}
{{- $roleEntries := list -}}
{{- range $roles -}}
{{- $roleEntries = append $roleEntries (dict "name" .) -}}
{{- end -}}
{{- $_ := set $realm "groups" $groupEntries -}}
{{- $_ := set $realm "roles" (dict "realm" $roleEntries) -}}
{{- $_ := set $realm "users" $users -}}
{{- if $defaultGroup -}}
{{- $_ := set $realm "defaultGroups" (list (printf "/%s" $defaultGroup)) -}}
{{- end -}}
{{ toPrettyJson $realm }}
{{- end -}}

{{- define "cohort-discovery.urlPort" -}}
{{ required (printf "%s must include a port, for example http://localhost:8100" .name) (regexFind "[0-9]+$" (urlParse .url).host) }}
{{- end -}}

{{- define "cohort-discovery.localhostForward" -}}
- name: {{ .name }}
  image: {{ include "cohort-discovery.image" .root.Values.images.socat }}
  imagePullPolicy: {{ .root.Values.imagePullPolicy }}
  args:
    - tcp-listen:{{ .listenPort }},fork,reuseaddr
    - tcp-connect:{{ .target }}
  resources:
    {{- toYaml .root.Values.socat.resources | nindent 4 }}
{{- end -}}

{{- define "cohort-discovery.apiConfigFiles" -}}
{{- $files := dict -}}
{{- with .Values.api.authPhp }}{{ $_ := set $files "auth.php" . }}{{ end -}}
{{- with .Values.api.claimsAccessControlPhp }}{{ $_ := set $files "claimsaccesscontrol.php" . }}{{ end -}}
{{- with .Values.api.workgroupsPhp }}{{ $_ := set $files "workgroups.php" . }}{{ end -}}
{{- toJson $files -}}
{{- end -}}

{{- define "cohort-discovery.apiConfigMount" -}}
{{- range $file, $_ := include "cohort-discovery.apiConfigFiles" . | fromJson }}
- name: api-config
  mountPath: /var/www/config/{{ $file }}
  subPath: {{ $file }}
  readOnly: true
{{- end }}
{{- end -}}

{{- define "cohort-discovery.apiConfigVolume" -}}
- name: api-config
  configMap:
    name: {{ include "cohort-discovery.name" (dict "root" . "component" "api-config") }}
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
