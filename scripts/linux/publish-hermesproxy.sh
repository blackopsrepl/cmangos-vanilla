#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

image="${DOTNET_SDK_IMAGE:-mcr.microsoft.com/dotnet/sdk:6.0}"
skip_publish=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-publish)
      skip_publish=1
      shift
      ;;
    -h|--help)
      printf 'Usage: %s [--skip-publish]\n' "$0"
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

require_podman
root="$(repo_root)"
lock="$root/versions.lock"
repo="$(read_key_value "$lock" hermesproxy_repo 'https://github.com/Novivy/HermesProxy.git')"
sha="$(read_key_value "$lock" hermesproxy_sha '2c4813b4bb77309d94ac40d4702fdffa6dcbf40e')"
source_dir="$(resolve_repo_path "$(env_value HERMES_PROXY_SOURCE_DIR data/hermesproxy-src)")"
publish_dir="$(resolve_repo_path "$(env_value HERMES_PROXY_LINUX_PUBLISH_DIR data/hermesproxy-linux)")"
assert_inside_repo "$source_dir"
assert_inside_repo "$publish_dir"

if [ ! -d "$source_dir/.git" ]; then
  if [ -d "$source_dir" ] && [ -n "$(find "$source_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
    printf 'HermesProxy source directory exists but is not a git checkout: %s\n' "$source_dir" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$source_dir")"
  git clone "$repo" "$source_dir"
fi

git -C "$source_dir" fetch --tags --prune origin
if [ "$(git -C "$source_dir" rev-parse --is-shallow-repository)" = "true" ]; then
  git -C "$source_dir" fetch --unshallow --tags origin
fi
git -C "$source_dir" checkout --force "$sha"

mkdir -p "$publish_dir"
if [ "$skip_publish" = "0" ]; then
  find "$publish_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  podman run --rm \
    -v "$source_dir:/src:Z" \
    -v "$publish_dir:/out:Z" \
    -w /src/HermesProxy \
    "$image" \
    dotnet publish HermesProxy.csproj \
      --configuration Release \
      --runtime linux-x64 \
      --self-contained true \
      -p:UsePublishBuildSettings=true \
      -p:PublishSingleFile=true \
      -o /out
  chmod +x "$publish_dir/HermesProxy"
fi

test -x "$publish_dir/HermesProxy"
printf 'HermesProxy Linux publish ready: %s\n' "$publish_dir"
