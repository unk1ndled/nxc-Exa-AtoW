#!/usr/bin/env bash
#SBATCH --job-name=openqcd-ym1
#SBATCH --partition=main
# OpenQCD 2.0's compiled process grid requires exactly two MPI tasks.
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:03:00
#SBATCH --output=openqcd-ym1-%j.out
#SBATCH --error=openqcd-ym1-%j.err

set -euo pipefail

submit_dir="${SLURM_SUBMIT_DIR:-$PWD}"
input_file="${1:-e2e/openqcd-ym1.in}"
if [[ "$input_file" != /* ]]; then
    input_file="$submit_dir/$input_file"
fi

if [[ ! -r "$input_file" ]]; then
    echo "OpenQCD input is not readable: $input_file" >&2
    exit 1
fi

cd "$submit_dir"
srun --mpi=pmix --nodes=2 --ntasks=2 --ntasks-per-node=1 \
    ym1 -i "$input_file" -noms

log_file="$submit_dir/openqcd-e2e.log"
test -s "$log_file"
grep -q '8x4x4x4 lattice, 4x4x4x4 local lattice' "$log_file"
grep -q '2x1x1x1 process grid' "$log_file"
test "$(grep -c '^Trajectory no ' "$log_file")" -eq 1
grep -q '^Trajectory no 1$' "$log_file"
grep -q '^Average plaquette = ' "$log_file"
grep -q '^Configuration no 1 exported' "$log_file"
test -s "$submit_dir/openqcd-e2en1"
