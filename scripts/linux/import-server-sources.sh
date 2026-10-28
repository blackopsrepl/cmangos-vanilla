#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

source_path=""
check=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --source)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        printf '%s\n' '--source requires a local directory.' >&2
        exit 1
      fi
      source_path="$2"
      shift 2
      ;;
    --check) check=1; shift ;;
    -h|--help)
      printf 'Usage: %s --source DIRECTORY | --check\n' "$0"
      printf 'Imports authorized local source trees; never downloads or overwrites sources.\n'
      exit 0
      ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

root="$(repo_root)"
if [ "$check" = 1 ]; then
  if [ -n "$source_path" ]; then
    printf '%s\n' '--check and --source are mutually exclusive.' >&2
    exit 1
  fi
  check_server_sources "$root/server"
  printf 'Local server source inputs match the pinned bases.\n'
  exit 0
fi
if [ -z "$source_path" ]; then
  printf '%s\n' 'Supply --source DIRECTORY. See docs/source-inputs.md.' >&2
  exit 1
fi
source_path="$(realpath "$source_path")"
if [ -e "$root/server" ] || [ -L "$root/server" ]; then
  printf '%s\n' 'server/ already exists; refusing to overwrite local work. Use --check to validate it.' >&2
  exit 1
fi
check_server_sources "$source_path"
staging="$(mktemp -d "$root/.server-import-XXXXXXXX")"
cleanup() {
  rm -rf -- "$staging"
}
trap cleanup EXIT
# Keep local fork modifications and notices, but not nested repository metadata.
tar -C "$source_path" --exclude=.git -cf - mangos-classic classic-db playerbots | tar -C "$staging" -xf -
check_server_sources "$staging"
# -T prevents nesting inside a server directory created by a concurrent import.
mv -T -- "$staging" "$root/server"
trap - EXIT
printf 'Local server sources imported into ignored server/. Keep these inputs and built images private.\n'
