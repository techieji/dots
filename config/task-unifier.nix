{ config, ... }:
let
  projectDir = "${config.home.homeDirectory}/Documents/projects/jobs";
in {
  systemd.user.services.task-unifier-dashboard = {
    Unit = {
      Description = "Task Unifier local dashboard";
      After = [ "network.target" ];
    };

    Service = {
      Type = "simple";
      WorkingDirectory = projectDir;
      EnvironmentFile = "-${config.home.homeDirectory}/.config/task-unifier/environment";
      ExecStart = "${projectDir}/.venv/bin/task-unifier --config ${projectDir}/config.toml serve --bind 127.0.0.1 --port 8787";
      Restart = "on-failure";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ "${projectDir}/runtime" ];
    };

    Install.WantedBy = [ "default.target" ];
  };
}
