#!/usr/bin/env bash
set -euo pipefail

workload="${1:-openqcd}"
repository_root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
identity_file=$(realpath "${NXC_IDENTITY_FILE:-$HOME/.ssh/id_rsa}")
export NXC_IDENTITY_FILE=$identity_file

if [[ ! -f "$identity_file" ]]; then
  echo "SSH identity not found: $identity_file" >&2
  exit 1
fi

if [[ -n ${E2E_HPC_CONFIG:-} ]]; then
  E2E_HPC_CONFIG=$(realpath "$E2E_HPC_CONFIG")
  export E2E_HPC_CONFIG
fi

cd "$repository_root/e2e"
python minimal-e2e.py --app "$workload"
