{ pkgs, lib, system, inputs, ... }: 
{
  home.username = "prajasekar";
  home.homeDirectory = "/home/prajasekar";
  home.packages = with pkgs; [
    ctags
    # obsidian
    grimblast
    speedcrunch
    libreoffice-qt
    pass
  ];

  programs.zathura.enable = true;

  programs.kitty = {
    enable = true;
    settings = {
      enable_audio_bell = false;
      shell = "nu";
      notify_on_cmd_finish = "invisible 20";
      initial_window_width = "100c";
      initial_window_height = "100c";
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user = { name = "Pradhyum Rajasekar"; email = "drpradhyum2016@outlook.com"; };
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
    extraConfig = builtins.readFile ./vimrc;
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
      character = {
        success_symbol = "[>](bold green)";
        error_symbol = "[>](bold red)";
      };
      cmd_duration = {
        format = " took [$duration]($style)";
        min_time = 0;
      };
      directory = {
        format = "[$path]($style) ";
        truncation_length = 2;
        style = "lightblue";
      };
      nix_shell = {
        format = " [$symbol]($style)";
        symbol = "\\[*\\]";
      };
      status = {
        format = " [$symbol$common_meaning$signal_name$maybe_int]($style)";
        success_style = "bold green";
        failure_style = "bold red";
        symbol = "";
        success_symbol = "OK";
        disabled = false;
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
 
  programs.bottom.enable = true;

  ### Hyprland-related things

  stylix.targets.hyprland.enable = false;
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    extraConfig = import ./hyprland.lua { inherit pkgs inputs system; };
  };
 
  stylix.targets.hyprlock.enable = false;
  programs.hyprlock = {
    enable = true;
    settings = {
      general = { no_fade_in = false; disable_loading_bar = true; };
      background = { 
        monitor = "";
        # path = wallpaper;      # TODO
        path = "screenshot";
        blur_passes = 3;
        contrast = 0.8916;
        brightness = 0.8172;
        vibrancy = 0.1696;
        vibrancy_darkness = 0.0;
      };
      auth."fingerprint:enabled" = true;
      input-field = [ {
        monitor = ""; size = "600, 100"; outline_thickness = 2;
        dots_size = 0.2; dots_spacing = 1; dots_center = true;
        outer_color = "rgba(0,0,0,0)"; inner_color = "rgba(0,0,0,0.1)";
        font_color = "rgb(200,200,200)";
        fade_on_empty = true;
        font_family = "FiraCode Nerd Font Mono";      # TODO
        hide_input = false;
        position = "100, -300"; halign = "left"; valign = "top";
      } ];
      label = [ {
        monitor = "";
        text = ''cmd[update:1000] echo "$(date +"%-l:%M%p")"'';
        color = "rgba(255, 255, 255, 1)";
        font_size = 120;
        font_family = "FiraCode Nerd Font Mono";       # TODO
        position = "100, -100"; halign = "left"; valign = "top";
      } ];
    };
  };

  services.awww.enable = true;      # Wallpaper

  programs.vicinae = {
    enable = true;
  };

  stylix.targets.waybar.addCss = false;
  programs.waybar = {
    enable = true;
    style = lib.mkAfter (builtins.readFile ./waybar-style.css);
    settings.mainBar = {
      reload_style_on_change = true;
      toggle = true;
      layer = "top";
      position = "left";
      margin-top = 0; margin-bottom = 0; margin-left = 0; margin-right = 0;
      spacing = 0;
      include = [ ./waybar-modules.json ];
      modules-left = [ "clock" "battery#draw" ];
      modules-center = [ "hyprland/workspaces" ];
      modules-right = [ "pulseaudio#microphone" "group/audio" "group/brightness" "battery" ];
    };
  };
 
  home.stateVersion = "26.05";
  programs.home-manager.enable = true;
}
