#!/usr/bin/env bash
#SBATCH --account=swtest
#SBATCH --partition=capella
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:1
#SBATCH --gpus-per-task=1
#SBATCH --export=HOME=/home/chwu350f,PATH=/usr/local/cuda/bin:/usr/local/bin:/usr/bin:/bin,LANG=C.UTF-8,TZ=UTC,PYTHONNOUSERSITE=1,PYTHONDONTWRITEBYTECODE=1
#SBATCH --cpus-per-task=14
#SBATCH --mem=180G
#SBATCH --time=65
#SBATCH --chdir=/tmp
#SBATCH --output=/home/h4/chwu350f/capella-audit/20261024T125511Z-cb94c9e3/slurm/recommended-S-throughput-%j.out
#SBATCH --error=/home/h4/chwu350f/capella-audit/20261024T125511Z-cb94c9e3/slurm/recommended-S-throughput-%j.err
set -euo pipefail
# Observed candidate: 12 processes/GPU; threads=1; workers=0; MPS=True
srun --ntasks=1 --cpus-per-task=14 --gres=gpu:1 --gpus-per-task=1 /usr/bin/python3 -I /home/h4/chwu350f/capella-audit/20261024T125511Z-cb94c9e3/runtime.py --payload /home/h4/chwu350f/capella-audit/20261024T125511Z-cb94c9e3 p5-S-throughput-long
