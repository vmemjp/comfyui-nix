{
  description = "ComfyUI dev env (direnv-friendly; uv; project-local state; py3.13 default w/ 3.12 switch)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    comfyui-src.url = "github:Comfy-Org/ComfyUI";
    comfyui-src.flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, comfyui-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        python312 = pkgs.python312;
        python313 = pkgs.python313;
        uv = pkgs.uv;

        # 起動や依存ビルドに必要になりがちなツール
        basePkgs = with pkgs; [
          uv
          python312
          python313
          git
          ffmpeg

          cmake
          ninja
          pkg-config
          stdenv.cc
          stdenv.cc.cc.lib
          zlib
          openssl
          libffi
          glib
          libGL
        ];

        comfyui-init = pkgs.writeShellApplication {
          name = "comfyui-init";
          runtimeInputs = basePkgs;
          text = ''
            set -euo pipefail

            # 既定: プロジェクト配下に状態を閉じる
            STATE_DIR="''${COMFYUI_STATE_DIR:-$PWD/.comfyui-state}"

            COMFYUI_PYTHON="''${COMFYUI_PYTHON:-3.13}"
            case "$COMFYUI_PYTHON" in
              3.13) PY_BIN="${python313}/bin/python" ;;
              3.12) PY_BIN="${python312}/bin/python" ;;
              *)
                echo "Unsupported COMFYUI_PYTHON=$COMFYUI_PYTHON (use 3.13 or 3.12)"
                exit 2
                ;;
            esac

            COMFYUI_HOME="''${COMFYUI_HOME:-$STATE_DIR/src}"
            VENV_DIR="''${COMFYUI_VENV:-$STATE_DIR/venv-py$COMFYUI_PYTHON}"

            mkdir -p "$STATE_DIR"

            # ComfyUI 本体を state dir に展開（store は書けない）
            if [ ! -d "$COMFYUI_HOME" ]; then
              mkdir -p "$(dirname "$COMFYUI_HOME")"
              cp -a "${comfyui-src}" "$COMFYUI_HOME"
              chmod -R u+rwX "$COMFYUI_HOME" || true
            fi

            cd "$COMFYUI_HOME"

            # venv
            if [ ! -d "$VENV_DIR" ]; then
              mkdir -p "$(dirname "$VENV_DIR")"
              uv venv "$VENV_DIR" --python "$PY_BIN"
            fi

            # PyTorch の CUDA ビルドを指定 (cu130, cu128, cpu など)
            TORCH_INDEX="https://download.pytorch.org/whl/''${COMFYUI_TORCH_VARIANT:-cu130}"

            # 依存投入
            uv pip install --python "$VENV_DIR/bin/python" \
              --extra-index-url "$TORCH_INDEX" \
              --requirements requirements.txt

            # 任意: Manager
            if [ "''${COMFYUI_ENABLE_MANAGER:-1}" = "1" ] && [ -f manager_requirements.txt ]; then
              uv pip install --python "$VENV_DIR/bin/python" \
                --extra-index-url "$TORCH_INDEX" \
                --requirements manager_requirements.txt
            fi

            echo "ComfyUI ready."
            echo "  Source: $COMFYUI_HOME"
            echo "  Venv:   $VENV_DIR"
          '';
        };

        comfyui-update = pkgs.writeShellApplication {
          name = "comfyui-update";
          runtimeInputs = basePkgs;
          text = ''
            set -euo pipefail

            STATE_DIR="''${COMFYUI_STATE_DIR:-$PWD/.comfyui-state}"
            COMFYUI_PYTHON="''${COMFYUI_PYTHON:-3.13}"

            COMFYUI_HOME="''${COMFYUI_HOME:-$STATE_DIR/src}"
            VENV_DIR="''${COMFYUI_VENV:-$STATE_DIR/venv-py$COMFYUI_PYTHON}"

            if [ ! -d "$COMFYUI_HOME" ]; then
              echo "ComfyUI not found. Run: comfyui-init"
              exit 1
            fi

            # ユーザデータを保持するディレクトリ
            USER_DIRS=(models custom_nodes input output user)

            echo "Updating ComfyUI source..."

            # ユーザデータを一時退避
            BACKUP_DIR="$(mktemp -d)"
            trap 'rm -rf "$BACKUP_DIR"' EXIT
            for d in "''${USER_DIRS[@]}"; do
              if [ -d "$COMFYUI_HOME/$d" ]; then
                mv "$COMFYUI_HOME/$d" "$BACKUP_DIR/$d"
              fi
            done

            # ソースを差し替え
            rm -rf "$COMFYUI_HOME"
            cp -a "${comfyui-src}" "$COMFYUI_HOME"
            chmod -R u+rwX "$COMFYUI_HOME" || true

            # ユーザデータを復元（新しいソースのデフォルトを上書き）
            for d in "''${USER_DIRS[@]}"; do
              if [ -d "$BACKUP_DIR/$d" ]; then
                rm -rf "''${COMFYUI_HOME:?}/$d"
                mv "$BACKUP_DIR/$d" "$COMFYUI_HOME/$d"
              fi
            done

            # 依存を再インストール
            cd "$COMFYUI_HOME"
            TORCH_INDEX="https://download.pytorch.org/whl/''${COMFYUI_TORCH_VARIANT:-cu130}"

            uv pip install --python "$VENV_DIR/bin/python" \
              --extra-index-url "$TORCH_INDEX" \
              --requirements requirements.txt

            if [ "''${COMFYUI_ENABLE_MANAGER:-1}" = "1" ] && [ -f manager_requirements.txt ]; then
              uv pip install --python "$VENV_DIR/bin/python" \
                --extra-index-url "$TORCH_INDEX" \
                --requirements manager_requirements.txt
            fi

            echo "ComfyUI updated."
            echo "  Source: $COMFYUI_HOME"
            echo "  Venv:   $VENV_DIR"
          '';
        };

        comfyui-run = pkgs.writeShellApplication {
          name = "comfyui";
          runtimeInputs = basePkgs;
          text = ''
            set -euo pipefail

            STATE_DIR="''${COMFYUI_STATE_DIR:-$PWD/.comfyui-state}"
            COMFYUI_PYTHON="''${COMFYUI_PYTHON:-3.13}"

            COMFYUI_HOME="''${COMFYUI_HOME:-$STATE_DIR/src}"
            VENV_DIR="''${COMFYUI_VENV:-$STATE_DIR/venv-py$COMFYUI_PYTHON}"

            if [ ! -x "$VENV_DIR/bin/python" ]; then
              echo "venv not found. Run: comfyui-init"
              exit 1
            fi

            cd "$COMFYUI_HOME"

            # Manager を使うなら引数で有効化（comfyui-init が requirements を入れる想定）
            if [ "''${COMFYUI_ENABLE_MANAGER:-1}" = "1" ] && [ -f manager_requirements.txt ]; then
              ENABLE_MANAGER_ARGS="--enable-manager"
            else
              ENABLE_MANAGER_ARGS=""
            fi

            LISTEN="''${COMFYUI_LISTEN:-127.0.0.1}"
            PORT="''${COMFYUI_PORT:-8188}"

            exec "$VENV_DIR/bin/python" main.py --listen "$LISTEN" --port "$PORT" $ENABLE_MANAGER_ARGS "$@"
          '';
        };
      in
      {
        apps.default = {
          type = "app";
          program = "${pkgs.writeShellApplication {
            name = "comfyui-app";
            runtimeInputs = basePkgs;
            text = ''
              set -euo pipefail

              export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

              STATE_DIR="''${COMFYUI_STATE_DIR:-$PWD/.comfyui-state}"
              COMFYUI_PYTHON="''${COMFYUI_PYTHON:-3.13}"
              case "$COMFYUI_PYTHON" in
                3.13) PY_BIN="${python313}/bin/python" ;;
                3.12) PY_BIN="${python312}/bin/python" ;;
                *)
                  echo "Unsupported COMFYUI_PYTHON=$COMFYUI_PYTHON (use 3.13 or 3.12)"
                  exit 2
                  ;;
              esac

              COMFYUI_HOME="''${COMFYUI_HOME:-$STATE_DIR/src}"
              VENV_DIR="''${COMFYUI_VENV:-$STATE_DIR/venv-py$COMFYUI_PYTHON}"

              # init if needed
              if [ ! -x "$VENV_DIR/bin/python" ]; then
                echo "First run: initializing ComfyUI..."
                mkdir -p "$STATE_DIR"

                if [ ! -d "$COMFYUI_HOME" ]; then
                  mkdir -p "$(dirname "$COMFYUI_HOME")"
                  cp -a "${comfyui-src}" "$COMFYUI_HOME"
                  chmod -R u+rwX "$COMFYUI_HOME" || true
                fi

                mkdir -p "$(dirname "$VENV_DIR")"
                uv venv "$VENV_DIR" --python "$PY_BIN"

                TORCH_INDEX="https://download.pytorch.org/whl/''${COMFYUI_TORCH_VARIANT:-cu130}"
                uv pip install --python "$VENV_DIR/bin/python" \
                  --extra-index-url "$TORCH_INDEX" \
                  --requirements "$COMFYUI_HOME/requirements.txt"

                if [ "''${COMFYUI_ENABLE_MANAGER:-1}" = "1" ] && [ -f "$COMFYUI_HOME/manager_requirements.txt" ]; then
                  uv pip install --python "$VENV_DIR/bin/python" \
                    --extra-index-url "$TORCH_INDEX" \
                    --requirements "$COMFYUI_HOME/manager_requirements.txt"
                fi
              fi

              cd "$COMFYUI_HOME"

              if [ "''${COMFYUI_ENABLE_MANAGER:-1}" = "1" ] && [ -f manager_requirements.txt ]; then
                ENABLE_MANAGER_ARGS="--enable-manager"
              else
                ENABLE_MANAGER_ARGS=""
              fi

              LISTEN="''${COMFYUI_LISTEN:-127.0.0.1}"
              PORT="''${COMFYUI_PORT:-8188}"

              exec "$VENV_DIR/bin/python" main.py --listen "$LISTEN" --port "$PORT" $ENABLE_MANAGER_ARGS "$@"
            '';
          }}/bin/comfyui-app";
        };

        devShells.default = pkgs.mkShell {
          packages = basePkgs ++ [ comfyui-init comfyui-update comfyui-run ];
          shellHook = ''
            export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            echo "ComfyUI dev shell"
            echo "  init  : comfyui-init"
            echo "  update: comfyui-update"
            echo "  run   : comfyui"
            echo "Switch Python: COMFYUI_PYTHON=3.12  (default 3.13)"
            echo "Switch torch:  COMFYUI_TORCH_VARIANT=cu128 (default cu130)"
          '';
        };
      });
}
