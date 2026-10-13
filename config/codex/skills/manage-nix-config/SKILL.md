---
name: manage-nix-config
description: Manage declarative NixOS, Home Manager, and flake configuration and install, remove, or configure tools through Nix. Use when Codex needs to add packages, enable programs or services, edit Nix modules or flake inputs, diagnose Nix evaluation or build failures, or validate a Nix-managed system without unsafe activation or generation cleanup.
---

# Manage Nix Configuration

## Work declaratively

1. Read the repository's AGENTS.md and nearby Nix modules before editing.
2. Identify whether the requested change belongs to NixOS, Home Manager, or a project dev shell.
3. Prefer an existing module option over adding a raw package or imperative setup.
4. Keep host-specific values and the repository's established module layout intact.
5. Make the smallest focused change and explain any reboot, migration, or state impact.

Do not use nix-env -i, nix profile install, downloaded install scripts, or manual files under /etc when the repository can express the result declaratively.

## Choose the package scope

- Put system services, drivers, shells, and tools required before login in NixOS configuration.
- Put interactive user applications and CLI tools in Home Manager.
- Use programs.<name>.enable or services.<name>.enable when available; use package lists only when no suitable module exists.
- Put build-only dependencies in a dev shell rather than the host configuration.
- Add a flake input only when the software is unavailable or unsuitable in the pinned nixpkgs. Follow the input's nixpkgs dependency when compatible.
- Use nix search nixpkgs <name> or evaluate package attributes to confirm names instead of guessing.

When packaging software yourself, pin its source and hash, keep runtime dependencies explicit, and avoid introducing overlays unless reuse justifies one.

## Edit safely

- Preserve two-space indentation and neighboring compact attribute-set style.
- Avoid changing flake.lock unless adding or updating an input is part of the request.
- Never include passwords, tokens, private keys, or /persist/secrets contents.
- Review persistence requirements for applications that keep state on ephemeral-root systems.
- Preserve unrelated worktree changes and generated backup files.

## Validate

Run checks from the flake root in this order, stopping to diagnose failures:

1. Parse or evaluate the affected module when a narrow check is available.
2. Run nix flake check --no-build for an evaluation-only check.
3. Run nix flake check when builds are appropriate.
4. For behavioral or system changes, run nh os test . only when the repository permits it and the user has authorized temporary activation.
5. For every user-facing CLI, confirm its package is directly present in the user's Home Manager or NixOS package set; a runtime dependency of another wrapper does not expose it on PATH.
6. After activation, test command -v <command> and <command> --version from the user's normal login shell. Do not substitute a Nix store path, development shell, root shell, or agent-specific PATH for this check.
7. Exercise the affected application, service, desktop component, or command when practical.
8. After Home Manager activation, verify every managed config or skill exists at its intended destination. For a Home Manager file source, use test -L and readlink on the destination and confirm it resolves into the active Home Manager generation or Nix store source. Check the application-specific discovery directory, not only the repository source.
9. If activation was not authorized or performed, state that the declaration was evaluated but runtime PATH and symlink accessibility could not yet be verified.

Report checks that were not run and why. Do not claim a config is installed or exposed merely because evaluation passed.

## Hard safety boundaries

- Never run nh os switch .
- Never delete or prune bootloader or NixOS generations.
- Do not substitute nixos-rebuild switch, nix-collect-garbage -d, or equivalent commands.
- Do not weaken sandbox, secret, authentication, filesystem, or boot protections merely to make evaluation pass.
- Use nh os boot . only when the user explicitly requests a next-boot deployment and understands that a reboot is required.
- Stop and report disk-space or boot-partition problems; leave generation cleanup to the user.

## Installing a tool

For a typical installation:

1. Confirm the package or module name against the pinned inputs.
2. Select NixOS, Home Manager, or dev-shell scope.
3. Enable its module and integrations, or add its package.
4. Add only necessary configuration, persistence, environment variables, and service wiring.
5. Update the lock only if a new flake input was required.
6. Run the validation sequence and summarize where the tool was added.
