# Repository Guidelines

## Project Structure & Module Organization

This is a host-specific NixOS flake for `pradtop`. `flake.nix` wires the system together; `configuration.nix` contains system settings, `hardware-configuration.nix` describes hardware and filesystems, and `home.nix` manages the user environment. Application configuration belongs in `config/`, helpers in `scripts/`, and wallpapers, shaders, fonts, or archives in `resources/`. Treat `-safeBackup-0001` files and generated `tags` as local output, not primary configuration.

## Build, Test, and Development Commands

- `nix flake check` evaluates the flake and runs any declared checks without activating it.
- `nh os test .` builds and temporarily activates the configuration; use this for most changes.
- `nh os boot .` selects the build for the next boot; prefer it for bootloader or filesystem changes.
- `nix flake update` refreshes locked inputs in `flake.lock`; review dependency changes before committing.

Run commands from the repository root. Evaluation may require NixOS on `x86_64-linux` and access to the configured flake inputs.

## Coding Style & Naming Conventions

Use two-space indentation in Nix files and preserve the existing compact attribute-set style. Prefer declarative Home Manager or NixOS options over ad hoc shell setup. Use lowercase, hyphenated names for scripts and assets (for example, `toggle-keyboard.nu`). Add comments only when a setting's purpose or system impact is not obvious. No repository-wide formatter is configured, so follow neighboring code.

## Testing Guidelines

There is no standalone automated test suite. At minimum, run `nix flake check`; for behavioral changes, follow with `nh os test .`. Exercise affected desktop components directly, such as Waybar, Hyprland, or Nushell scripts.

## Agent Safety

Agents must never run `nh os switch .`. Agents must also never run a command that deletes past bootloader generations, under any circumstance. A full boot partition or lack of disk space does not permit either action; report the condition and leave remediation to the user.

## Commit & Pull Request Guidelines

Recent commits use short, imperative summaries such as `Added hyprsunset` and `Updated theme`. Keep each commit focused and explain unusual system consequences in the body. Pull requests should summarize changed modules, list validation commands, and call out required reboots or migration steps. Include screenshots for visible Waybar, Hyprland, or notification styling changes.

## Security & Local Configuration

Never commit passwords, private keys, tokens, or files from `/persist/secrets`. Review hostnames, UUIDs, usernames, email addresses, and persistence paths before adapting this configuration to another machine.
