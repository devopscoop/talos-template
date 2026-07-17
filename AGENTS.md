# AGENTS.md

Instructions for AI coding agents working in this repo.

## Package manifests

This repo ships a `Brewfile` (macOS: `brew bundle`) and a `pkglist.txt` (Arch Linux) that install the CLI tools the repo uses. Keep them in sync with the docs:

- When the docs start instructing readers to run a new local tool, add the package to BOTH files, with a comment noting what uses it.
- When a tool stops being used, remove it from both files.
- Linux-only tools for the optional virt-manager (QEMU/KVM) path belong in pkglist.txt as commented-out optional entries (Homebrew can't provide them); mirror that pattern for similar additions.
- Verify package names before adding them: `brew info <formula>` for Homebrew, and the official repos/AUR for Arch (e.g. kubectl is Homebrew `kubernetes-cli` but Arch `kubectl`). If a package is AUR-only, note that in pkglist.txt's header instructions.
- Update the "Install required packages" section in README.md if the tool list changes.
