#!/usr/bin/env bash
set -euo pipefail

identity_file=${NXC_IDENTITY_FILE:-$HOME/.ssh/id_rsa}
export NXC_IDENTITY_FILE=$identity_file

if [[ ! -f "$identity_file" ]]; then
  echo "SSH identity not found: $identity_file" >&2
  exit 1
fi

if [[ "$identity_file" != "$HOME/.ssh/id_rsa" ]]; then
  temporary_config=$(mktemp)
  trap 'rm -f "$temporary_config"' EXIT
  sed "s|~/.ssh/id_rsa|$identity_file|" e2e/minimal-hpc.ini >"$temporary_config"
  export E2E_HPC_CONFIG=$temporary_config
fi

cd e2e
python minimal-e2e.py
