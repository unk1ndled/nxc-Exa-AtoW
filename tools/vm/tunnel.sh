#!/usr/bin/env bash
set -euo pipefail

deployment_file="${1:-deploy/openqcd::vm.json}"

if [[ ! -f "$deployment_file" ]]; then
  echo "deployment file not found: $deployment_file" >&2
  echo "start the VM topology with 'just up' first" >&2
  exit 1
fi
deployment_file=$(realpath "$deployment_file")

identity_file=$(realpath "${NXC_IDENTITY_FILE:-$HOME/.ssh/id_rsa}")
if [[ ! -f "$identity_file" ]]; then
  echo "SSH identity not found: $identity_file" >&2
  exit 1
fi

ssh_options=(
  -q
  -o ConnectTimeout=5
  -o ExitOnForwardFailure=yes
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -i "$identity_file"
)
control_dir="/tmp/nxc-exa-atow-tunnels-${UID}"
mkdir -p "$control_dir"
chmod 0700 "$control_dir"
active_deployment_file="$control_dir/active-deployment"

active_deployment=""
if [[ -f "$active_deployment_file" ]]; then
  IFS= read -r active_deployment <"$active_deployment_file" || true
fi

# All compositions use the same three host ports. Close masters owned by this
# repository before switching to another deployment, otherwise a successful
# control-socket check could silently retain tunnels to the previous workload.
if [[ -n "$active_deployment" && "$active_deployment" != "$deployment_file" ]]; then
  for control_socket in "$control_dir"/*.sock; do
    [[ -S "$control_socket" ]] || continue
    ssh -q -S "$control_socket" -O exit root@localhost >/dev/null 2>&1 || true
    rm -f "$control_socket"
  done
  rm -f "$active_deployment_file"
fi

deployment_rows=$(jq -er '.deployment | to_entries[] | [.value.vm_id, .value.role] | @tsv' "$deployment_file")
declare -A forwarded=()

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

  control_socket="$control_dir/$role.sock"
  if [[ -S "$control_socket" ]] && ssh "${ssh_options[@]}" \
    -S "$control_socket" -O check -p "$ssh_port" root@localhost \
    >/dev/null 2>&1; then
    forwarded["$role"]=1
    echo "reuse $role tunnel on localhost:${service_port}"
    continue
  fi
  rm -f "$control_socket"

  if ssh "${ssh_options[@]}" -M -S "$control_socket" -fN -p "$ssh_port" \
    -L "127.0.0.1:${service_port}:localhost:${remote_port}" \
    root@localhost </dev/null; then
    forwarded["$role"]=1
    if [[ "$role" == frontend ]]; then
      echo "frontend SSH: localhost:${service_port}"
    else
      echo "$role API: http://localhost:${service_port}/api/v1"
    fi
  else
    echo "could not forward $role on localhost:${service_port}" >&2
  fi
done <<<"$deployment_rows"

status=0
for role in ebuffer ebservice frontend; do
  if [[ -z ${forwarded[$role]:-} ]]; then
    echo "required tunnel was not established: $role" >&2
    status=1
  fi
done

if (( status == 0 )); then
  printf '%s\n' "$deployment_file" >"$active_deployment_file"
fi
exit "$status"
