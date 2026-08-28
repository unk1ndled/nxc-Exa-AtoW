#!/usr/bin/env bash
set -euo pipefail

workload="${1:-openqcd}"
application="${2:-$workload}"
deployment_file="${3:-deploy/${workload}::g5k-nfs-store.json}"
repository_root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")

if [[ ! -f "$deployment_file" ]]; then
  echo "deployment file not found: $deployment_file" >&2
  exit 1
fi
deployment_file=$(realpath "$deployment_file")

ebuffer_ip=$(nxc helper ip ebuffer)
ebservice_ip=$(nxc helper ip ebservice)
frontend_ip=$(nxc helper ip frontend)
for endpoint in "$ebuffer_ip" "$ebservice_ip" "$frontend_ip"; do
  if [[ -z "$endpoint" ]]; then
    echo "NXC did not resolve every required G5K endpoint" >&2
    exit 1
  fi
done

export E2E_EBUFFER_URL="http://${ebuffer_ip}:8000/api/v1"
export E2E_EBSERVICE_URL="http://${ebservice_ip}:8001/api/v1"
export E2E_SSH_HOST=$frontend_ip

cd "$repository_root"
uv run --project checks/host \
  bash tools/host/run-e2e.sh "$application" g5k-direct "$deployment_file" "$workload"
