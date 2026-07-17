# Brewfile for talos-template
#
# Installs every CLI tool used or referenced by this repo.
# Usage: brew bundle
#
# Note: the optional virt-manager (QEMU/KVM) path also needs virt-manager,
# swtpm, and NetworkManager (nmcli) — Linux-only tools that Homebrew doesn't
# provide. See pkglist.txt for the Arch packages.

# talosctl - generates Talos secrets/config, applies config, bootstraps the
# cluster, fetches kubeconfig, upgrades nodes. The docs target Talos v1.11.x.
brew "talosctl"

# kubectl - merging kubeconfigs and using the cluster
brew "kubernetes-cli"
