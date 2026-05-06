# Project structure

This project is organized so that setup, training, checkpoints, logs, and copied-back results stay separate.

## Main folders

```text
configs/                 Experiment configuration files.
datasets/                Dataset download scripts, converter scripts, and local data.
datasets/data/           Local datasets. Ignored by Git.
src/models/              Model definitions.
src/train/               Training entry points.
checkpoints/pretrained/  Pretrained or starting checkpoints.
outputs/runs/            One folder per experiment run. Ignored by Git.
scripts/                 Setup and run scripts.
docs/                    Notes and runbooks.
```

## Typical droplet workflow

```bash
./scripts/setup_droplet.sh
./scripts/smoke_test_gwhd.sh
tmux new -s gwhd
./scripts/run_gwhd_experiment.sh configs/gwhd/grl.yaml
```

Each experiment should produce a self-contained folder under `outputs/runs/` containing the config, command, git commit, logs, checkpoints, and metrics.
