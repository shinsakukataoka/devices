#!/usr/bin/env bash
#SBATCH --job-name=cache_sweep
#SBATCH --partition=cpu-dense-preempt-q
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --time=08:00:00
#SBATCH --output=cache_sweep_%j.out
#SBATCH --error=cache_sweep_%j.err
set -euo pipefail
cd /home/skataoka26/COSC_498/devices/scripts
export JOBS="${SLURM_CPUS_PER_TASK}"
bash run_cache_sweep.sh
