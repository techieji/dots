{ config, pkgs, lib, system, inputs, hyprlandPackage, ... }:
let
  cursorInfo = {
    name = "TheDot";
    size = 24;
    xcursor = ./resources/thedot0.6.tar;
  };
  cursorPackage = pkgs.runCommand "thedot-cursors" {} ''
    mkdir -p source $out/share/icons/${cursorInfo.name}
    tar xf ${cursorInfo.xcursor} -C source
    cp -r source/thedot0.6/Dot-Transparent/. $out/share/icons/${cursorInfo.name}/
  '';
  iosevkaRadon = pkgs.iosevka.override { set = "Radon"; privateBuildPlan = builtins.readFile ./config/iosevka-radon.toml; };
  background = "${./resources/backgrounds/nightscape.png}";
  lockscreenUi = pkgs.stdenvNoCC.mkDerivation {
    pname = "dots-lock-ui";
    version = "1.0.0";
    src = ./config/lockscreen;
    nativeBuildInputs = [ pkgs.qt6.qtdeclarative pkgs.qt6.qtshadertools ];
    dontWrapQtApps = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/dots-lock
      cp *.qml $out/share/dots-lock/
      qsb --qt6 temperature.frag -o $out/share/dots-lock/temperature.frag.qsb
      qmllint -I ${pkgs.quickshell}/lib/qt-6/qml -I . *.qml
      runHook postInstall
    '';
  };
  dotsLock = pkgs.writeShellApplication {
    name = "dots-lock";
    runtimeInputs = with pkgs; [
      coreutils
      grim
      hyprlandPackage
      jq
      quickshell
      systemd
      util-linux
    ];
    text = ''
      mode=lock
      if [[ ''${1:-} == "--preview" ]]; then
        mode=preview
      elif [[ ''${1:-} == "--suspend" ]]; then
        mode=suspend
      elif [[ $# -ne 0 ]]; then
        echo "usage: dots-lock [--preview|--suspend]" >&2
        exit 2
      fi

      runtime_base=''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}
      exec 9>"$runtime_base/dots-lock.lock"
      if ! flock -n 9; then
        exit 0
      fi

      umask 077
      runtime_dir=$(mktemp -d "$runtime_base/dots-lock.XXXXXX")
      cleanup() {
        rm -rf -- "$runtime_dir"
      }
      trap cleanup EXIT INT TERM

      bar_widths='{}'
      if layer_state=$(hyprctl -j layers 2>/dev/null); then
        bar_widths=$(jq -c '
          to_entries
          | map({
              key: .key,
              value: ([.value.levels[][] | select(.namespace == "waybar") | .w]
                | if length > 0 then max else 0 end)
            })
          | from_entries
        ' <<<"$layer_state") || bar_widths='{}'
      fi

      mapfile -t outputs < <(hyprctl -j monitors | jq -r '.[].name')
      for output in "''${outputs[@]}"; do
        safe_output=''${output//[^A-Za-z0-9_.-]/_}
        grim -o "$output" "$runtime_dir/$safe_output.png" || true
      done

      run_ui() {
        DOTS_LOCK_MODE="$1" \
        DOTS_LOCK_RUNTIME="$runtime_dir" \
        DOTS_LOCK_BACKGROUND="${background}" \
        DOTS_LOCK_RECOVERY="''${2:-0}" \
        DOTS_LOCK_BAR_WIDTHS="$bar_widths" \
          ${pkgs.quickshell}/bin/qs -n -p ${lockscreenUi}/share/dots-lock
      }

      if [[ $mode == preview ]]; then
        run_ui preview
        exit $?
      fi

      if [[ $mode == suspend ]]; then
        run_ui lock 0 &
        ui_pid=$!
        for _ in $(seq 1 100); do
          if [[ -e $runtime_dir/ready ]]; then
            systemctl suspend
            break
          fi
          if ! kill -0 "$ui_pid" 2>/dev/null; then
            break
          fi
          sleep 0.05
        done
        set +e
        wait "$ui_pid"
        status=$?
        set -e
      else
        set +e
        run_ui lock 0
        status=$?
        set -e
      fi

      if (( status != 0 )); then
        rm -f -- "$runtime_dir"/*.png "$runtime_dir/ready"
        run_ui lock 1
      fi
    '';
  };
  hyprshellPackage = let
    craneLib = inputs.hyprshell.inputs.crane.mkLib pkgs;
    buildLib = import "${inputs.hyprshell}/nix/build.nix" { inherit craneLib pkgs; };
    commonArgs = buildLib.commonArgs // {
      version = "4.11.0-alpha.1";
      buildInputs = buildLib.commonArgs.buildInputs ++ [ pkgs.dbus pkgs.libgbm ];
      cargoExtraArgs = "";
    };
    cargoArtifacts = craneLib.buildDepsOnly (commonArgs // {
      src = craneLib.cleanCargoSource inputs.hyprshell;
    });
  in craneLib.buildPackage (commonArgs // {
    inherit cargoArtifacts;
    patches = [ ./patches/hyprshell-workspace-grid.patch ];
    patchFlags = [ "-p1" ];
    postInstall = ''
      install -Dm644 packaging/hyprshell-settings.desktop \
        $out/share/applications/hyprshell-settings.desktop
      install -Dm644 packaging/hyprshell-settings.png \
        $out/share/pixmaps/hyprshell-settings.png
      mkdir -p $out/share/hyprshell
      cp -r packaging/share/. $out/share/hyprshell/
    '';
  });

  xdg = {
    dataHome = ".local/share";
    configHome = ".config";
  };
in {
  imports = [
    "${inputs.impermanence}/home-manager.nix"
    inputs.direnv-instant.homeModules.direnv-instant
    inputs.hyprshell.homeModules.default
    ./config/codex
    ./config/avizo.nix
    ./config/task-unifier.nix
  ];

  home.persistence."/persist/" = {
    directories = [
      ".gnupg" ".password-store" ".ssh" "Documents"
      "${xdg.dataHome}/zoxide" "${xdg.configHome}/net.imput.helium"
      "${xdg.configHome}/onedrive" "${xdg.configHome}/Slack" "${xdg.configHome}/discord"
      ".codex" ".vim" ".joinnow"   # Codex state, Ultisnips, and eduroam certificates
      ".agents" ".serena" ".local/state/codex-harness" ".local/share/codex-harness"
    ];
  };
 
  home.username = "prajasekar";
  home.homeDirectory = "/home/prajasekar";
  home.packages = with pkgs; [
    musescore
    universal-ctags
    obsidian
    slack discord
    grimblast
    dotsLock
    speedcrunch
    libreoffice-qt
    pass
    signal-desktop
    ( iosevkaRadon.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.nerd-font-patcher ];
      postInstall = (old.postInstall or "") + ''
      mkdir -p $out/share/fonts/truetype/nerd-patched
      for f in $out/share/fonts/truetype/*.ttf; do
        nerd-font-patcher --complete --no-progressbars \
          --outputdir $out/share/fonts/truetype/nerd-patched \
          "$f"
      done
      '';
    }) )
    inputs.antigravity-nix.packages.x86_64-linux.google-antigravity-cli
  ];
  home.sessionVariables.NIXOS_OZONE_WL = "1";

  xdg.enable = true;

  home.pointerCursor = {
    enable = true;
    inherit (cursorInfo) name size;
    package = cursorPackage;
    gtk.enable = true;
    x11.enable = true;
  };

  gtk.enable = true;

  xdg.configFile."ctags/.ctags".text = ''
    _build
  '';

  programs.zathura.enable = true;

  programs.kitty = {
    enable = true;
    settings = {
      enable_audio_bell = false;
      shell = "nu";
      notify_on_cmd_finish = "invisible 20";
      initial_window_width = "100c";
      initial_window_height = "100c";
      background_opacity = lib.mkForce "0.90";
      dynamic_background_opacity = false;
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user = { name = "Pradhyum R"; email = "drpradhyum2016@outlook.com"; };
      init.defaultBranch = "main";
    };
  };

  programs.vim = {
    enable = true;
    defaultEditor = true;
    packageConfigurable = pkgs.vim-full;
    plugins = with pkgs.vimPlugins; [
      ultisnips
      vimtex
      vim-gutentags
      vim-airline
      vim-devicons
      tagbar
    ];
    extraConfig = builtins.readFile ./config/vimrc;
  };

  programs.nushell = {
    enable = true;
    settings = {
      show_banner = false;
      buffer_editor = "vim";
    };
  };

  programs.zoxide = { enable = true; enableNushellIntegration = true; };
  programs.carapace = { enable = true; enableNushellIntegration = true; };
  programs.nix-your-shell = { enable = true; enableNushellIntegration = true; };

  programs.starship = {
    enable = true;
    enableNushellIntegration = true;
    settings = {
      add_newline = false;
      format = "$directory$character";
      right_format = "$status$cmd_duration$nix_shell";
      character = { success_symbol = "[>](bold green)"; error_symbol = "[>](bold red)"; };
      cmd_duration = { format = " took [$duration]($style)"; min_time = 0; };
      directory = { format = "[$path]($style) "; truncation_length = 2; style = "lightblue"; };
      nix_shell = { format = " [$symbol]($style)"; symbol = "\\[*\\]"; };
      status = {
        format = " [$symbol$common_meaning$signal_name$maybe_int]($style)"; disabled = false;
        success_style = "bold green"; failure_style = "bold red";
        symbol = ""; success_symbol = "OK";
      };
    };
  };

  programs.tofi = {
    enable = true;
    settings = {
      font-size = lib.mkForce "20";
      # Text layout
      prompt-text = "";
      prompt-padding = 0;
      placeholder-text = "";
      num-results = 0;
      result-spacing = 15;
      horizontal = false;
      min-input-width = 60;

      # Window theming
      width = "100%";
      height = "100%";
      # TODO make background color transparent
      outline-width = 0;
      border-width = 0;
      corner-radius = 0;
      padding-top = "15%";
      padding-left = "35%";
      clip-to-padding = true;
      scale = true;

      # Window positioning
      anchor = "center"; exclusive-zone = -1;
      margin-top = 0; margin-bottom = 0; margin-left = 0; margin-right = 0;

      # Behavior
      hide-cursor = true; text-cursor = false; history = true;
    };
  };

  programs.hyprshell = {
    enable = true;
    package = hyprshellPackage;
    systemd.enable = true;
    styleFile = import ./config/hyprshell-style.css {
      c = config.lib.stylix.colors.withHashtag;
    };
    settings.windows = {
      enable = true;
      scale = 4.5;
      items_per_row = 4;
      overview = {
        enable = true;
        key = "Tab";
        modifier = "super";
        filter_by = [ ];
        exclude_workspaces = "special:.*";
        top_offset = 0;
        launcher = {
          show_when_empty = false;
          plugins = {
            applications.enable = false;
            calc.enable = false;
            shell.enable = false;
            terminal.enable = false;
            websearch.enable = false;
            path.enable = false;
            actions.enable = false;
          };
        };
      };
      switch.enable = false;
      switch_2.enable = false;
    };
  };

  systemd.user.services.hyprshell.Service.Environment = [
    "HYPRSHELL_EXPERIMENTAL=1"
  ];
 
  programs.bottom.enable = true;

  ### Hyprland-related things

  stylix.targets.hyprland.enable = false;
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    extraConfig = import ./config/hyprland.lua {
      # Vars that are passed to generate the final hyprland.lua
      inherit pkgs;
      pabc = inputs.pabc.packages.${system}.default;
      helium = inputs.helium.defaultPackage.${system};
      inherit dotsLock;
    };
    package = null;
    portalPackage = null;
  };

  programs.bash = {
    # Needed for automatically starting hyprland
    enable = true;
    profileExtra = ''
      if uwsm check may-start; then
          exec uwsm start hyprland.desktop
      fi
    '';
  };

  services.hyprsunset = {
    enable = true;
    settings = {
      profile = [
        { identity = true; }
      ];
    };
  };
 
  stylix.targets.hyprlock.enable = false;
  programs.hyprlock.enable = false;

  services.hyprpaper = {
    enable = true;
    settings = {
      splash = false;
      wallpaper = [ { monitor = ""; path = background; } ];
    };
  };

  # Config from: https://github.com/iyiolacak/iyiolacak-swaync-config/
  stylix.targets.swaync.enable = false;        # TODO enable colors and have the css read these colors
  services.swaync = {
    enable = true;
    style = import ./config/swaync-style.css { c = config.lib.stylix.colors.withHashtag; };
    settings = {
      positionX = "right"; positionY = "top";
      control-center-exclusive-zone = false;
      control-center-width = 400;
      notification-2fa-action = true; notification-inline-replies = false; notification-window-width = 300;
      notification-body-image-height = 240; notification-body-image-width = 240;
      timeout = 8; timeout-low = 4; timeout-critical = 0;
      fit-to-screen = true; keyboard-shortcuts = true; image-visibility = "when-available";
      transition-time = 150;
      script-fail-notify = true;
      widgets = [ "title" "notifications" "buttons-grid" ];
      widget-config = { title = { text = "Notifications"; clear-all-button = true; button-text = "Clear"; }; };
    };
  };

  services.poweralertd.enable = true;
 
  programs.vicinae = {
    enable = true;
    systemd.enable = true;
    settings.launcher_window = {
      opacity = lib.mkForce 0.90;
      rounding = 8;
      material = "none";
    };
  };      # App launcher

  stylix.targets.waybar.addCss = false;
  programs.waybar = {
    enable = true;
    style = lib.mkAfter (builtins.readFile ./config/waybar-style.css);
    settings.mainBar = {
      reload_style_on_change = true;
      toggle = true;
      layer = "top";
      position = "left";
      margin-top = 0; margin-bottom = 0; margin-left = 0; margin-right = 0;
      spacing = 0;
      include = [ ./config/waybar-modules.json ];
      modules-left = [ "clock" "battery#draw" ];
      modules-center = [ "hyprland/workspaces" ];
      modules-right = [ "custom/notification" "battery" ];
    };
    systemd.enable = true;
  };

  #programs.direnv-instant = { 
  #  enable = true;
  #  enableNushellIntegration = true;
  #};

  #programs.direnv = {
  #  enable = true;
  #  nix-direnv.enable = true;
  #  enableNushellIntegration = true;
  #};

  services.avizoContrast.enable = true;

  home.stateVersion = "26.05";
  programs.home-manager.enable = true;
}
