#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

remove_volumes=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --volumes)
      remove_volumes=1
      shift
      ;;
    -h|--help)
      printf 'Usage: %s [--volumes]\n' "$0"
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

require_podman
ensure_env_file >/dev/null
project="${CMANGOS_COMPOSE_PROJECT:-$(env_value PROJECT_NAME cmangos-classic)}"
label="io.podman.compose.project=$project"

removed_pods=0
for pod in "pod_$project" "pod__-$project"; do
  if podman pod exists "$pod" >/dev/null 2>&1; then
    podman pod rm -f "$pod" >/dev/null
    printf 'Removed pod %s.\n' "$pod"
    removed_pods=1
  fi
done

mapfile -t containers < <(podman ps -a --filter "label=$label" --format '{{.ID}}')
if [ "${#containers[@]}" -gt 0 ]; then
  podman rm -f "${containers[@]}" >/dev/null
  printf 'Removed remaining containers for project %s.\n' "$project"
elif [ "$removed_pods" = "0" ]; then
  printf 'No containers found for project %s.\n' "$project"
fi

network="${project}_default"
if podman network exists "$network" >/dev/null 2>&1; then
  if podman network rm "$network" >/dev/null; then
    printf 'Removed network %s.\n' "$network"
  else
    printf 'Could not remove network %s; it may still be in use.\n' "$network" >&2
  fi
fi

if [ "$remove_volumes" = "1" ]; then
  mapfile -t volumes < <(podman volume ls --filter "label=$label" --format '{{.Name}}')
  if [ "${#volumes[@]}" -gt 0 ]; then
    podman volume rm -f "${volumes[@]}" >/dev/null
    printf 'Removed volumes for project %s.\n' "$project"
  else
    printf 'No volumes found for project %s.\n' "$project"
  fi
fi
