# Brewfile for talos-template
#
# Installs every CLI tool used or referenced by this repo.
# Usage: brew bundle
#
# Note: the optional virt-manager (QEMU/KVM) path also needs virt-manager,
# swtpm, and NetworkManager (nmcli) — Linux-only tools that Homebrew doesn't
# provide. See pkglist.txt for the Arch packages.

# tenv - version manager that installs/pins OpenTofu (`tofu`) from
# cluster/.opentofu-version. Do NOT install opentofu directly; tenv provides
# the `tofu` binary. Used for `tofu init/plan/apply` and cluster/update_opentofu.sh.
brew "tenv"

# talosctl - operating the nodes after OpenTofu has built them: health checks,
# logs, dashboards. The docs target Talos v1.11.x.
brew "talosctl"

# kubectl - merging kubeconfigs and using the cluster
brew "kubernetes-cli"

# zizmor - GitHub Actions workflow auditing, referenced in .github/workflows/opentofu-talos.yml
brew "zizmor"
