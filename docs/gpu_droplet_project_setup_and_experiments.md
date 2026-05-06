# GPU Droplet Project Setup and Experiment Workflow

This runbook assumes you are using a GPU droplet image with NVIDIA drivers already installed. It guides you through setting up the project, verifying CUDA, preparing the GWHD dataset, running a smoke test, launching full experiments, saving results, and copying the outputs back to your local machine.

Replace the placeholder values such as `YOUR_DROPLET_IP`, `YOUR_REPO_URL`, `YOUR_BRANCH_NAME`, and `YOUR_REPO_NAME` with your actual values.

---

## 0. Local machine: define the key values

Run these commands from your local machine or WSL terminal before connecting to the droplet.

```bash
export DROPLET_IP="YOUR_DROPLET_IP"
export DROPLET_USER="root"
export REPO_URL="YOUR_REPO_URL"
export REPO_NAME="YOUR_REPO_NAME"
export LOCAL_EXPERIMENT_DIR="/mnt/c/Users/geveg/OneDrive/Desktop/thesis_experiments"
```

If you are not using WSL, adjust `LOCAL_EXPERIMENT_DIR` to a normal Windows, Linux, or macOS path.

Example WSL path:

```bash
export LOCAL_EXPERIMENT_DIR="/mnt/c/Users/geveg/OneDrive/Desktop/thesis_experiments"
```

Create the local results folder:

```bash
mkdir -p "$LOCAL_EXPERIMENT_DIR"
```

---

## 1. Local machine: SSH into the GPU droplet

```bash
ssh ${DROPLET_USER}@${DROPLET_IP}
```

Once connected, all following commands are run on the GPU droplet unless stated otherwise.

---

## 2. Droplet: basic system check

Check the operating system:

```bash
lsb_release -a || cat /etc/os-release
```

Check available disk space:

```bash
df -h
```

Check CPU and RAM:

```bash
lscpu | head
free -h
```

Check that the GPU is visible:

```bash
nvidia-smi
```

If `nvidia-smi` does not work, stop here. The GPU image is not correctly configured or the droplet does not have GPU access.

---

## 3. Droplet: install basic utilities

```bash
apt-get update
apt-get install -y git tmux htop unzip zip rsync wget curl build-essential
```

Optional but useful:

```bash
apt-get install -y tree nano
```

---

## 4. Droplet: clone the repository

```bash
cd /root

git clone "$REPO_URL"
cd "$REPO_NAME"
```

If you need a specific branch:

```bash
git checkout YOUR_BRANCH_NAME
```

Check the current commit:

```bash
git status
git rev-parse HEAD
```

---

## 5. Droplet: create the Python environment

First check what Python versions are available:

```bash
python3 --version
which python3
```

### Option A: use system Python with `venv`

Use this if the installed Python version matches your project requirements.

```bash
cd /root/$REPO_NAME
python3 -m venv .venv
source .venv/bin/activate
python --version
pip install --upgrade pip setuptools wheel
```

### Option B: use Miniconda when you need a specific Python version

Use this if your project needs an older Python version, for example Python 3.8 or 3.9.

```bash
cd /root
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
bash miniconda.sh -b -p /root/miniconda
source /root/miniconda/etc/profile.d/conda.sh
conda init bash
```

Create an environment. Adjust the Python version if needed:

```bash
conda create -y -n thesis-gpu python=3.8
conda activate thesis-gpu
python --version
pip install --upgrade pip setuptools wheel
```

Return to the repo:

```bash
cd /root/$REPO_NAME
```

---

## 6. Droplet: install project dependencies

Activate the environment first:

```bash
cd /root/$REPO_NAME
source .venv/bin/activate 2>/dev/null || conda activate thesis-gpu
```

If your repository has an install script, inspect it first:

```bash
ls -lah
find . -maxdepth 2 -iname "*install*" -o -iname "requirements*.txt" -o -iname "environment*.yml"
```

If you have a `requirements.txt` file:

```bash
pip install -r requirements.txt
```

If you have a project install script, run it only after checking its contents:

```bash
cat install.sh
chmod +x install.sh
./install.sh
```

If your repository is a Python package:

```bash
pip install -e .
```

---

## 7. Droplet: verify PyTorch and CUDA

```bash
python - <<'PY'
import torch
print("Torch version:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())
print("CUDA version used by PyTorch:", torch.version.cuda)
print("GPU count:", torch.cuda.device_count())
if torch.cuda.is_available():
    print("GPU name:", torch.cuda.get_device_name(0))
PY
```

Expected result:

```text
CUDA available: True
```

If CUDA is not available, do not start training yet.

---

## 8. Droplet: create project folders

```bash
cd /root/$REPO_NAME
mkdir -p data
mkdir -p experiments
mkdir -p logs
mkdir -p checkpoints
```

Recommended dataset location:

```bash
mkdir -p /data/GWHD
```

---

## 9. Local machine: upload the dataset to the droplet

Run this from your local machine or WSL terminal, not from inside the droplet.

Example using `rsync`:

```bash
rsync -avz --progress /path/to/local/GWHD/ ${DROPLET_USER}@${DROPLET_IP}:/data/GWHD/
```

Example if the dataset is a zip file:

```bash
scp /path/to/GWHD.zip ${DROPLET_USER}@${DROPLET_IP}:/data/GWHD.zip
```

Then SSH back into the droplet and unzip it:

```bash
ssh ${DROPLET_USER}@${DROPLET_IP}
unzip /data/GWHD.zip -d /data/GWHD
```

Check the dataset structure:

```bash
find /data/GWHD -maxdepth 3 -type f | head -50
find /data/GWHD -maxdepth 3 -type d | head -50
```

---

## 10. Droplet: configure dataset paths

Open your config file and make sure the dataset path points to the droplet path.

For example:

```bash
cd /root/$REPO_NAME
find . -maxdepth 3 -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) | sort
```

Search for old local dataset paths:

```bash
grep -R "GWHD\|dataset\|data_root\|root" -n configs . | head -100
```

If your config file contains a dataset path, update it to something like:

```yaml
dataset_root: /data/GWHD
```

Make a droplet-specific copy of the config rather than editing the original:

```bash
mkdir -p configs/droplet
cp configs/YOUR_CONFIG.yaml configs/droplet/YOUR_CONFIG_gpu.yaml
nano configs/droplet/YOUR_CONFIG_gpu.yaml
```

---

## 11. Droplet: run a tiny smoke test

Before running a full experiment, confirm that the code, dataset, CUDA, model, and validation loop work.

Use the closest command that matches your project.

### If your training script supports debug flags

```bash
python train.py \
  --config configs/droplet/YOUR_CONFIG_gpu.yaml \
  --max_epochs 1 \
  --limit_train_batches 2 \
  --limit_val_batches 2
```

### If your project uses PyTorch Lightning

```bash
python train.py \
  --config configs/droplet/YOUR_CONFIG_gpu.yaml \
  --trainer.max_epochs 1 \
  --trainer.limit_train_batches 2 \
  --trainer.limit_val_batches 2
```

### If your project does not support debug flags

Temporarily edit the config to use:

```yaml
epochs: 1
batch_size: 1
num_workers: 0
```

Then run:

```bash
python train.py --config configs/droplet/YOUR_CONFIG_gpu.yaml
```

The smoke test is successful if:

```text
1. CUDA is used.
2. The dataloader finds images and annotations.
3. At least one training batch completes.
4. At least one validation batch completes.
5. Logs/checkpoints/results are created.
```

---

## 12. Droplet: create a repeatable experiment folder

Choose a clear experiment name.

Examples:

```bash
export EXP_NAME="gwhd_baseline_seed42"
# export EXP_NAME="gwhd_grl_lambda0.1_seed42"
# export EXP_NAME="gwhd_coral_lambda0.1_seed42"
# export EXP_NAME="gwhd_irm_lambda0.1_seed42"
```

Create the folder structure:

```bash
cd /root/$REPO_NAME
mkdir -p experiments/$EXP_NAME/{checkpoints,logs,results,plots,configs}
```

Save the exact code version:

```bash
git rev-parse HEAD > experiments/$EXP_NAME/git_commit.txt
git status --short > experiments/$EXP_NAME/git_status.txt
```

Save the Python environment:

```bash
python --version > experiments/$EXP_NAME/python_version.txt
pip freeze > experiments/$EXP_NAME/requirements_used.txt
```

Save GPU information:

```bash
nvidia-smi > experiments/$EXP_NAME/gpu_info.txt
```

Save the config used for the run:

```bash
cp configs/droplet/YOUR_CONFIG_gpu.yaml experiments/$EXP_NAME/configs/config_used.yaml
```

---

## 13. Droplet: run the full experiment in `tmux`

Start a tmux session:

```bash
tmux new -s $EXP_NAME
```

Activate the Python environment inside tmux:

```bash
cd /root/$REPO_NAME
source .venv/bin/activate 2>/dev/null || conda activate thesis-gpu
```

Define the experiment name again inside tmux:

```bash
export EXP_NAME="gwhd_grl_lambda0.1_seed42"
```

Save the exact command that will be run:

```bash
cat > experiments/$EXP_NAME/command.txt <<'EOF_CMD'
python train.py \
  --config configs/droplet/YOUR_CONFIG_gpu.yaml \
  --seed 42 \
  --output_dir experiments/gwhd_grl_lambda0.1_seed42
EOF_CMD
```

Run the experiment:

```bash
python train.py \
  --config configs/droplet/YOUR_CONFIG_gpu.yaml \
  --seed 42 \
  --output_dir experiments/$EXP_NAME \
  2>&1 | tee experiments/$EXP_NAME/logs/train.log
```

Detach from tmux without stopping training:

```text
Ctrl+B, then D
```

Reattach later:

```bash
tmux attach -t $EXP_NAME
```

List tmux sessions:

```bash
tmux ls
```

---

## 14. Droplet: monitor training

Open a second SSH session and run:

```bash
watch -n 1 nvidia-smi
```

Check the training log:

```bash
tail -f /root/$REPO_NAME/experiments/$EXP_NAME/logs/train.log
```

Check output files:

```bash
find /root/$REPO_NAME/experiments/$EXP_NAME -maxdepth 3 -type f | sort
```

Check checkpoint sizes:

```bash
find /root/$REPO_NAME/experiments/$EXP_NAME -type f \( -name "*.ckpt" -o -name "*.pth" -o -name "*.pt" \) -exec ls -lh {} \;
```

---

## 15. Droplet: run validation or test evaluation after training

If validation already runs during training, this step may still be useful to evaluate the best checkpoint cleanly.

Find checkpoints:

```bash
find experiments/$EXP_NAME -type f \( -name "*.ckpt" -o -name "*.pth" -o -name "*.pt" \) | sort
```

Set the checkpoint path:

```bash
export BEST_CKPT="experiments/$EXP_NAME/checkpoints/best.ckpt"
```

Adjust this path if your project saves checkpoints somewhere else.

### Validation command template

```bash
python eval.py \
  --config experiments/$EXP_NAME/configs/config_used.yaml \
  --checkpoint "$BEST_CKPT" \
  --split val \
  --output experiments/$EXP_NAME/results/val_metrics.json \
  2>&1 | tee experiments/$EXP_NAME/logs/val_eval.log
```

### Test command template

```bash
python eval.py \
  --config experiments/$EXP_NAME/configs/config_used.yaml \
  --checkpoint "$BEST_CKPT" \
  --split test \
  --output experiments/$EXP_NAME/results/test_metrics.json \
  2>&1 | tee experiments/$EXP_NAME/logs/test_eval.log
```

If your project does not have `eval.py`, look for the correct evaluation script:

```bash
find . -maxdepth 3 -type f \( -iname "*eval*" -o -iname "*test*" -o -iname "*validate*" \)
```

---

## 16. Droplet: collect important outputs into one folder

After training and evaluation, create a compact archive.

```bash
cd /root/$REPO_NAME
mkdir -p experiments/$EXP_NAME/export
```

Copy common result files if they exist:

```bash
cp -v experiments/$EXP_NAME/git_commit.txt experiments/$EXP_NAME/export/ 2>/dev/null || true
cp -v experiments/$EXP_NAME/git_status.txt experiments/$EXP_NAME/export/ 2>/dev/null || true
cp -v experiments/$EXP_NAME/python_version.txt experiments/$EXP_NAME/export/ 2>/dev/null || true
cp -v experiments/$EXP_NAME/requirements_used.txt experiments/$EXP_NAME/export/ 2>/dev/null || true
cp -v experiments/$EXP_NAME/gpu_info.txt experiments/$EXP_NAME/export/ 2>/dev/null || true
cp -v experiments/$EXP_NAME/command.txt experiments/$EXP_NAME/export/ 2>/dev/null || true
cp -rv experiments/$EXP_NAME/configs experiments/$EXP_NAME/export/ 2>/dev/null || true
cp -rv experiments/$EXP_NAME/logs experiments/$EXP_NAME/export/ 2>/dev/null || true
cp -rv experiments/$EXP_NAME/results experiments/$EXP_NAME/export/ 2>/dev/null || true
```

Copy checkpoints:

```bash
mkdir -p experiments/$EXP_NAME/export/checkpoints
find experiments/$EXP_NAME -type f \( -name "*.ckpt" -o -name "*.pth" -o -name "*.pt" \) \
  -exec cp -v {} experiments/$EXP_NAME/export/checkpoints/ \;
```

Create a compressed archive:

```bash
tar -czvf experiments/${EXP_NAME}_export.tar.gz -C experiments/$EXP_NAME export
```

Check archive size:

```bash
ls -lh experiments/${EXP_NAME}_export.tar.gz
```

---

## 17. Local machine: copy the experiment results back

Run this from your local machine or WSL terminal.

```bash
rsync -avz --progress \
  ${DROPLET_USER}@${DROPLET_IP}:/root/${REPO_NAME}/experiments/${EXP_NAME}/ \
  ${LOCAL_EXPERIMENT_DIR}/${EXP_NAME}/
```

Or copy only the compressed export:

```bash
rsync -avz --progress \
  ${DROPLET_USER}@${DROPLET_IP}:/root/${REPO_NAME}/experiments/${EXP_NAME}_export.tar.gz \
  ${LOCAL_EXPERIMENT_DIR}/
```

Extract locally:

```bash
cd "$LOCAL_EXPERIMENT_DIR"
tar -xzvf ${EXP_NAME}_export.tar.gz -C ${EXP_NAME}_exported
```

Verify copied files:

```bash
find "$LOCAL_EXPERIMENT_DIR/$EXP_NAME" -maxdepth 3 -type f | sort | head -100
```

---

## 18. Recommended experiment commands

Use separate experiment names for each model and hyperparameter setting.

### Baseline Faster R-CNN

```bash
export EXP_NAME="gwhd_baseline_seed42"
mkdir -p experiments/$EXP_NAME/{checkpoints,logs,results,plots,configs}
cp configs/droplet/baseline_gpu.yaml experiments/$EXP_NAME/configs/config_used.yaml

git rev-parse HEAD > experiments/$EXP_NAME/git_commit.txt
pip freeze > experiments/$EXP_NAME/requirements_used.txt
nvidia-smi > experiments/$EXP_NAME/gpu_info.txt

python train.py \
  --config experiments/$EXP_NAME/configs/config_used.yaml \
  --seed 42 \
  --output_dir experiments/$EXP_NAME \
  2>&1 | tee experiments/$EXP_NAME/logs/train.log
```

### Faster R-CNN + GRL

```bash
export EXP_NAME="gwhd_grl_lambda0.1_seed42"
mkdir -p experiments/$EXP_NAME/{checkpoints,logs,results,plots,configs}
cp configs/droplet/grl_gpu.yaml experiments/$EXP_NAME/configs/config_used.yaml

git rev-parse HEAD > experiments/$EXP_NAME/git_commit.txt
pip freeze > experiments/$EXP_NAME/requirements_used.txt
nvidia-smi > experiments/$EXP_NAME/gpu_info.txt

python train.py \
  --config experiments/$EXP_NAME/configs/config_used.yaml \
  --seed 42 \
  --output_dir experiments/$EXP_NAME \
  2>&1 | tee experiments/$EXP_NAME/logs/train.log
```

### Faster R-CNN + CORAL

```bash
export EXP_NAME="gwhd_coral_lambda0.1_seed42"
mkdir -p experiments/$EXP_NAME/{checkpoints,logs,results,plots,configs}
cp configs/droplet/coral_gpu.yaml experiments/$EXP_NAME/configs/config_used.yaml

git rev-parse HEAD > experiments/$EXP_NAME/git_commit.txt
pip freeze > experiments/$EXP_NAME/requirements_used.txt
nvidia-smi > experiments/$EXP_NAME/gpu_info.txt

python train.py \
  --config experiments/$EXP_NAME/configs/config_used.yaml \
  --seed 42 \
  --output_dir experiments/$EXP_NAME \
  2>&1 | tee experiments/$EXP_NAME/logs/train.log
```

### Faster R-CNN + IRM

```bash
export EXP_NAME="gwhd_irm_lambda0.1_seed42"
mkdir -p experiments/$EXP_NAME/{checkpoints,logs,results,plots,configs}
cp configs/droplet/irm_gpu.yaml experiments/$EXP_NAME/configs/config_used.yaml

git rev-parse HEAD > experiments/$EXP_NAME/git_commit.txt
pip freeze > experiments/$EXP_NAME/requirements_used.txt
nvidia-smi > experiments/$EXP_NAME/gpu_info.txt

python train.py \
  --config experiments/$EXP_NAME/configs/config_used.yaml \
  --seed 42 \
  --output_dir experiments/$EXP_NAME \
  2>&1 | tee experiments/$EXP_NAME/logs/train.log
```

---

## 19. What to save for each experiment

Before deleting or shutting down the droplet, make sure the following files exist locally:

```text
[ ] config_used.yaml
[ ] command.txt
[ ] git_commit.txt
[ ] git_status.txt
[ ] requirements_used.txt
[ ] python_version.txt
[ ] gpu_info.txt
[ ] train.log
[ ] val_eval.log, if separate validation was run
[ ] test_eval.log, if separate test evaluation was run
[ ] metrics.csv, metrics.json, or equivalent logger output
[ ] val_metrics.json
[ ] test_metrics.json
[ ] per_domain_metrics.csv, if available
[ ] best checkpoint
[ ] last checkpoint
[ ] sample predictions or prediction JSON files, if available
```

The most important thesis artifacts are:

```text
1. Validation and test metrics.
2. Per-domain metrics.
3. Best checkpoint.
4. Training log.
5. Exact config.
6. Git commit hash.
7. Exact command used to run the experiment.
```

---

## 20. Common failure checks

### CUDA not available in PyTorch

```bash
python - <<'PY'
import torch
print(torch.__version__)
print(torch.cuda.is_available())
print(torch.version.cuda)
PY
```

If this prints `False`, your installed PyTorch version may not match the CUDA runtime.

### Batch size crash

Try a smaller batch size in the config:

```yaml
batch_size: 2
```

or:

```yaml
batch_size: 4
```

Then rerun the smoke test first.

### Dataloader worker crash

Try:

```yaml
num_workers: 0
```

If that works, increase gradually:

```yaml
num_workers: 2
num_workers: 4
```

### Out of memory

Reduce one or more of:

```yaml
batch_size: 1
image_size: smaller_value
num_workers: 0
```

Also check for other Python processes using the GPU:

```bash
nvidia-smi
ps aux | grep python
```

### Dataset path error

Search for hardcoded local paths:

```bash
grep -R "C:\\Users\|OneDrive\|Desktop\|/Users/\|/home/" -n . | head -100
```

---

## 21. Safe shutdown checklist

Only destroy the droplet after confirming that the copied files are present on your local machine.

Local verification:

```bash
find "$LOCAL_EXPERIMENT_DIR" -maxdepth 3 -type f | sort | head -100
```

Check important files:

```bash
ls -lh "$LOCAL_EXPERIMENT_DIR/$EXP_NAME"
find "$LOCAL_EXPERIMENT_DIR/$EXP_NAME" -type f \( -name "*.json" -o -name "*.csv" -o -name "*.log" -o -name "*.ckpt" -o -name "*.pth" \) -exec ls -lh {} \;
```

After this, it is safe to shut down or destroy the droplet from the cloud provider dashboard.
