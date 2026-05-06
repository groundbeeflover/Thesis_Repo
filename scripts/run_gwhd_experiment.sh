#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

CONFIG_PATH="${1:-configs/gwhd/baseline.yaml}"

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Config not found: $CONFIG_PATH"
  exit 1
fi

if [[ -d .venv ]]; then
  source .venv/bin/activate
fi

CONFIG_NAME="$(basename "$CONFIG_PATH" .yaml)"
RUN_DIR="outputs/runs/${CONFIG_NAME}_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$RUN_DIR/checkpoints" "$RUN_DIR/results" "$RUN_DIR/logs" "$RUN_DIR/tensorboard"

cp "$CONFIG_PATH" "$RUN_DIR/config.yaml"
(git rev-parse HEAD > "$RUN_DIR/git_commit.txt") 2>/dev/null || true
(pip freeze > "$RUN_DIR/requirements_used.txt") 2>/dev/null || true
echo "python -m src.train.train_GWHD --config $CONFIG_PATH --output_dir $RUN_DIR" > "$RUN_DIR/command.txt"

echo "Run directory: $RUN_DIR"

# This assumes train_GWHD.py supports --config and --output_dir.
# If not, update src/train/train_GWHD.py to accept these arguments,
# or replace the command below with your current training command.
python -m src.train.train_GWHD   --config "$CONFIG_PATH"   --output_dir "$RUN_DIR"   2>&1 | tee "$RUN_DIR/logs/train.log"
