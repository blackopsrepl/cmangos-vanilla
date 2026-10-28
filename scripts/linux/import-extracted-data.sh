#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

source_path=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --source)
      source_path="${2:-}"
      shift 2
      ;;
    -h|--help)
      printf 'Usage: %s --source PATH\n' "$0"
      printf 'PATH may be a directory, .zip, .tar, .tar.gz, or .tgz containing dbc/maps/vmaps/mmaps extracted files.\n'
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$source_path" ]; then
  printf '%s\n' '--source is required.' >&2
  exit 1
fi

if [ ! -e "$source_path" ]; then
  printf 'Source does not exist: %s\n' "$source_path" >&2
  exit 1
fi
source_path="$(realpath "$source_path")"

root="$(repo_root)"
target="$root/data/extracted"
staging="$(mktemp -d)"
cleanup() {
  rm -rf "$staging"
}
trap cleanup EXIT

if [ -d "$source_path" ]; then
  cp -a "$source_path"/. "$staging"/
else
  case "$source_path" in
    *.tar.gz|*.tgz)
      archive_kind="tar"
      ;;
    *.zip)
      archive_kind="zip"
      ;;
    *.tar)
      archive_kind="tar"
      ;;
    *)
      printf 'Unsupported source type: %s\n' "$source_path" >&2
      exit 1
      ;;
  esac
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$source_path" "$staging" "$archive_kind" <<'PY'
import os
import pathlib
import stat
import sys
import tarfile
import zipfile

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2]).resolve()
archive_kind = sys.argv[3]

def target_path(name):
    path = (target / name).resolve()
    if os.path.commonpath([str(target), str(path)]) != str(target):
        raise SystemExit(f"Unsafe archive entry path: {name}")
    return path

def check_zip_info(info):
    target_path(info.filename)
    mode = (info.external_attr >> 16) & 0o170000
    if mode == stat.S_IFLNK:
        raise SystemExit(f"Unsafe zip symlink entry: {info.filename}")

def check_tar_info(info):
    target_path(info.name)
    if info.issym() or info.islnk() or info.isdev():
        raise SystemExit(f"Unsafe tar entry type: {info.name}")

if archive_kind == "zip":
    with zipfile.ZipFile(source) as archive:
        for info in archive.infolist():
            check_zip_info(info)
        archive.extractall(target)
elif archive_kind == "tar":
    with tarfile.open(source) as archive:
        for info in archive.getmembers():
            check_tar_info(info)
        archive.extractall(target)
else:
    raise SystemExit(f"Unsupported archive kind: {archive_kind}")
PY
  else
    case "$archive_kind" in
      tar)
        tar -xf "$source_path" -C "$staging"
        ;;
      zip)
        printf 'Importing .zip requires python3 for safe extraction.\n' >&2
        exit 1
        ;;
    esac
  fi
fi

find_required_root() {
  local candidate
  if [ -z "$(missing_extracted_data "$staging" staging)" ]; then
    printf '%s\n' "$staging"
    return 0
  fi
  while IFS= read -r candidate; do
    if [ -z "$(missing_extracted_data "$candidate" staging)" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(find "$staging" -mindepth 1 -maxdepth 3 -type d)
  return 1
}

required_root="$(find_required_root)" || {
  printf 'Source must contain dbc/*.dbc, maps/*.map, vmaps/*.vmtree, and mmaps/*.mmap files.\n' >&2
  exit 1
}

mkdir -p "$target"
for dir in dbc maps vmaps mmaps; do
  rm -rf -- "${target:?}/$dir"
  cp -a "$required_root/$dir" "$target/$dir"
done

mapfile -t missing < <(missing_extracted_data "$target")
if [ "${#missing[@]}" -gt 0 ]; then
  printf 'Imported data is missing or invalid: %s\n' "${missing[*]}" >&2
  exit 1
fi

printf 'Imported extracted data into %s\n' "$target"
find "$target" -maxdepth 1 -mindepth 1 -type d -printf ' - %f\n' | sort
