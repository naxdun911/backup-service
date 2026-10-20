#!/usr/bin/env bash
# backup.sh: archive a source folder into a destination folder.

set -euo pipefail
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
umask 077

usage() {
    cat >&2 <<'EOF'
Usage: backup.sh [-c config] [-d days] [-k keep] [-x pattern]... [-n] [-v] <source_dir> <dest_dir>

  -c  config file path
  -d  retention days (default 7)
  -k  minimum newest archives to always keep (default 3)
  -x  exclude pattern, repeatable
  -n  dry run, change nothing
  -v  verbose output to stderr
EOF
}

die() {
    printf 'Error: %s\n' "$1" >&2
    usage
    exit 1
}

is_uint() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

# ---- Parse CLI flags. Empty means "not given". ----
cli_config=""
cli_days=""
cli_keep=""
cli_dry_run=""
cli_verbose=""
cli_excludes=()

while getopts ":c:d:k:x:nvh" opt; do
    case "$opt" in
        c) cli_config="$OPTARG" ;;
        d) cli_days="$OPTARG" ;;
        k) cli_keep="$OPTARG" ;;
        x) cli_excludes+=("$OPTARG") ;;
        n) cli_dry_run=1 ;;
        v) cli_verbose=1 ;;
        h) usage; exit 0 ;;
        \?) printf 'Unknown option: -%s\n' "$OPTARG" >&2; usage; exit 1 ;;
        :)  printf 'Option -%s needs a value\n' "$OPTARG" >&2; usage; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

# Positional args: both, or none (none means env or config supplies them).
if [[ $# -ne 0 && $# -ne 2 ]]; then
    die "expected <source_dir> <dest_dir>, or none if set in env or config"
fi

# ---- Config precedence: CLI > env > config file > defaults ----

# Snapshot env first, before defaults or the config file touch these names.
env_source="${BACKUP_SOURCE:-}"
env_dest="${BACKUP_DEST:-}"
env_days="${BACKUP_RETENTION_DAYS:-}"
env_keep="${BACKUP_KEEP_MIN:-}"

# Layer 1: defaults.
BACKUP_SOURCE=""
BACKUP_DEST=""
BACKUP_RETENTION_DAYS=7
BACKUP_KEEP_MIN=3

# Layer 2: config file.
if [[ -n "$cli_config" ]]; then
    [[ -f "$cli_config" && -r "$cli_config" ]] || die "config file not readable: $cli_config"
    # shellcheck source=/dev/null
    source "$cli_config"
fi

# Layer 3: environment.
if [[ -n "$env_source" ]]; then BACKUP_SOURCE="$env_source"; fi
if [[ -n "$env_dest" ]]; then BACKUP_DEST="$env_dest"; fi
if [[ -n "$env_days" ]]; then BACKUP_RETENTION_DAYS="$env_days"; fi
if [[ -n "$env_keep" ]]; then BACKUP_KEEP_MIN="$env_keep"; fi

# Layer 4: CLI flags and positional args.
if [[ $# -eq 2 ]]; then
    BACKUP_SOURCE="$1"
    BACKUP_DEST="$2"
fi
if [[ -n "$cli_days" ]]; then BACKUP_RETENTION_DAYS="$cli_days"; fi
if [[ -n "$cli_keep" ]]; then BACKUP_KEEP_MIN="$cli_keep"; fi

dry_run="${cli_dry_run:-0}"
verbose="${cli_verbose:-0}"

# ---- Validate the FINAL values, whichever layer they came from ----
[[ -n "$BACKUP_SOURCE" ]] || die "source_dir is not set"
[[ -n "$BACKUP_DEST" ]] || die "dest_dir is not set"
is_uint "$BACKUP_RETENTION_DAYS" || die "retention days must be a whole number, got '$BACKUP_RETENTION_DAYS'"
is_uint "$BACKUP_KEEP_MIN" || die "keep must be a whole number, got '$BACKUP_KEEP_MIN'"

# ---- Temporary debug print. Removed in commit 2. ----
printf 'source=%s\n' "$BACKUP_SOURCE"
printf 'dest=%s\n' "$BACKUP_DEST"
printf 'days=%s\n' "$BACKUP_RETENTION_DAYS"
printf 'keep=%s\n' "$BACKUP_KEEP_MIN"
printf 'dry_run=%s\n' "$dry_run"
printf 'verbose=%s\n' "$verbose"
if [[ ${#cli_excludes[@]} -gt 0 ]]; then
    for pattern in "${cli_excludes[@]}"; do
        printf 'exclude=%s\n' "$pattern"
    done
fi
