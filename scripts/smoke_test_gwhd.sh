#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ -d .venv ]]; then
  source .venv/bin/activate
fi

# This assumes train_GWHD.py supports these debug arguments.
# If not, manually reduce epochs/batches in a temporary config.
python -m src.train.train_GWHD   --config configs/gwhd/baseline.yaml   --output_dir outputs/runs/smoke_test_$(date +%Y%m%d_%H%M%S)   --max_epochs 1   --limit_train_batches 2   --limit_val_batches 2
