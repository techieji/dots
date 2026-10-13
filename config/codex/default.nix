{ config, lib, pkgs, inputs, system, ... }:
let
  harness = pkgs.writeShellApplication {
    name = "codex-harness";
    runtimeInputs = [ pkgs.bubblewrap pkgs.codex pkgs.git pkgs.jq pkgs.libnotify pkgs.python3 pkgs.sqlite ];
    text = ''exec ${pkgs.python3}/bin/python3 ${./harness.py} "$@"'';
  };
  chatgpt = pkgs.stdenv.mkDerivation rec {
    pname = "chatgpt-desktop";
    version = "26.1007.21434";
    src = pkgs.fetchurl {
      url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
      hash = "sha256-J2tTQcPXSyYdOtUhBvf6ft3gaEHkdn/ipAy1QJmx8+0=";
    };
    nativeBuildInputs = [ pkgs.asar pkgs.autoPatchelfHook pkgs.dpkg pkgs.makeWrapper ];
    buildInputs = with pkgs; [
      alsa-lib at-spi2-atk cairo cups dbus expat glib gtk3 libdrm libglvnd
      libnotify libusb1 libxkbcommon mesa nspr nss openssl pango systemd
      tpm2-tss vulkan-loader
      libx11 libxcb libxcomposite libxdamage libxext libxfixes libxrandr
    ];
    autoPatchelfIgnoreMissingDeps = [
      "libc.musl-x86_64.so.1"
      "libQt5Core.so.5" "libQt5Gui.so.5" "libQt5Widgets.so.5"
      "libQt6Core.so.6" "libQt6Gui.so.6" "libQt6Widgets.so.6"
    ];
    unpackPhase = ''dpkg-deb -x "$src" .'';
    postPatch = ''
      asar extract usr/lib/chatgpt/resources/app.asar app-asar
      substituteInPlace app-asar/.vite/build/worker.js \
        --replace-fail 'process.platform===`linux`&&n.recursive!==!1?j9' '!1?j9' \
        --replace-fail 'process.platform===`linux`?j9' '!1?j9'
      asar pack app-asar usr/lib/chatgpt/resources/app.asar
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r usr/* "$out/"
      runHook postInstall
    '';
    postFixup = ''
      wrapProgram "$out/lib/chatgpt/ChatGPT" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pkgs.libglvnd ]}:/run/opengl-driver/lib"
      rm "$out/bin/chatgpt"
      makeWrapper "$out/lib/chatgpt/ChatGPT" "$out/bin/chatgpt" \
        --run 'plugin_resources="''${XDG_CACHE_HOME:-$HOME/.cache}/chatgpt/bundled-plugins-${version}"' \
        --run 'mkdir -p "$plugin_resources/plugins"' \
        --run "cp -r --no-preserve=mode '$out/lib/chatgpt/resources/plugins/.' \"\$plugin_resources/plugins/\"" \
        --run 'export CODEX_ELECTRON_BUNDLED_PLUGINS_RESOURCES_PATH="$plugin_resources"'
    '';
    meta = {
      description = "ChatGPT desktop app with Codex";
      homepage = "https://openai.com/codex/";
      license = lib.licenses.unfree;
      mainProgram = "chatgpt";
      platforms = [ "x86_64-linux" ];
    };
  };
  serenaPackage = inputs.serena.packages.${system}.default;
in {
  home.packages = [
    harness chatgpt pkgs.codex pkgs.bubblewrap pkgs.sqlite pkgs.jq pkgs.libnotify pkgs.repomix pkgs.nixd serenaPackage
    (pkgs.writeShellScriptBin "codex-semantic" ''
      exec ${lib.getExe serenaPackage} "$@"
    '')
    (pkgs.writeShellScriptBin "codex-context-audit" ''
      set -eu
      budget="''${CODEX_CONTEXT_TOKEN_BUDGET:-12000}"
      exec ${lib.getExe pkgs.repomix} --compress --token-budget "$budget" "$@"
    '')
  ];
  home.file = {
    ".config/codex-harness/policy.json".source = ./policy.json;
    ".config/codex-harness/prompts".source = ./prompts;
    ".config/codex-harness/schemas".source = ./schemas;
  };
  systemd.user.services.codex-harness = {
    Unit.Description = "Process queued Codex harness jobs";
    Service = {
      Type = "oneshot";
      ExecStart = "${harness}/bin/codex-harness worker";
      Environment = [ "CODEX_HARNESS_INTERNAL=1" ];
      RuntimeMaxSec = "4h";
    };
  };
  systemd.user.paths.codex-harness = {
    Unit.Description = "Watch the Codex harness queue";
    Path.PathChanged = "%S/codex-harness/wake";
    Install.WantedBy = [ "default.target" ];
  };
  systemd.user.services.codex-harness-maintenance = {
    Unit.Description = "Prune and reconcile Codex harness state";
    Service = { Type = "oneshot"; ExecStart = "${harness}/bin/codex-harness maintain"; };
  };
  systemd.user.timers.codex-harness-maintenance = {
    Unit.Description = "Daily Codex harness maintenance";
    Timer = { OnCalendar = "daily"; Persistent = true; RandomizedDelaySec = "15m"; };
    Install.WantedBy = [ "timers.target" ];
  };
}
