#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo 'Checking NVIDIA GPU...'
nvidia-smi

echo 'Checking Python...'
python3 --version

echo 'Creating virtual environment...'
python3 -m venv .venv
source .venv/bin/activate

echo 'Installing Python dependencies...'
python -m pip install --upgrade pip setuptools wheel
pip install -r requirements.txt

echo 'Checking PyTorch CUDA...'
python - <<'PY'
import torch
print('Torch version:', torch.__version__)
print('CUDA available:', torch.cuda.is_available())
if torch.cuda.is_available():
    print('GPU:', torch.cuda.get_device_name(0))
PY

echo 'Droplet setup complete.'
