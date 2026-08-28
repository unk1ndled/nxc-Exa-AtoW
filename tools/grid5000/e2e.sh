#!/usr/bin/env bash
set -euo pipefail

workload="${1:-openqcd}"
application="${2:-$workload}"
walltime="${3:-1:00:00}"
duration="${4:-1h}"
repository_root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")
flavour="g5k-nfs-store"
composition="${workload}::${flavour}"

if command -v nix >/dev/null; then
  nix_command=$(command -v nix)
elif [[ -x "$HOME/.local/bin/nix" ]]; then
  nix_command="$HOME/.local/bin/nix"
else
  echo "Nix is unavailable; run: nxc helper install-nix" >&2
  exit 1
fi

run_in_nix_shell() {
  "$nix_command" develop --command bash -c \
    'export PATH="$PATH:$HOME/.local/bin"; exec "$@"' bash "$@"
}

if [[ ! "$workload" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "invalid workload name: $workload" >&2
  exit 2
fi
if [[ ! "$application" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "invalid application name: $application" >&2
  exit 2
fi
if [[ ! "$walltime" =~ ^[0-9]+:[0-5][0-9]:[0-5][0-9]$ ]]; then
  echo "walltime must use H:MM:SS, got: $walltime" >&2
  exit 2
fi
if [[ ! "$duration" =~ ^[1-9][0-9]*[smhd]$ ]]; then
  echo "duration must use an integer followed by s, m, h, or d, got: $duration" >&2
  exit 2
fi
for command in oarsub oardel oarstat; do
  if ! command -v "$command" >/dev/null; then
    echo "required command is unavailable: $command" >&2
    exit 1
  fi
done
if [[ ! -f "$HOME/.ssh/id_rsa" || ! -f "$HOME/.ssh/id_rsa.pub" ]]; then
  echo "Grid'5000 deployment requires $HOME/.ssh/id_rsa and id_rsa.pub" >&2
  exit 1
fi

cd "$repository_root"
echo "Building $composition"
run_in_nix_shell nxc build -f "$flavour" -C "$composition"

compose_info="build/$composition"
node_count=$(
  run_in_nix_shell jq -er --arg workload "$workload" \
    '.compositions_info[$workload].roles | length' \
    "$compose_info"
)
if (( node_count < 1 )); then
  echo "composition has no roles: $composition" >&2
  exit 1
fi

job_directory="$repository_root/deploy/g5k-jobs"
mkdir -p "$job_directory"
helper_source=$(run_in_nix_shell nxc helper g5k_script)
helper="$job_directory/nxc-g5k-script"
# The user-Nix /nix/store mount exists on the frontend but not on allocated
# production nodes. Materialize NXC's unmodified helper in the shared home.
run_in_nix_shell install -m 755 "$helper_source" "$helper"
submission=$(
  oarsub \
    -n "nxc-${workload}" \
    -l "nodes=${node_count},walltime=${walltime}" \
    -O "$job_directory/OAR.%jobid%.stdout" \
    -E "$job_directory/OAR.%jobid%.stderr" \
    "$helper $duration"
)
printf '%s\n' "$submission"
job_id=$(sed -n 's/^OAR_JOB_ID=\([0-9][0-9]*\)$/\1/p' <<<"$submission" | tail -n 1)
if [[ -z "$job_id" ]]; then
  echo "could not recover the OAR job id" >&2
  exit 1
fi

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  echo "Releasing Grid'5000 reservation $job_id"
  if ! oardel "$job_id"; then
    echo "could not release OAR job $job_id; run: oardel $job_id" >&2
    status=1
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

machine_file="$job_directory/OAR.${job_id}.stdout"
echo "Waiting for $node_count reserved nodes in $machine_file"
deadline=$((SECONDS + 900))
while (( SECONDS < deadline )); do
  if [[ -f "$machine_file" ]]; then
    reserved_nodes=$(awk 'NF { print $1 }' "$machine_file" | sort -u | wc -l)
    if (( reserved_nodes == node_count )); then
      break
    fi
  fi
  job_state=$(oarstat -s -j "$job_id" | awk -F': ' 'NR == 1 { print $2 }')
  if [[ "$job_state" == "Error" || "$job_state" == "Terminated" ]]; then
    echo "OAR job $job_id ended in state $job_state before producing its node file" >&2
    if [[ -f "$job_directory/OAR.${job_id}.stderr" ]]; then
      tail -n 80 "$job_directory/OAR.${job_id}.stderr" >&2
    fi
    exit 1
  fi
  sleep 2
done
reserved_nodes=${reserved_nodes:-0}
if (( reserved_nodes != node_count )); then
  echo "reservation produced $reserved_nodes nodes, expected $node_count" >&2
  if [[ -f "$job_directory/OAR.${job_id}.stderr" ]]; then
    tail -n 80 "$job_directory/OAR.${job_id}.stderr" >&2
  fi
  exit 1
fi

echo "Deploying $composition on OAR job $job_id"
run_in_nix_shell nxc start -C "$composition" -m "$machine_file" -W

deployment_file="$repository_root/deploy/${composition}.json"
if [[ ! -f "$deployment_file" ]]; then
  echo "NXC did not create deployment metadata: $deployment_file" >&2
  exit 1
fi

echo "Running embedded topology checks"
run_in_nix_shell nxc driver -t -d "$deployment_file"

echo "Running $application API-to-SLURM E2E"
run_in_nix_shell bash tools/grid5000/run-test.sh "$workload" "$application" "$deployment_file"
