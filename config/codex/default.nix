{ config, lib, pkgs, inputs, system, ... }:
let
  harness = pkgs.writeShellApplication {
    name = "codex-harness";
    runtimeInputs = [ pkgs.bubblewrap pkgs.codex pkgs.git pkgs.jq pkgs.libnotify pkgs.python3 pkgs.sqlite ];
    text = ''exec ${pkgs.python3}/bin/python3 ${./harness.py} "$@"'';
  };
  hooks = pkgs.replaceVars ./hooks.json { harness = "${harness}/bin/codex-harness"; };
  serenaPackage = inputs.serena.packages.${system}.default;
in {
  home.packages = [
    harness pkgs.bubblewrap pkgs.sqlite pkgs.jq pkgs.libnotify pkgs.repomix pkgs.nixd serenaPackage
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
    ".codex/config.toml".source = lib.mkForce ./config.toml;
    ".codex/hooks.json".source = hooks;
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
