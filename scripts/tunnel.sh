#!/usr/bin/env bash
set -euo pipefail

deployment_file="${1:-deploy/hpc::vm.json}"

if [[ ! -f "$deployment_file" ]]; then
  echo "deployment file not found: $deployment_file" >&2
  echo "start the VM topology with 'just up' first" >&2
  exit 1
fi

ssh_options=(
  -o ConnectTimeout=5
  -o ExitOnForwardFailure=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
)

while IFS=$'\t' read -r vm_id role; do
  case "$role" in
    ebuffer) service_port=8000 ;;
    ebservice) service_port=8001 ;;
    frontend) service_port=2222 ;;
    *) continue ;;
  esac

  padded_id=$(printf '%02d' "$vm_id")
  ssh_port=$(
    ps aux \
      | grep "[m]ac=52:54:00:12:01:${padded_id}" \
      | sed -nE 's/.*hostfwd=tcp::([0-9]+)-:22.*/\1/p' \
      | head -n 1 \
      || true
  )

  if [[ -z "$ssh_port" ]]; then
    echo "skip $role: VM is not running" >&2
    continue
  fi

  remote_port="$service_port"
  if [[ "$role" == frontend ]]; then
    remote_port=22
  fi

  if ssh "${ssh_options[@]}" -fN -p "$ssh_port" \
    -L "127.0.0.1:${service_port}:localhost:${remote_port}" \
    root@localhost </dev/null; then
    if [[ "$role" == frontend ]]; then
      echo "frontend SSH: localhost:${service_port}"
    else
      echo "$role API: http://localhost:${service_port}/api/v1"
    fi
  else
    echo "could not forward $role on localhost:${service_port}" >&2
  fi
done < <(
  jq -r '.deployment | to_entries[] | [.value.vm_id, .value.role] | @tsv' \
    "$deployment_file"
)
