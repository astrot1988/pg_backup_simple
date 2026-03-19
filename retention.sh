#!/usr/bin/env bash
set -euo pipefail

: "${BACKUP_DIR:=/backups}"

shopt -s nullglob
files=("${BACKUP_DIR}"/*.sql.gz)
(( ${#files[@]} == 0 )) && exit 0

declare -A keep_map=()
declare -A seen_periods=()
declare -A limits=()
declare -A cutoffs=()

order=(hourly daily weekly monthly yearly)

parse_base() {
  local base="$1"
  local date_part time_part

  date_part="${base%%T*}"
  time_part="${base#*T}"
  printf '%s %s\n' "${date_part}" "${time_part//-/:}"
}

period_key_for_mode() {
  local iso_key="$1"
  local mode="$2"

  case "${mode}" in
    hourly)
      date -d "${iso_key}" '+%Y-%m-%dT%H'
      ;;
    daily)
      date -d "${iso_key}" '+%Y-%m-%d'
      ;;
    weekly)
      date -d "${iso_key}" '+%G-W%V'
      ;;
    monthly)
      date -d "${iso_key}" '+%Y-%m'
      ;;
    yearly)
      date -d "${iso_key}" '+%Y'
      ;;
    *)
      echo "Unknown retention mode: ${mode}" >&2
      return 1
      ;;
  esac
}

load_limit() {
  local mode="$1"
  local var_name="KEEP_${mode^^}"
  local value="${!var_name:-}"

  [[ -z "${value}" ]] && return 0
  [[ "${value}" =~ ^[0-9]+$ ]] || {
    echo "Ignoring invalid retention value for ${mode}: ${value}" >&2
    return 0
  }
  (( value == 0 )) && return 0

  limits["${mode}"]="${value}"
}

compute_cutoff() {
  local latest_iso="$1"
  local mode="$2"
  local limit="${limits[${mode}]}"

  case "${mode}" in
    hourly)
      date -d "${latest_iso} ${limit} hour ago" '+%s'
      ;;
    daily)
      date -d "${latest_iso} ${limit} day ago" '+%s'
      ;;
    weekly)
      date -d "${latest_iso} ${limit} week ago" '+%s'
      ;;
    monthly)
      date -d "${latest_iso} ${limit} month ago" '+%s'
      ;;
    yearly)
      date -d "${latest_iso} ${limit} year ago" '+%s'
      ;;
    *)
      echo "Unknown retention mode: ${mode}" >&2
      return 1
      ;;
  esac
}

for mode in "${order[@]}"; do
  load_limit "${mode}"
done

if (( ${#limits[@]} == 0 )); then
  echo "Retention disabled: keeping all backups"
  exit 0
fi

latest_base="$(basename "${files[-1]}" .sql.gz)"
latest_iso="$(parse_base "${latest_base}")"
latest_epoch="$(date -d "${latest_iso}" '+%s')"

enabled_modes=()
for mode in "${order[@]}"; do
  if [[ -n "${limits[${mode}]+x}" ]]; then
    cutoffs["${mode}"]="$(compute_cutoff "${latest_iso}" "${mode}")"
    enabled_modes+=("${mode}")
  fi
done

for (( idx=${#files[@]}-1; idx>=0; idx-- )); do
  file="${files[idx]}"
  base="$(basename "${file}" .sql.gz)"
  iso_key="$(parse_base "${base}")"
  file_epoch="$(date -d "${iso_key}" '+%s')"

  matched=0

  for (( mode_idx=0; mode_idx<${#enabled_modes[@]}; mode_idx++ )); do
    mode="${enabled_modes[${mode_idx}]}"
    cutoff_epoch="${cutoffs[${mode}]}"

    if (( file_epoch < cutoff_epoch )); then
      continue
    fi

    matched=1

    if (( mode_idx == 0 )); then
      keep_map["${file}"]=1
      break
    fi

    finer_mode="${enabled_modes[$((mode_idx - 1))]}"
    finer_cutoff_epoch="${cutoffs[${finer_mode}]}"

    if (( file_epoch >= finer_cutoff_epoch )); then
      continue
    fi

    period_key="$(period_key_for_mode "${iso_key}" "${mode}")"
    seen_key="${mode}:${period_key}"

    if [[ -z "${seen_periods[${seen_key}]+x}" ]]; then
      seen_periods["${seen_key}"]=1
      keep_map["${file}"]=1
    fi
    break
  done

  if (( matched == 0 )); then
    rm -f "${file}"
    echo "Removed old backup: ${file}"
    continue
  fi

  if [[ -z "${keep_map[${file}]+x}" ]]; then
    rm -f "${file}"
    echo "Removed old backup: ${file}"
  fi
done

exit 0
