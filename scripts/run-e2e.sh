#!/usr/bin/env bash
set -euo pipefail

application="${1:-openqcd}"
transport="${2:-vm-tunnel}"
deployment_file="${3:-deploy/${application}::vm.json}"
expected_composition="${4:-$application}"
repository_root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")

if [[ ! -f "$deployment_file" ]]; then
  echo "deployment file not found: $deployment_file" >&2
  exit 1
fi
deployment_file=$(realpath "$deployment_file")

identity_file=$(realpath "${NXC_IDENTITY_FILE:-$HOME/.ssh/id_rsa}")
export NXC_IDENTITY_FILE=$identity_file
export NXC_DEPLOYMENT_FILE=$deployment_file
export NXC_E2E_TRANSPORT=$transport
export NXC_EXPECTED_COMPOSITION=$expected_composition

known_hosts_file=""
cleanup() {
  if [[ -n "$known_hosts_file" ]]; then
    rm -f -- "$known_hosts_file"
  fi
}
trap cleanup EXIT
if [[ "$transport" == g5k-direct ]]; then
  known_hosts_file=$(mktemp -t nxc-e2e-known-hosts.XXXXXX)
  chmod 0600 "$known_hosts_file"
  export E2E_KNOWN_HOSTS_FILE=$known_hosts_file
fi

if [[ ! -f "$identity_file" ]]; then
  echo "SSH identity not found: $identity_file" >&2
  exit 1
fi

if [[ -n ${E2E_HPC_CONFIG:-} ]]; then
  E2E_HPC_CONFIG=$(realpath "$E2E_HPC_CONFIG")
  export E2E_HPC_CONFIG
fi

cd "$repository_root/e2e"
python minimal-e2e.py --app "$application"
