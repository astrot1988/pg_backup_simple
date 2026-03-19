#!/usr/bin/env bash
set -euo pipefail

: "${BACKUP_DIR:=/backups}"
: "${PGDUMP_EXTRA_OPTS:=}"

timestamp="$(date '+%Y-%m-%dT%H-%M-%S')"
outfile="${BACKUP_DIR}/${timestamp}.sql.gz"
tmpfile="${outfile}.tmp"

mkdir -p "${BACKUP_DIR}"

if [[ -n "${DATABASE_URL:-}" ]]; then
  pg_dump ${PGDUMP_EXTRA_OPTS} "${DATABASE_URL}" | gzip -9 >"${tmpfile}"
else
  : "${PGHOST:?PGHOST is required when DATABASE_URL is not set}"
  : "${PGPORT:=5432}"
  : "${PGDATABASE:?PGDATABASE is required when DATABASE_URL is not set}"
  : "${PGUSER:?PGUSER is required when DATABASE_URL is not set}"
  : "${PGPASSWORD:?PGPASSWORD is required when DATABASE_URL is not set}"
  export PGPASSWORD
  pg_dump ${PGDUMP_EXTRA_OPTS} \
    --host="${PGHOST}" \
    --port="${PGPORT}" \
    --username="${PGUSER}" \
    "${PGDATABASE}" | gzip -9 >"${tmpfile}"
fi

mv "${tmpfile}" "${outfile}"
echo "Backup created: ${outfile}"

/app/retention.sh
