{
  description = "Amica AI on NixOS: dev shell + services (llama.cpp, whisper.cpp, piper, frontend)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        # Use: nix develop
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            ## node/web
            nodejs_20
            pnpm
            libvips            # for sharp
            pkg-config
            python3            # node-gyp sometimes needs it
            git

            ## media / audio
            ffmpeg
            sox
            espeak-ng

            ## local backends (optional but handy)
            llama-cpp           # provides llama-* binaries incl. server
            whisper-cpp         # provides whisper server executable (name can vary by channel)
            piper
          ];

          # Sharp on Nix often works fine with the bundled binary; leave this unset unless you prefer system libvips.
          # SHARP_IGNORE_GLOBAL_LIBVIPS = "1";

          # Nice-to-have for Next/Image & node-gyp
          NIX_CFLAGS_COMPILE = "-O2";
        };

        # Expose these for convenience if you want to "nix run" them later
        packages = {
          inherit (pkgs) llama-cpp whisper-cpp piper;
        };
      }
    ) // {
      # NixOS module: services.amica.*
      nixosModules.amica = { config, lib, pkgs, ... }:
        let
          cfg = config.services.amica;
          inherit (lib) mkEnableOption mkIf mkOption types;
        in {
          options.services.amica = {
            enable = mkEnableOption "Amica stack (frontend + optional LLM/STT/TTS services)";

            user = mkOption { type = types.str; default = "amica"; description = "System user to run services under."; };
            group = mkOption { type = types.str; default = "amica"; };

            dataDir = mkOption {
              type = types.path;
              default = "/var/lib/amica";
              description = "Home/work directory for Amica services (logs, cache, etc.).";
            };

            environment = mkOption {
              type = types.attrsOf types.str;
              default = {};
              description = "Extra environment variables exported to the frontend service (e.g. NEXT_PUBLIC_*).";
            };

            # --- Frontend (Next.js) ---
            frontend = {
              enable = mkEnableOption "Run Amica frontend as a managed service";
              repoPath = mkOption {
                type = types.path;
                default = "/var/lib/amica/app"; # clone repo here
                description = "Path to the Amica repo checkout (the directory containing package.json).";
              };
              port = mkOption { type = types.port; default = 3000; };
              # dev = true -> `pnpm dev`; dev = false -> `pnpm build && pnpm start`
              dev = mkOption { type = types.bool; default = true; description = "Run in Next dev mode (hot reload) or production mode."; };
              nodePackage = mkOption { type = types.package; default = pkgs.nodejs_20; };
              pnpmPackage = mkOption { type = types.package; default = pkgs.pnpm; };
            };

            # --- llama.cpp (LLM) ---
            llama = {
              enable = mkEnableOption "Run llama.cpp HTTP server";
              model = mkOption { type = types.path; description = "Path to your GGUF model file (e.g., Mistral/OpenHermes .gguf)."; };
              port = mkOption { type = types.port; default = 8080; };
              threads = mkOption { type = types.int; default = 8; };
              ctx = mkOption { type = types.int; default = 4096; };
              ngl = mkOption {
                type = types.int;
                default = 0;
                description = "Number of GPU layers to offload (set >0 if you built llama-cpp with CUDA/Metal).";
              };
              extraArgs = mkOption { type = types.listOf types.str; default = []; description = "Additional llama-server flags."; };
            };

            # --- whisper.cpp (STT) ---
            whisper = {
              enable = mkEnableOption "Run whisper.cpp server (speech-to-text)";
              model = mkOption { type = types.path; description = "Path to Whisper model (e.g., ggml-base.en.bin)."; };
              port = mkOption { type = types.port; default = 5001; };
              threads = mkOption { type = types.int; default = 4; };
              extraArgs = mkOption { type = types.listOf types.str; default = []; };
            };

            # --- Piper (TTS) ---
            piper = {
              enable = mkEnableOption "Run Piper TTS in HTTP server mode";
              model = mkOption {
                type = types.path;
                description = "Path to Piper voice file (e.g., en_US-amy-medium.onnx).";
              };
              port = mkOption { type = types.port; default = 5002; };
              host = mkOption { type = types.str; default = "127.0.0.1"; };
              extraArgs = mkOption { type = types.listOf types.str; default = []; };
            };
          };

          config = mkIf cfg.enable {
            users.groups.${cfg.group} = {};
            users.users.${cfg.user} = {
              isSystemUser = true;
              group = cfg.group;
              home = cfg.dataDir;
              createHome = true;
            };

            # --- llama.cpp server ---
            systemd.services."amica-llama" = mkIf cfg.llama.enable {
              description = "llama.cpp HTTP server for Amica";
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              serviceConfig = {
                User = cfg.user;
                Group = cfg.group;
                WorkingDirectory = cfg.dataDir;
                ExecStart = lib.concatStringsSep " " ([
                  "${pkgs.llama-cpp}/bin/llama-server"
                  "-m ${cfg.llama.model}"
                  "-c ${toString cfg.llama.ctx}"
                  "-t ${toString cfg.llama.threads}"
                  "--port ${toString cfg.llama.port}"
                ] ++ lib.optional (cfg.llama.ngl > 0) ("-ngl " + toString cfg.llama.ngl)
                  ++ cfg.llama.extraArgs);
                Restart = "on-failure";
              };
            };

            # --- whisper.cpp server ---
            # NOTE: binary name can vary between channels; adjust to your package.
            systemd.services."amica-whisper" = mkIf cfg.whisper.enable {
              description = "whisper.cpp server for Amica (STT)";
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              serviceConfig = {
                User = cfg.user;
                Group = cfg.group;
                WorkingDirectory = cfg.dataDir;
                ExecStart = lib.concatStringsSep " " ([
                  # try one of these depending on nixpkgs channel:
                  # "${pkgs.whisper-cpp}/bin/whisper-server"
                  # "${pkgs.whisper-cpp}/bin/server"
                  # "${pkgs.whisper-cpp}/bin/whisper-cpp-server"
                  "${pkgs.whisper-cpp}/bin/server"
                  "-m ${cfg.whisper.model}"
                  "-t ${toString cfg.whisper.threads}"
                  "-p ${toString cfg.whisper.port}"
                ] ++ cfg.whisper.extraArgs);
                Restart = "on-failure";
              };
            };

            # --- Piper TTS server ---
            systemd.services."amica-piper" = mkIf cfg.piper.enable {
              description = "Piper TTS HTTP server for Amica";
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              serviceConfig = {
                User = cfg.user;
                Group = cfg.group;
                WorkingDirectory = cfg.dataDir;
                # Piper has a simple HTTP mode in recent builds:
                ExecStart = lib.concatStringsSep " " ([
                  "${pkgs.piper}/bin/piper"
                  "--server"
                  "--host ${cfg.piper.host}"
                  "--port ${toString cfg.piper.port}"
                  "--model ${cfg.piper.model}"
                ] ++ cfg.piper.extraArgs);
                Restart = "on-failure";
              };
            };

            # --- Amica frontend (Next.js) ---
            systemd.services."amica-frontend" = mkIf cfg.frontend.enable {
              description = "Amica frontend (Next.js)";
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              environment = cfg.environment // {
                PORT = toString cfg.frontend.port;
                NODE_ENV = if cfg.frontend.dev then "development" else "production";
              };
              path = [ cfg.frontend.nodePackage cfg.frontend.pnpmPackage pkgs.git ];
              serviceConfig = {
                User = cfg.user;
                Group = cfg.group;
                WorkingDirectory = cfg.frontend.repoPath;
                # dev mode: assumes you've run `pnpm i`
                ExecStart = if cfg.frontend.dev then
                  "${cfg.frontend.pnpmPackage}/bin/pnpm dev --port ${toString cfg.frontend.port}"
                else
                  "${pkgs.bash}/bin/bash -lc 'pnpm i --frozen-lockfile && pnpm build && pnpm start -p ${toString cfg.frontend.port}'";
                Restart = "on-failure";
              };
            };

            # Open the ports you actually enable:
            networking.firewall.allowedTCPPorts =
              (lib.optional cfg.frontend.enable cfg.frontend.port)
              ++ (lib.optional cfg.llama.enable cfg.llama.port)
              ++ (lib.optional cfg.whisper.enable cfg.whisper.port)
              ++ (lib.optional cfg.piper.enable cfg.piper.port);
          };
        };
    };
}
