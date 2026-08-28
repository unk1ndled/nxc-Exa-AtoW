#!/usr/bin/env bash
#SBATCH --job-name=mpi-hello
#SBATCH --partition=main
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:02:00
#SBATCH --output=mpi-hello.out
#SBATCH --error=mpi-hello.err

set -euo pipefail

output=$(srun --mpi=pmix --nodes=2 --ntasks=2 --ntasks-per-node=1 mpi-hello)
test "$(grep -c '^Hello from rank' <<<"$output")" -eq 2
grep -q 'rank 0 of 2' <<<"$output"
grep -q 'rank 1 of 2' <<<"$output"
printf '%s\n' "$output"
