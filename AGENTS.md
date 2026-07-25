# AGENTS.md

Instructions for AI coding agents working in this repo. `CLAUDE.md` is a symlink
to this file — edit `AGENTS.md`, and do not replace the symlink with a real file.

## What this repo is

A template/runbook for standing up a Talos Linux Kubernetes homelab cluster on
ProxMox. There is no application code, no build, no test suite, and no linter —
the deliverables are `README.md` (a numbered runbook a human follows by hand) and
the YAML patch fragments it feeds to `talosctl`.

Consequences for agents:

- Changing a YAML patch means changing the README step that applies it, and vice
  versa. They are a single unit; neither is self-documenting.
- Nothing here can be verified by running it — a real ProxMox host, a booted
  Talos ISO, and node IPs are required. Do not claim a change is tested.
- `talosctl validate --config <file> --mode metal` is the one useful local check
  on a *generated* machine config. It does not work on the bare patch fragments
  in this repo, since they are partial documents.

## The patch pipeline

The patch files are not applied independently — they layer in a fixed order, and
each `talosctl machineconfig patch` writes back **in place** with
`--output controlplane.yaml`, so patches accumulate on one growing base file:

```
talosctl gen config --config-patch @tpm-disk-encryption.yaml   # -> controlplane.yaml, worker.yaml, talosconfig
  + @controlplane-patch-allowSchedulingOnControlPlanes.yaml    # -> controlplane.yaml (in place)
  + @controlplane-patch-vip.yaml                               # -> controlplane.yaml (in place)
  + @controlplane-patch-<cluster><N>.yaml                      # -> <cluster><N>.yaml  (per node, forks off)
  + @longhorn-patch.yaml                                       # -> <cluster><N>.yaml  (per node, in place)
```

Things this ordering implies, which are easy to get wrong:

- `tpm-disk-encryption.yaml` is passed to `gen config`, not to `machineconfig
  patch`. It must be applied at generation time, because rekeying LUKS on an
  already-installed node is not a config patch.
- Every node config inherits allowSchedulingOnControlPlanes and the VIP, because
  both are merged into `controlplane.yaml` before any node forks off it. Adding
  a cluster-wide setting means inserting it *before* the per-node step.
- `controlplane-patch-vip.yaml` and the per-node patches both target the network
  interface using the identical `deviceSelector: busPath: "0*"`. That is what
  makes them merge into one interface instead of producing two. Keep the
  selector byte-identical when adding interface patches.
- `worker.yaml` is generated but never used. This is an all-control-plane
  cluster; that is the reason allowSchedulingOnControlPlanes exists here.

## Template values

This is a template, and the checked-in values are one person's homelab. A new
cluster requires editing these, mostly by hand:

| Value | Where |
| --- | --- |
| Cluster name `worclustershire` | patch filenames, `hostname:` in each node patch, README `CLUSTER_NAME` |
| Node IPs `192.168.8.4/.5/.6` | `controlplane-patch-<cluster><N>.yaml` |
| VIP `192.168.8.7` | `controlplane-patch-vip.yaml`, README `YOUR_ENDPOINT` |
| Gateway `192.168.8.1` | each node patch |
| Installer image digest | README (`--install-image`, and the upgrade command) |

Node patch files follow `controlplane-patch-<clustername><N>.yaml`, and the
`hostname:` inside must match the filename. Adding a fourth node means a new
patch file plus README steps in both "Adding more nodes" and the apply block.

## Conventions

- Every YAML patch opens with a comment linking the upstream Talos or Longhorn
  doc that justifies it. Preserve this when editing, and add the link when
  introducing a new patch — it is how a reader tells a deliberate setting from a
  copied one.
- The docs target **Talos v1.11**. The version appears in doc URLs, the
  `:v1.11.5` image tags, and the package manifest comments. Bumping it means
  updating all three, not just the image tag.
- GitHub Actions are pinned to full commit SHAs with a trailing `# v4`-style
  comment. Keep new actions pinned the same way.
- Nodes must use static IPs (`dhcp: false`). A node whose address changes drops
  out of the cluster.

## Generated files and secrets

There is no `.gitignore`. Following the README produces `secrets.yaml`,
`talosconfig`, `controlplane.yaml`, `worker.yaml`, and `<cluster><N>.yaml` in the
repo root — `secrets.yaml` and `talosconfig` hold cluster PKI. Never commit
these, and never paste their contents into an issue, PR, or commit message. The
README carries an open `TODO: Encrypt your secrets.yaml file`.

## Package manifests

This repo ships a `Brewfile` (macOS: `brew bundle`) and a `pkglist.txt` (Arch Linux) that install the CLI tools the repo uses. Keep them in sync with the docs:

- When the docs start instructing readers to run a new local tool, add the package to BOTH files, with a comment noting what uses it.
- When a tool stops being used, remove it from both files.
- Linux-only tools for the optional virt-manager (QEMU/KVM) path belong in pkglist.txt as commented-out optional entries (Homebrew can't provide them); mirror that pattern for similar additions.
- Verify package names before adding them: `brew info <formula>` for Homebrew, and the official repos/AUR for Arch (e.g. kubectl is Homebrew `kubernetes-cli` but Arch `kubectl`). If a package is AUR-only, note that in pkglist.txt's header instructions.
- Update the "Install required packages" section in README.md if the tool list changes.
