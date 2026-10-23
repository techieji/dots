{ config, lib, pkgs, inputs, system, ... }:
let
  harness = pkgs.writeShellApplication {
    name = "codex-harness";
    runtimeInputs = [ pkgs.bubblewrap pkgs.codex pkgs.git pkgs.jq pkgs.libnotify pkgs.python3 pkgs.sqlite ];
    text = ''exec ${pkgs.python3}/bin/python3 ${./harness.py} "$@"'';
  };
  serenaPackage = inputs.serena.packages.${system}.default;
  heliumPackage = inputs.helium.defaultPackage.${system};
  playwrightHeliumMcp = pkgs.writeShellApplication {
    name = "playwright-helium-mcp";
    runtimeInputs = [ pkgs.playwright-mcp ];
    text = ''
      export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      export WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-1}"
      export DISPLAY="''${DISPLAY:-:0}"
      exec playwright-mcp \
        --browser=chromium \
        --executable-path=${lib.getExe heliumPackage} \
        "$@"
    '';
  };
  academicCollector = inputs.task-unifier.packages.${system}.default;
  academicProjectDir = "${config.home.homeDirectory}/Documents/projects/jobs";
  academicSync = pkgs.writeShellApplication {
    name = "academic-sync";
    runtimeInputs = [ academicCollector playwrightHeliumMcp ];
    text = ''
      export TASK_UNIFIER_PROJECT_DIR=${academicProjectDir}
      export TASK_UNIFIER_RUNTIME_DIR=${academicProjectDir}/runtime
      export TASK_UNIFIER_HELIUM_BIN=${lib.getExe heliumPackage}
      academic-browser-collect
      task-unifier --config ${academicProjectDir}/config.toml run
    '';
  };
in {
  home.packages = [
    harness playwrightHeliumMcp academicCollector pkgs.codex pkgs.bubblewrap pkgs.sqlite pkgs.jq pkgs.libnotify pkgs.repomix pkgs.nixd serenaPackage
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
  systemd.user.services.academic-sync = {
    Unit.Description = "Collect Canvas and Gradescope assignments";
    Service = {
      Type = "oneshot";
      ExecStart = "${academicSync}/bin/academic-sync";
      RuntimeMaxSec = "2h";
    };
  };
  systemd.user.timers.academic-sync = {
    Unit.Description = "Collect Canvas and Gradescope assignments daily";
    Timer = { OnCalendar = "daily"; Persistent = true; RandomizedDelaySec = "15m"; };
    Install.WantedBy = [ "timers.target" ];
  };
}
