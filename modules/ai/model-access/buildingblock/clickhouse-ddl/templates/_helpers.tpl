{{/*
The preamble both Jobs share. It defines a shell function that sends one statement to the shared
cluster as the administrative user, and it waits until the cluster answers at all.

The wait is what makes the Job usable right after the cluster was installed or restarted: a
`clickhouse-client` that cannot connect exits non-zero, and with `set -e` the Job would fail on a
server that is only a few seconds from being ready. A command in the condition of `until` does not
trip `set -e`, so the loop is the one place a failure is tolerated. Past the deadline the Job fails
with a message that names the address it tried.
*/}}
{{- define "clickhouse-ddl.preamble" -}}
set -eu

host="{{ required "clickhouse.host is required" .Values.clickhouse.host }}"
port="{{ .Values.clickhouse.nativePort }}"

run() {
  clickhouse-client --host "$host" --port "$port" \
    --user "{{ .Values.admin.username }}" --password "$ADMIN_PASSWORD" \
    --query "$1"
}

deadline=$(( $(date +%s) + {{ .Values.job.timeoutSeconds }} ))
until run "SELECT 1" > /dev/null 2>&1; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "ClickHouse at $host:$port did not answer within {{ .Values.job.timeoutSeconds }} seconds"
    exit 1
  fi
  echo "waiting for ClickHouse at $host:$port"
  sleep 5
done
{{- end -}}

{{/*
The statements that create the tenant's database and its user. Every one of them is idempotent,
because every apply of the building block runs this Job again.

The password reaches the statement as a shell variable from a secretKeyRef and is put into a quoted
SQL literal. ClickHouse replaces it with '[HIDDEN]' in its query log.
*/}}
{{- define "clickhouse-ddl.script.create" -}}
{{ include "clickhouse-ddl.preamble" . }}

database="{{ required "tenant.database is required" .Values.tenant.database }}"
username="{{ required "tenant.username is required" .Values.tenant.username }}"
cluster="{{ .Values.clickhouse.ddlCluster }}"

run "CREATE DATABASE IF NOT EXISTS $database ON CLUSTER $cluster"

run "CREATE USER IF NOT EXISTS $username ON CLUSTER $cluster IDENTIFIED WITH sha256_password BY '$TENANT_PASSWORD' DEFAULT DATABASE $database"

# CREATE USER IF NOT EXISTS leaves the password of a user that already exists as it is, so the
# password is set again here. Terraform holds the value and hands the same one to Langfuse, and
# without this statement the two would drift apart the moment the value in state is replaced.
run "ALTER USER $username ON CLUSTER $cluster IDENTIFIED WITH sha256_password BY '$TENANT_PASSWORD'"

# ON CLUSTER belongs directly after GRANT here, unlike in the statements above, where it follows the
# object the statement names. WITH REPLACE OPTION revokes everything the user held before, so the
# grants converge on this list instead of only ever growing.
run "GRANT ON CLUSTER $cluster {{ join ", " (required "tenant.grants is required" .Values.tenant.grants) }} ON $database.* TO $username WITH REPLACE OPTION"

echo "database $database and user $username are in place"
{{- end -}}

{{/*
The statements that remove the tenant again. They run as a pre-delete hook, so the database and the
user go when the building block is deleted.

SYNC makes the server wait for the tables to be gone before it answers, rather than dropping them in
the background. Without it the Job could finish while the replicated tables of the database still hold
their entries in Keeper, and a tenant recreated under the same name would meet them.
*/}}
{{- define "clickhouse-ddl.script.drop" -}}
{{ include "clickhouse-ddl.preamble" . }}

database="{{ required "tenant.database is required" .Values.tenant.database }}"
username="{{ required "tenant.username is required" .Values.tenant.username }}"
cluster="{{ .Values.clickhouse.ddlCluster }}"

run "DROP DATABASE IF EXISTS $database ON CLUSTER $cluster SYNC"
run "DROP USER IF EXISTS $username ON CLUSTER $cluster"

echo "database $database and user $username are gone"
{{- end -}}
