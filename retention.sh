#!/usr/bin/env bash
set -euo pipefail

: "${BACKUP_DIR:=/backups}"

shopt -s nullglob
files=("${BACKUP_DIR}"/*.sql.gz)
(( ${#files[@]} == 0 )) && exit 0

declare -A keep_map=()

mark_latest_for_periods() {
  local limit="$1"
  local mode="$2"
  [[ -z "${limit}" ]] && return 0
  [[ "${limit}" =~ ^[0-9]+$ ]] || {
    echo "Ignoring invalid retention value for ${mode}: ${limit}" >&2
    return 0
  }
  (( limit == 0 )) && return 0

  local -A seen=()
  local kept=0
  local file base date_part time_part iso_key period_key

  for (( idx=${#files[@]}-1; idx>=0; idx-- )); do
    file="${files[idx]}"
    base="$(basename "${file}" .sql.gz)"
    date_part="${base%%T*}"
    time_part="${base#*T}"
    iso_key="${date_part} ${time_part//-/:}"

    case "${mode}" in
      daily)
        period_key="$(date -d "${iso_key}" '+%Y-%m-%d')"
        ;;
      weekly)
        period_key="$(date -d "${iso_key}" '+%G-W%V')"
        ;;
      monthly)
        period_key="$(date -d "${iso_key}" '+%Y-%m')"
        ;;
      yearly)
        period_key="$(date -d "${iso_key}" '+%Y')"
        ;;
      *)
        echo "Unknown retention mode: ${mode}" >&2
        return 1
        ;;
    esac

    if [[ -z "${seen[${period_key}]+x}" ]]; then
      seen["${period_key}"]=1
      keep_map["${file}"]=1
      (( kept += 1 ))
      (( kept >= limit )) && break
    fi
  done
}

mark_latest_for_periods "${KEEP_DAILY:-}" daily
mark_latest_for_periods "${KEEP_WEEKLY:-}" weekly
mark_latest_for_periods "${KEEP_MONTHLY:-}" monthly
mark_latest_for_periods "${KEEP_YEARLY:-}" yearly

if [[ -z "${KEEP_DAILY:-}${KEEP_WEEKLY:-}${KEEP_MONTHLY:-}${KEEP_YEARLY:-}" ]]; then
  echo "Retention disabled: keeping all backups"
  exit 0
fi

for file in "${files[@]}"; do
  if [[ -z "${keep_map[${file}]+x}" ]]; then
    rm -f "${file}"
    echo "Removed old backup: ${file}"
  fi
done
