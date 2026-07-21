# Dotfiles

This repository uses [nix](https://nixos.org/) to automatically populate a bunch of
dotfiles and generally setup my system. This is mainly for **my use** in case I mess up
my system (it has my name and email in places).

Features:
 - Visuals: [hyprland](https://hypr.land/) with [waybar](https://github.com/Alexays/Waybar) (taskbar) and
   [awww](https://codeberg.org/LGFae/awww) (wallpaper). [hyprlock](https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/)
   for the lockscreen.
 - Terminal: [nushell](https://www.nushell.sh/) with [carapace](https://carapace.sh/) for completions,
   [starship](https://starship.rs/) for the prompt, [zoxide](https://github.com/ajeetdsouza/zoxide).
   [vim](https://www.vim.org/) with [ctags](https://en.wikipedia.org/wiki/ctags) support, as well as
   [UltiSnips](https://github.com/SirVer/ultisnips) and [VimTeX](https://github.com/lervag/vimtex).
   [Kitty](https://sw.kovidgoyal.net/kitty/) as terminal emulator.
 - Desktop tools: [libreoffice](https://www.libreoffice.org/), [speedcrunch](https://heldercorreia.bitbucket.io/speedcrunch/)
   as calculator, [pass](https://www.passwordstore.org/) as password manager. [vicinae](https://www.vicinae.com/)
   for launcher. [pabc](https://github.com/techieji/pabc) for brightness control.
 - Misc: [weylus](https://github.com/H-M-H/Weylus) for remote tablet support.
  [onedrive](https://github.com/abraunegg/onedrive) sync capability (command line only).
   [stylix](https://github.com/nix-community/stylix) for theming.
   [nh](https://github.com/nix-community/nh) for building the system.

Usage: `nh os switch .` while in this repository.

Implementation notes:
 - `hyprland.lua` is actually a nix function that returns Lua code. This is done to inject the executable
   paths.
 - Vim plugins are maintained in `home.nix`. Everything else is in `vimrc`.

Currently remaining impurities:
 - Font: Iosevka (with custom options)
 - Cursor: TheDot (maybe convert to hyprcursor?)

Future improvements:
 - Get rid of Flatpak! (is only used for [Weylus Community Edition](https://github.com/electronstudio/WeylusCommunityEdition))
   - Related: get rid of the weylus in `configuration.nix` if it is not being used; manually open the firewall and set user groups.
 - Determine whether gstreamer is needed for Weylus.
 - More elegant way of stating requirements for Hyprland?

Adaptation notes:
 - My name and email is used in configuring git (`home.nix`).
 - My name is used to setup a user.
 - Some weird filesystem mischief is in `configuration.nix`.
