# comfyui-flake

A Nix Flake for running [ComfyUI](https://github.com/Comfy-Org/ComfyUI) on Linux with direnv support.

ComfyUI Desktop does not ship Linux builds. This flake provides a reproducible, project-local setup using Nix + uv so you can run ComfyUI without polluting your system.

## Features

- **Reproducible dependencies** -- `pyproject.toml` + `uv.lock` ensure exact, lockfile-pinned installs via `uv sync`
- **Separated user data** -- models, custom_nodes, input, output, user live outside the source tree under `.comfyui-state/`, so updates are a simple source replacement
- **direnv-friendly** -- drop an `.envrc` with `use flake` and everything is ready
- **ComfyUI Manager** enabled by default

## Tested On

- NixOS 26.05.20260217.0182a36 (Yarara)
- NVIDIA RTX 4070

## Prerequisites

- [Nix](https://nixos.org/) with flakes enabled
- NVIDIA GPU + drivers (for CUDA builds)

## Quick Start

The fastest way -- one command to initialize and launch:

```bash
git clone https://github.com/vmemjp/comfyui-flake
cd comfyui-flake
nix run .
```

On the first run, this automatically sets up the venv via `uv sync`, installs dependencies, and starts ComfyUI.

### Using a dev shell (alternative)

If you prefer separate init/run steps, or use direnv:

```bash
nix develop  # or: echo 'use flake' > .envrc && direnv allow

comfyui-init  # first-time setup
comfyui       # start ComfyUI
```

ComfyUI starts at `http://127.0.0.1:8188` by default.

## Commands

| Command | Description |
|---|---|
| `nix run .` | One-command bootstrap: init if needed, then start |
| `comfyui-init` | First-time setup: copy source, create symlinks, `uv sync` dependencies (dev shell) |
| `comfyui-update` | Update ComfyUI source and re-sync dependencies (user data is untouched) (dev shell) |
| `comfyui` | Start ComfyUI (dev shell) |

## Updating ComfyUI

```bash
# 1. Update the flake input to the latest commit
nix flake update comfyui-src

# 2. Apply the update (re-enters dev shell with new derivation, then updates local source)
comfyui-update

# 3. Sync dependency changes from upstream requirements.txt
./sync-requirements.sh
```

`comfyui-update` replaces the source tree while user data (`models/`, `custom_nodes/`, `input/`, `output/`, `user/`) lives outside the source directory and is untouched.

## Configuration

All configuration is done via environment variables. Set them before running `comfyui-init` or `comfyui`.

### PyTorch CUDA Variant

The CUDA variant is configured in `pyproject.toml` (default: cu130). To change it, edit the `[[tool.uv.index]]` URL:

```toml
[[tool.uv.index]]
name = "pytorch"
url = "https://download.pytorch.org/whl/cu128"  # or cu130, cpu
explicit = true
```

Then regenerate the lockfile and re-sync:

```bash
uv lock
comfyui-init  # or: uv sync
```

### Network

```bash
COMFYUI_LISTEN=0.0.0.0 comfyui    # Listen on all interfaces
COMFYUI_PORT=9000 comfyui          # Use a different port
```

### All Variables

| Variable | Default | Description |
|---|---|---|
| `COMFYUI_STATE_DIR` | `$PWD/.comfyui-state` | Root directory for all state |
| `COMFYUI_LISTEN` | `127.0.0.1` | Listen address |
| `COMFYUI_PORT` | `8188` | Listen port |
| `COMFYUI_HOME` | `$STATE_DIR/src` | ComfyUI source directory |
| `COMFYUI_ENABLE_MANAGER` | `1` | Enable ComfyUI Manager (`0` to disable) |

## Project Structure

```
.
├── pyproject.toml          # Dependency management
├── uv.lock                 # Lockfile (committed)
├── flake.nix
├── flake.lock
└── .comfyui-state/         # Created by comfyui-init (gitignored)
    ├── src/                # ComfyUI source (replaced on update)
    │   ├── custom_nodes/ → ../custom_nodes  (symlink)
    │   ├── input/ → ../input                (symlink)
    │   ├── output/ → ../output              (symlink)
    │   ├── user/ → ../user                  (symlink)
    │   └── models/ → ../models              (symlink)
    ├── models/             # Model files
    ├── custom_nodes/       # Custom node extensions
    ├── input/              # Input images
    ├── output/             # Generated outputs
    └── user/               # User settings
```

All user data directories are symlinked from the source tree into `.comfyui-state/`.

## License

MIT
