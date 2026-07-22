# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, inputs, ... }: {
  imports = [ ./hardware-configuration.nix inputs.impermanence.nixosModules.impermanence ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "pradtop"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
 
  networking.networkmanager.enable = true;        # Enable networking
  programs.nm-applet.enable = true;         # Enable network manager applet

  # Internationalisation properties.
  time.timeZone = "America/New_York";
  i18n.extraLocaleSettings = let US = "en_US.UTF-8"; in {
    defaultLocale = US; LC_ADDRESS = US; LC_IDENTIFICATION = US;
    LC_MEASUREMENT = US; LC_MONETARY = US; LC_NAME = US; LC_NUMERIC = US;
    LC_PAPER = US; LC_TELEPHONE = US; LC_TIME = US;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.avahi = { enable = true; nssmdns4 = true; openFirewall = true; };

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
      General = { Experimental = true; };
      Policy = { AutoEnable = true; };
    };
  };
  services.blueman.enable = true;

  services.fprintd.enable = true;      # Fingerprint

  fileSystems."/persist" = {
    device = "/dev/disk/by-uuid/3d3f9482-968e-46a2-b464-637b97a82845";
    fsType = "btrfs";
    options = [ "subvol=@persist" "compress=zstd" ];
    neededForBoot = true;
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/3d3f9482-968e-46a2-b464-637b97a82845";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd" ];
    neededForBoot = true;
  };

  fileSystems."/" = lib.mkForce {
    device = "none";
    fsType = "tmpfs";
    options = [ "defaults" "size=16G" "mode=755" ];
  };

  fileSystems."/home/prajasekar" = {       # I'm the only user after all!
    device = "none";
    fsType = "tmpfs";
    options = [ "defaults" "size=16G" "mode=755" ];
    neededForBoot = true;      # Why is this true?
  };

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"
      "/var/lib/NetworkManager"
      "/var/lib/fprint"
    ];
    files = [
      "/etc/machine-id"
    ];
  };

  fileSystems."/mnt/data-part" = {
    device = "/dev/disk/by-uuid/3d3f9482-968e-46a2-b464-637b97a82845";
    fsType = "btrfs";
  };

  users.mutableUsers = false;
  users.users.root.hashedPassword = "!";
  users.users.prajasekar = {
    hashedPasswordFile = "/persist/secrets/prajasekar-password-hash";
    isNormalUser = true;
    description = "Pradhyum Rajasekar";
    extraGroups = [ "networkmanager" "wheel" "ydotool" ];
  };

  systemd.services."getty@tty1" = {     # Autologin?
    overrideStrategy = "asDropin";
    serviceConfig.ExecStart = ["" "@${pkgs.util-linux}/sbin/agetty agetty --login-program ${config.services.getty.loginProgram} --autologin prajasekar --noclear --keep-baud %I 115200,38400,9600 $TERM"];
  };

  programs.gnupg.agent.enable = true;
  programs.ydotool.enable = true;        # For password menu

  services.upower.enable = true;

  programs.hyprland = { enable = true; withUWSM = true; xwayland.enable = true; };

  services.onedrive.enable = true;
  
  programs.weylus = { enable = true; openFirewall = true; users = [ "prajasekar" ]; };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
    config.hyprland.default = [ "hyprland" "gtk" ];
  };

  stylix.enable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/danqing.yaml";
  stylix.fonts = { monospace.name = "Iosevka Radon"; };     # This font is technically only set in prajasekar

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [ python3 vim ];

  environment.shells = [ pkgs.nushell ];
  programs.starship.enable = true;           # TODO remove (starship seems to be using the global path instead of the home-manager one)

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
