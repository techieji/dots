# Dotfiles

This repository uses [nix](https://nixos.org/) to automatically populate a bunch of
dotfiles and generally setup my system. This is mainly for **my use** in case I mess up
my system (it has my name and email in places).

Note that this setup is *pretty darn declarative*. Particularly:
 - Uses NixOS (duh) to configure, like, the entire system. Services, filesystems, invoking everything
   else here, you name it.
 - Uses [home manager](https://wiki.nixos.org/wiki/Home_Manager) to manage config files for most programs.
 - Uses [Impermanence](https://github.com/nix-community/impermanence) to keep system state consistent.

On this last one, important notes:
 - Both `/` and `/home` are `tmpfs`s. They are *different* `tmpfs`s, each with a max size of 16G.
   In practice, that means that these directories are wiped on boot.
 - The system is hosted on a [btrfs](https://en.wikipedia.org/wiki/Btrfs) with 2 subvolumes:
   - `@nix`: stores the nix store
   - `@persist`: stores data persisted by impermanence.
   
   The main userspace data location that is persisted is `~/Documents`.

Features:
 - Visuals: [hyprland](https://hypr.land/) with [waybar](https://github.com/Alexays/Waybar) (taskbar) and
   [awww](https://codeberg.org/LGFae/awww) (wallpaper). [hyprlock](https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/)
   for the lockscreen, [TheDot](https://www.gnome-look.org/p/1244392) for the cursor (converted to [hyprcursor](https://wiki.hypr.land/Hypr-Ecosystem/hyprcursor/)).
   A custom [Iosevka](https://typeof.net/Iosevka/) font patched with [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts#font-patcher).
 - Terminal: [nushell](https://www.nushell.sh/) with [carapace](https://carapace.sh/) for completions,
   [starship](https://starship.rs/) for the prompt, [zoxide](https://github.com/ajeetdsouza/zoxide).
   [vim](https://www.vim.org/) with [ctags](https://en.wikipedia.org/wiki/ctags) support, as well as
   [UltiSnips](https://github.com/SirVer/ultisnips) and [VimTeX](https://github.com/lervag/vimtex).
   [Kitty](https://sw.kovidgoyal.net/kitty/) as terminal emulator.
 - Desktop tools: [libreoffice](https://www.libreoffice.org/), [speedcrunch](https://heldercorreia.bitbucket.io/speedcrunch/)
   as calculator, [pass](https://www.passwordstore.org/) as password manager. [vicinae](https://www.vicinae.com/)
   for launcher. [pabc](https://github.com/techieji/pabc) for brightness control. [Helium](https://helium.computer/) for browser.
 - Misc: [weylus](https://github.com/H-M-H/Weylus) for remote tablet support.
  [onedrive](https://github.com/abraunegg/onedrive) sync capability (command line only).
   [stylix](https://github.com/nix-community/stylix) for theming.
   [nh](https://github.com/nix-community/nh) for building the system.

Usage: `nh os switch .` while in this repository.

Implementation notes:
 - `hyprland.lua` is actually a nix function that returns Lua code. This is done to inject the executable
   paths.
 - Vim plugins are maintained in `home.nix`. Everything else is in `config/vimrc`.

Impurities:
 - Networking configurations are persisted instead of being in `configuration.nix`.

Future improvements:
 - More elegant way of stating requirements for Hyprland?

Adaptation notes:
 - My name and email is used in configuring git (`home.nix`).
 - My name is used to setup a user.
 - Some weird filesystem mischief is in `configuration.nix`.
 - A hashed password file (made with `mkpasswd -m sha-512` or something) must be in `/persist/secrets/<username>-password-hash`.
