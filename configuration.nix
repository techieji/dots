# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:
let
  cursorinfo = { name = "Dot-Transparent"; size = "24"; };
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "pradtop"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable network manager applet
  programs.nm-applet.enable = true;

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Enable the LXQT Desktop Environment.
  # services.xserver.displayManager.lightdm.enable = true;
  # services.xserver.desktopManager.lxqt.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
    wireplumber.enable = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };
  services.blueman.enable = true;

  services.fprintd.enable = true;

  fileSystems."/mnt/data-part" = {
    device = "/dev/nvme0n1p5";            # TODO switch to by-uuid
    fsType = "btrfs";
  };

  fileSystems."/home/prajasekar" = {
    depends = [ "/mnt/data-part" ];
    device = "/mnt/data-part/home/prajasekar";
    fsType = "none";
    options = [ "bind" ];
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.prajasekar = {
    isNormalUser = true;
    description = "Pradhyum Rajasekar";
    extraGroups = [ "networkmanager" "wheel" "ydotool" ];
  };

  systemd.services."getty@tty1" = {     # Autologin?
    overrideStrategy = "asDropin";
    serviceConfig.ExecStart = ["" "@${pkgs.util-linux}/sbin/agetty agetty --login-program ${config.services.getty.loginProgram} --autologin prajasekar --noclear --keep-baud %I 115200,38400,9600 $TERM"];
  };

  programs.gnupg.agent.enable = true;
  programs.ydotool.enable = true;        # For pass

  services.upower.enable = true;

  services.flatpak.enable = true;     # TODO make this declarative

  ### Hyprland stuff
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  systemd.user.services.weylus = {
    enable = true;
    after = [ "graphical-session.target" ];
    description = "weylus (iPad as drawing tablet)";
    serviceConfig = {
      Type = "simple";
      ExecStartPre = "${pkgs.hyprland}/bin/hyprctl output create headless weylus";
      # TODO move away from flatpak after wayland fixes are upstreamed
      ExecStart = "${pkgs.flatpak}/bin/flatpak run io.github.electronstudio.WeylusCommunityEdition --no-gui --try-vaapi --auto-start --wayland-support";
      ExecStop = "${pkgs.hyprland}/bin/hyprctl output remove weylus";
    };
  };
  ### End hyprland stuff

  services.onedrive.enable = true;
  
  programs.weylus = {       # This is only to open the firewall and set perms. TODO: rewrite this manually!
    enable = true;
    openFirewall = true;
    users = [ "prajasekar" ];
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
    config.hyprland.default = [ "hyprland" "gtk" ];
  };

  stylix.enable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/danqing.yaml";
  stylix.fonts = { monospace.name = "Iosevka Radon"; };     # This is technically only set in prajasekar

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    python3 vim
    gst_all_1.gstreamer gst_all_1.gst-plugins-base gst_all_1.gst-plugins-good     # gstreamer (for Weylus) TODO decide whether this is necessary
  ];
  environment.variables.GST_PLUGIN_SYSTEM_PATH_1_0 = "/run/current-system/sw/lib/gstreamer-1.0/";

  environment.shells = [ pkgs.nushell ];
  programs.starship.enable = true;           # TODO remove (starship seems to be using this path instead of the home-manager one)

  programs.nh = {
    enable = true;
    flake = builtins.toString ./.;
    clean.enable = true;      # Autoclean service
    clean.extraArgs = "--keep-since 4d --keep 3";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
