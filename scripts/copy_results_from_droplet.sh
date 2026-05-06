#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: ./scripts/copy_results_from_droplet.sh USER@DROPLET_IP:/remote/project/path /local/output/path"
  echo "Example: ./scripts/copy_results_from_droplet.sh root@123.123.123.123:/root/thesis-project /mnt/c/Users/geveg/OneDrive/Desktop/thesis_experiments"
  exit 1
fi

REMOTE_PROJECT="$1"
LOCAL_OUTPUT="$2"

mkdir -p "$LOCAL_OUTPUT"
rsync -avz "$REMOTE_PROJECT/outputs/runs/" "$LOCAL_OUTPUT/"
