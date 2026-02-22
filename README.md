# comfyui-nix

A Nix Flake for running [ComfyUI](https://github.com/Comfy-Org/ComfyUI) on Linux with direnv support.

ComfyUI Desktop does not ship Linux builds. This flake provides a reproducible, project-local setup using Nix + uv so you can run ComfyUI without polluting your system.

## Features

- **Project-local state** -- all runtime data (source, venv, models, custom nodes) stays under `.comfyui-state/`
- **Python version switching** -- Python 3.13 (default) or 3.12 via environment variable
- **PyTorch CUDA variant selection** -- cu130 (default), cu128 (Blackwell), or cpu
- **direnv-friendly** -- drop an `.envrc` with `use flake` and everything is ready
- **ComfyUI Manager** enabled by default

## Tested On

- NixOS 26.05.20260217.0182a36 (Yarara)
- NVIDIA RTX 4070

## Prerequisites

- [Nix](https://nixos.org/) with flakes enabled
- NVIDIA GPU + drivers (for CUDA builds)

## Quick Start

```bash
git clone https://github.com/vmemjp/comfyui-nix
cd comfyui-nix

# Enter the dev shell
nix develop  # or use direnv: echo 'use flake' > .envrc && direnv allow

# Initialize (downloads ComfyUI source, creates venv, installs dependencies)
comfyui-init

# Run
comfyui
```

ComfyUI starts at `http://127.0.0.1:8188` by default.

## Commands

| Command | Description |
|---|---|
| `comfyui-init` | First-time setup: copy source, create venv, install dependencies |
| `comfyui-update` | Update ComfyUI source and reinstall dependencies (preserves models, custom nodes, outputs) |
| `comfyui` | Start ComfyUI |

## Updating ComfyUI

```bash
# 1. Update the flake input to the latest commit
nix flake update comfyui-src

# 2. Apply the update (re-enters dev shell with new derivation, then updates local source)
comfyui-update
```

`comfyui-update` preserves user data directories (`models/`, `custom_nodes/`, `input/`, `output/`, `user/`) while replacing the ComfyUI source.

## Configuration

All configuration is done via environment variables. Set them before running `comfyui-init` or `comfyui`.

### Python Version

```bash
COMFYUI_PYTHON=3.12 comfyui-init   # Use Python 3.12 instead of 3.13
```

Separate venvs are created per Python version (`venv-py3.13`, `venv-py3.12`).

### PyTorch CUDA Variant

```bash
COMFYUI_TORCH_VARIANT=cu128 comfyui-init  # For RTX 50-series (Blackwell)
COMFYUI_TORCH_VARIANT=cpu comfyui-init     # CPU-only, no CUDA
```

| Value | GPU |
|---|---|
| `cu130` (default) | NVIDIA (RTX 40-series and older) |
| `cu128` | NVIDIA RTX 50-series (Blackwell) |
| `cpu` | No GPU |

### Network

```bash
COMFYUI_LISTEN=0.0.0.0 comfyui    # Listen on all interfaces
COMFYUI_PORT=9000 comfyui          # Use a different port
```

### All Variables

| Variable | Default | Description |
|---|---|---|
| `COMFYUI_STATE_DIR` | `$PWD/.comfyui-state` | Root directory for all state |
| `COMFYUI_PYTHON` | `3.13` | Python version (`3.13` or `3.12`) |
| `COMFYUI_TORCH_VARIANT` | `cu130` | PyTorch index variant (`cu130`, `cu128`, `cpu`) |
| `COMFYUI_LISTEN` | `127.0.0.1` | Listen address |
| `COMFYUI_PORT` | `8188` | Listen port |
| `COMFYUI_HOME` | `$STATE_DIR/src` | ComfyUI source directory |
| `COMFYUI_VENV` | `$STATE_DIR/venv-py$VER` | venv directory |
| `COMFYUI_ENABLE_MANAGER` | `1` | Enable ComfyUI Manager (`0` to disable) |

## Project Structure

```
.
├── flake.nix
├── flake.lock
└── .comfyui-state/          # Created by comfyui-init (gitignored)
    ├── src/                  # ComfyUI source (writable copy)
    │   ├── models/           # Model files
    │   ├── custom_nodes/     # Custom node extensions
    │   ├── input/            # Input images
    │   ├── output/           # Generated outputs
    │   └── ...
    └── venv-py3.13/          # Python virtual environment
```

## License

MIT
