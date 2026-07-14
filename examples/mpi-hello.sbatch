#!/usr/bin/env bash
#SBATCH --job-name=mpi-hello
#SBATCH --partition=main
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --ntasks-per-node=1
#SBATCH --output=mpi-hello-%j.out

srun --mpi=pmix mpi-hello
