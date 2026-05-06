#!/usr/bin/env bash
set -Eeuo pipefail

# restructure_project.sh
# Run this from the root of the thesis/project repository before moving to a GPU droplet.
#
# What this does:
#   - Creates a cleaner project structure.
#   - Moves training/model files into src/.
#   - Moves converter scripts into datasets/converters/.
#   - Moves pretrained checkpoints into checkpoints/pretrained/.
#   - Moves previous Lightning logs into outputs/runs/.
#   - Moves droplet documentation into docs/.
#   - Creates backwards-compatible root wrapper scripts for old commands.
#   - Writes useful helper scripts for setup, smoke tests, experiment runs, and result copying.
#   - Writes a practical .gitignore.
#
# Usage:
#   chmod +x restructure_project.sh
#   ./restructure_project.sh
#
# Optional:
#   ./restructure_project.sh --dry-run
#   ./restructure_project.sh --yes

DRY_RUN=0
ASSUME_YES=0

for arg in "${@:-}"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    *)
      echo "Unknown argument: $arg"
      echo "Usage: $0 [--dry-run] [--yes]"
      exit 1
      ;;
  esac
done

PROJECT_ROOT="$(pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR=".restructure_backup_${TIMESTAMP}"

say() {
  printf '\n%s\n' "$*"
}

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] $*"
  else
    echo "+ $*"
    eval "$*"
  fi
}

make_dir() {
  local dir="$1"
  run "mkdir -p \"$dir\""
}

safe_move() {
  local src="$1"
  local dst="$2"

  if [[ ! -e "$src" ]]; then
    echo "skip: $src does not exist"
    return 0
  fi

  local dst_parent
  dst_parent="$(dirname "$dst")"
  make_dir "$dst_parent"

  if [[ -e "$dst" ]]; then
    echo "skip: destination already exists: $dst"
    echo "      source left in place: $src"
    return 0
  fi

  run "mv \"$src\" \"$dst\""
}

write_file_if_missing() {
  local path="$1"
  local content="$2"

  if [[ -e "$path" ]]; then
    echo "skip: $path already exists"
    return 0
  fi

  make_dir "$(dirname "$path")"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] write $path"
  else
    printf "%s" "$content" > "$path"
    echo "+ wrote $path"
  fi
}

append_gitignore_block() {
  local path=".gitignore"
  local marker_start="# >>> thesis project structure ignore rules >>>"
  local marker_end="# <<< thesis project structure ignore rules <<<"

  local block
  block=$(cat <<'GITIGNORE'
# >>> thesis project structure ignore rules >>>

# Python
__pycache__/
*.py[cod]
*$py.class
.venv/
venv/
env/

# Local/editor files
.DS_Store
.vscode/
.idea/
.ipynb_checkpoints/

# Datasets and archives
datasets/data/
*.zip
*.tar
*.tar.gz
*.7z

# Training outputs and experiment trackers
outputs/
lightning_logs/
wandb/
mlruns/
runs/

# Model checkpoints / weights
*.ckpt
*.pt
*.pth
*.onnx

# Logs
*.log

# Restructure backups
.restructure_backup_*/

# <<< thesis project structure ignore rules <<<
GITIGNORE
)

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] ensure .gitignore contains thesis ignore block"
    return 0
  fi

  touch "$path"
  if grep -qF "$marker_start" "$path"; then
    echo "skip: .gitignore already contains thesis ignore block"
  else
    printf "\n%s\n" "$block" >> "$path"
    echo "+ updated .gitignore"
  fi
}

require_project_root() {
  if [[ ! -f "requirements.txt" ]]; then
    echo "Error: requirements.txt not found. Run this script from the project root."
    exit 1
  fi

  if [[ ! -d "datasets" ]]; then
    echo "Error: datasets/ not found. Run this script from the project root."
    exit 1
  fi
}

confirm() {
  if [[ "$DRY_RUN" -eq 1 || "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi

  cat <<MSG
This will reorganize files under:
  $PROJECT_ROOT

A small backup folder will be created first:
  $BACKUP_DIR

Existing destination files will not be overwritten.
MSG

  read -r -p "Continue? [y/N] " answer
  case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 0 ;;
  esac
}

create_backup_snapshot() {
  say "Creating lightweight backup snapshot"
  make_dir "$BACKUP_DIR"

  # Back up only small source/config/docs files, not datasets/images/checkpoints/logs.
  local files_to_backup=(
    "README.md"
    "requirements.txt"
    "fasterrcnn.py"
    "train_GWHD.py"
    "train_DA.py"
    "train_BSC.py"
    "train_Cityscapes.py"
    "gpu_droplet_project_setup_and_experiments.md"
    ".gitignore"
  )

  for f in "${files_to_backup[@]}"; do
    if [[ -f "$f" ]]; then
      make_dir "$BACKUP_DIR/$(dirname "$f")"
      run "cp \"$f\" \"$BACKUP_DIR/$f\""
    fi
  done

  if [[ -d "datasets" ]]; then
    make_dir "$BACKUP_DIR/datasets"
    for f in datasets/*.py datasets/*.sh datasets/readme.md; do
      if [[ -f "$f" ]]; then
        make_dir "$BACKUP_DIR/$(dirname "$f")"
        run "cp \"$f\" \"$BACKUP_DIR/$f\""
      fi
    done
  fi
}

write_python_wrappers() {
  say "Creating backwards-compatible root Python wrappers"

  write_file_if_missing "train_GWHD.py" "#!/usr/bin/env python3
from src.train.train_GWHD import *

if __name__ == '__main__':
    try:
        main()
    except NameError as exc:
        raise SystemExit('src.train.train_GWHD does not expose a main() function yet. Run with: python -m src.train.train_GWHD') from exc
"

  write_file_if_missing "train_DA.py" "#!/usr/bin/env python3
from src.train.train_DA import *

if __name__ == '__main__':
    try:
        main()
    except NameError as exc:
        raise SystemExit('src.train.train_DA does not expose a main() function yet. Run with: python -m src.train.train_DA') from exc
"

  write_file_if_missing "train_BSC.py" "#!/usr/bin/env python3
from src.train.train_BSC import *

if __name__ == '__main__':
    try:
        main()
    except NameError as exc:
        raise SystemExit('src.train.train_BSC does not expose a main() function yet. Run with: python -m src.train.train_BSC') from exc
"

  write_file_if_missing "train_Cityscapes.py" "#!/usr/bin/env python3
from src.train.train_Cityscapes import *

if __name__ == '__main__':
    try:
        main()
    except NameError as exc:
        raise SystemExit('src.train.train_Cityscapes does not expose a main() function yet. Run with: python -m src.train.train_Cityscapes') from exc
"

  write_file_if_missing "fasterrcnn.py" "# Backwards-compatible import shim.
# Prefer importing from src.models.fasterrcnn in new code.
from src.models.fasterrcnn import *
"
}

write_config_templates() {
  say "Creating config templates"

  write_file_if_missing "configs/gwhd/baseline.yaml" "experiment_name: gwhd_baseline_seed42

paths:
  dataset_root: datasets/data/gwhd_2021
  image_dir: datasets/data/gwhd_2021/images
  train_csv: datasets/data/gwhd_2021/competition_train.csv
  val_csv: datasets/data/gwhd_2021/competition_val.csv
  test_csv: datasets/data/gwhd_2021/competition_test.csv
  metadata_csv: datasets/data/gwhd_2021/metadata_dataset.csv
  pretrained_checkpoint: checkpoints/pretrained/gwhd_best_prop.ckpt
  output_root: outputs/runs

model:
  name: fasterrcnn

training:
  seed: 42
  epochs: 50
  batch_size: 4
  learning_rate: 0.0001
  num_workers: 4

domain_generalization:
  method: none
  lambda: 0.0
"

  write_file_if_missing "configs/gwhd/grl.yaml" "experiment_name: gwhd_grl_lambda0.1_seed42

paths:
  dataset_root: datasets/data/gwhd_2021
  image_dir: datasets/data/gwhd_2021/images
  train_csv: datasets/data/gwhd_2021/competition_train.csv
  val_csv: datasets/data/gwhd_2021/competition_val.csv
  test_csv: datasets/data/gwhd_2021/competition_test.csv
  metadata_csv: datasets/data/gwhd_2021/metadata_dataset.csv
  pretrained_checkpoint: checkpoints/pretrained/gwhd_best_prop.ckpt
  output_root: outputs/runs

model:
  name: fasterrcnn

training:
  seed: 42
  epochs: 50
  batch_size: 4
  learning_rate: 0.0001
  num_workers: 4

domain_generalization:
  method: grl
  lambda: 0.1
"

  write_file_if_missing "configs/gwhd/coral.yaml" "experiment_name: gwhd_coral_lambda0.1_seed42

paths:
  dataset_root: datasets/data/gwhd_2021
  image_dir: datasets/data/gwhd_2021/images
  train_csv: datasets/data/gwhd_2021/competition_train.csv
  val_csv: datasets/data/gwhd_2021/competition_val.csv
  test_csv: datasets/data/gwhd_2021/competition_test.csv
  metadata_csv: datasets/data/gwhd_2021/metadata_dataset.csv
  pretrained_checkpoint: checkpoints/pretrained/gwhd_best_prop.ckpt
  output_root: outputs/runs

model:
  name: fasterrcnn

training:
  seed: 42
  epochs: 50
  batch_size: 4
  learning_rate: 0.0001
  num_workers: 4

domain_generalization:
  method: coral
  lambda: 0.1
"

  write_file_if_missing "configs/gwhd/irm.yaml" "experiment_name: gwhd_irm_lambda0.1_seed42

paths:
  dataset_root: datasets/data/gwhd_2021
  image_dir: datasets/data/gwhd_2021/images
  train_csv: datasets/data/gwhd_2021/competition_train.csv
  val_csv: datasets/data/gwhd_2021/competition_val.csv
  test_csv: datasets/data/gwhd_2021/competition_test.csv
  metadata_csv: datasets/data/gwhd_2021/metadata_dataset.csv
  pretrained_checkpoint: checkpoints/pretrained/gwhd_best_prop.ckpt
  output_root: outputs/runs

model:
  name: fasterrcnn

training:
  seed: 42
  epochs: 50
  batch_size: 4
  learning_rate: 0.0001
  num_workers: 4

domain_generalization:
  method: irm
  lambda: 0.1
"
}

write_helper_scripts() {
  say "Creating helper scripts"

  write_file_if_missing "scripts/setup_droplet.sh" "#!/usr/bin/env bash
set -Eeuo pipefail

cd \"\$(dirname \"\${BASH_SOURCE[0]}\")/..\"

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
"

  write_file_if_missing "scripts/run_gwhd_experiment.sh" "#!/usr/bin/env bash
set -Eeuo pipefail

cd \"\$(dirname \"\${BASH_SOURCE[0]}\")/..\"

CONFIG_PATH=\"\${1:-configs/gwhd/baseline.yaml}\"

if [[ ! -f \"\$CONFIG_PATH\" ]]; then
  echo \"Config not found: \$CONFIG_PATH\"
  exit 1
fi

if [[ -d .venv ]]; then
  source .venv/bin/activate
fi

CONFIG_NAME=\"\$(basename \"\$CONFIG_PATH\" .yaml)\"
RUN_DIR=\"outputs/runs/\${CONFIG_NAME}_\$(date +%Y%m%d_%H%M%S)\"

mkdir -p \"\$RUN_DIR/checkpoints\" \"\$RUN_DIR/results\" \"\$RUN_DIR/logs\" \"\$RUN_DIR/tensorboard\"

cp \"\$CONFIG_PATH\" \"\$RUN_DIR/config.yaml\"
(git rev-parse HEAD > \"\$RUN_DIR/git_commit.txt\") 2>/dev/null || true
(pip freeze > \"\$RUN_DIR/requirements_used.txt\") 2>/dev/null || true
echo \"python -m src.train.train_GWHD --config \$CONFIG_PATH --output_dir \$RUN_DIR\" > \"\$RUN_DIR/command.txt\"

echo \"Run directory: \$RUN_DIR\"

# This assumes train_GWHD.py supports --config and --output_dir.
# If not, update src/train/train_GWHD.py to accept these arguments,
# or replace the command below with your current training command.
python -m src.train.train_GWHD \
  --config \"\$CONFIG_PATH\" \
  --output_dir \"\$RUN_DIR\" \
  2>&1 | tee \"\$RUN_DIR/logs/train.log\"
"

  write_file_if_missing "scripts/smoke_test_gwhd.sh" "#!/usr/bin/env bash
set -Eeuo pipefail

cd \"\$(dirname \"\${BASH_SOURCE[0]}\")/..\"

if [[ -d .venv ]]; then
  source .venv/bin/activate
fi

# This assumes train_GWHD.py supports these debug arguments.
# If not, manually reduce epochs/batches in a temporary config.
python -m src.train.train_GWHD \
  --config configs/gwhd/baseline.yaml \
  --output_dir outputs/runs/smoke_test_\$(date +%Y%m%d_%H%M%S) \
  --max_epochs 1 \
  --limit_train_batches 2 \
  --limit_val_batches 2
"

  write_file_if_missing "scripts/copy_results_from_droplet.sh" "#!/usr/bin/env bash
set -Eeuo pipefail

if [[ \$# -lt 2 ]]; then
  echo \"Usage: ./scripts/copy_results_from_droplet.sh USER@DROPLET_IP:/remote/project/path /local/output/path\"
  echo \"Example: ./scripts/copy_results_from_droplet.sh root@123.123.123.123:/root/thesis-project /mnt/c/Users/geveg/OneDrive/Desktop/thesis_experiments\"
  exit 1
fi

REMOTE_PROJECT=\"\$1\"
LOCAL_OUTPUT=\"\$2\"

mkdir -p \"\$LOCAL_OUTPUT\"
rsync -avz \"\$REMOTE_PROJECT/outputs/runs/\" \"\$LOCAL_OUTPUT/\"
"

  if [[ "$DRY_RUN" -eq 0 ]]; then
    chmod +x scripts/*.sh || true
  fi
}

write_docs_note() {
  say "Creating docs note"

  write_file_if_missing "docs/project_structure.md" "# Project structure

This project is organized so that setup, training, checkpoints, logs, and copied-back results stay separate.

## Main folders

\`\`\`text
configs/                 Experiment configuration files.
datasets/                Dataset download scripts, converter scripts, and local data.
datasets/data/           Local datasets. Ignored by Git.
src/models/              Model definitions.
src/train/               Training entry points.
checkpoints/pretrained/  Pretrained or starting checkpoints.
outputs/runs/            One folder per experiment run. Ignored by Git.
scripts/                 Setup and run scripts.
docs/                    Notes and runbooks.
\`\`\`

## Typical droplet workflow

\`\`\`bash
./scripts/setup_droplet.sh
./scripts/smoke_test_gwhd.sh
tmux new -s gwhd
./scripts/run_gwhd_experiment.sh configs/gwhd/grl.yaml
\`\`\`

Each experiment should produce a self-contained folder under \`outputs/runs/\` containing the config, command, git commit, logs, checkpoints, and metrics.
"
}

print_planned_structure() {
  cat <<'TREE'
.
├── configs
│   └── gwhd
│       ├── baseline.yaml
│       ├── coral.yaml
│       ├── grl.yaml
│       └── irm.yaml
├── checkpoints
│   └── pretrained
│       └── gwhd_best_prop.ckpt
├── datasets
│   ├── converters
│   │   ├── json2csv_bdd100k_full.py
│   │   ├── json2csv_cityscapes.py
│   │   ├── json2csv_cityscapes_refined.py
│   │   └── xml2csv_sim10k.py
│   ├── data
│   │   └── gwhd_2021
│   │       ├── competition_test.csv
│   │       ├── competition_train.csv
│   │       ├── competition_val.csv
│   │       ├── metadata_dataset.csv
│   │       └── images/   # preserved in place, ignored by Git
│   ├── download.sh
│   ├── readme.md
│   └── to_csv_conversion.sh
├── docs
│   ├── gpu_droplet_project_setup_and_experiments.md
│   └── project_structure.md
├── outputs
│   ├── checkpoints
│   ├── logs
│   ├── results
│   └── runs
│       └── lightning_logs_old_TIMESTAMP
├── scripts
│   ├── copy_results_from_droplet.sh
│   ├── run_gwhd_experiment.sh
│   ├── setup_droplet.sh
│   └── smoke_test_gwhd.sh
├── src
│   ├── __init__.py
│   ├── models
│   │   ├── __init__.py
│   │   └── fasterrcnn.py
│   └── train
│       ├── __init__.py
│       ├── train_BSC.py
│       ├── train_Cityscapes.py
│       ├── train_DA.py
│       └── train_GWHD.py
├── train_BSC.py          # wrapper
├── train_Cityscapes.py   # wrapper
├── train_DA.py           # wrapper
├── train_GWHD.py         # wrapper
├── fasterrcnn.py         # import shim
├── .gitignore
├── README.md
├── requirements.txt
└── restructure_project.sh
TREE
}

main() {
  require_project_root
  confirm

  say "Creating target folders"
  make_dir "src/models"
  make_dir "src/train"
  make_dir "datasets/converters"
  make_dir "configs/gwhd"
  make_dir "checkpoints/pretrained"
  make_dir "outputs/runs"
  make_dir "outputs/logs"
  make_dir "outputs/checkpoints"
  make_dir "outputs/results"
  make_dir "docs"
  make_dir "scripts"

  create_backup_snapshot

  say "Moving model and training files"
  safe_move "fasterrcnn.py" "src/models/fasterrcnn.py"
  safe_move "train_GWHD.py" "src/train/train_GWHD.py"
  safe_move "train_DA.py" "src/train/train_DA.py"
  safe_move "train_BSC.py" "src/train/train_BSC.py"
  safe_move "train_Cityscapes.py" "src/train/train_Cityscapes.py"

  say "Moving dataset converter scripts"
  safe_move "datasets/json2csv_bdd100k_full.py" "datasets/converters/json2csv_bdd100k_full.py"
  safe_move "datasets/json2csv_cityscapes.py" "datasets/converters/json2csv_cityscapes.py"
  safe_move "datasets/json2csv_cityscapes_refined.py" "datasets/converters/json2csv_cityscapes_refined.py"
  safe_move "datasets/xml2csv_sim10k.py" "datasets/converters/xml2csv_sim10k.py"

  say "Moving docs, checkpoints, and previous logs"
  safe_move "gpu_droplet_project_setup_and_experiments.md" "docs/gpu_droplet_project_setup_and_experiments.md"
  safe_move "GWHD/best_prop.ckpt" "checkpoints/pretrained/gwhd_best_prop.ckpt"
  safe_move "lightning_logs" "outputs/runs/lightning_logs_old_${TIMESTAMP}"

  say "Removing Python cache folders"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] find . -type d -name __pycache__ -prune -exec rm -rf {} +"
  else
    find . -type d -name __pycache__ -prune -exec rm -rf {} +
    echo "+ removed __pycache__ folders"
  fi

  say "Creating Python package markers"
  write_file_if_missing "src/__init__.py" ""
  write_file_if_missing "src/models/__init__.py" ""
  write_file_if_missing "src/train/__init__.py" ""

  write_python_wrappers
  write_config_templates
  write_helper_scripts
  write_docs_note
  append_gitignore_block

  if [[ "$DRY_RUN" -eq 1 ]]; then
    say "Planned structure preview after applying changes"
    print_planned_structure
    say "Current structure was not changed because this was a dry run"
  else
    say "Final structure preview"
    if command -v tree >/dev/null 2>&1; then
      tree -a -L 4 -I '.git|.venv|__pycache__|*.zip'
    else
      find . -maxdepth 4 \
        -not -path './.git*' \
        -not -path './.venv*' \
        -not -path './__pycache__*' \
        | sort
    fi
  fi

  say "Done"
  cat <<MSG
Next steps:
  1. Inspect the moved files.
  2. Run: python train_GWHD.py --help
  3. If your training file does not support --config yet, update src/train/train_GWHD.py before using scripts/run_gwhd_experiment.sh.
  4. Commit the cleaned structure before creating the GPU droplet.

Suggested Git commands:
  git status
  git add .
  git commit -m "Clean project structure and add droplet scripts"
MSG
}

main
