# AGENTS.md

Instructions for AI coding agents working in this repo. `CLAUDE.md` is a symlink
to this file — edit `AGENTS.md`, and do not replace the symlink with a real file.

## What this repo is

A template for a Talos Linux Kubernetes homelab cluster on ProxMox, managed with
OpenTofu and the `siderolabs/talos` provider (pinned to 0.12.0). The VMs are
created by hand following `README.md`. Everything after that lives in `cluster/`:
the image schematic, the secrets, the machine configs, apply, bootstrap, and
OS and Kubernetes upgrades. `.github/workflows/opentofu-talos.yml` plans on
PRs and applies on merge to `main`.

Consequences for agents:

- Use `tofu`, never `terraform`. The version is pinned in
  `cluster/.opentofu-version` (read by tenv and by `setup-opentofu` in CI) and
  in `required_version` in `cluster/versions.tf`. `cluster/update_opentofu.sh`
  keeps the two in sync.
- Local checks: `tofu fmt -recursive -check` and `tofu validate` (after `tofu init -backend=false`). `talosctl validate --config <file> --mode metal` works
  on a rendered machine config, not on the patch fragments.
- Nothing beyond that can be verified without the real nodes. Do not claim a
  change is tested. Never run `tofu apply` against the real backend unless
  asked: an apply can reboot or upgrade nodes.
- A change to `cluster/` and the README step that describes it is one unit.

## How `cluster/` fits together

```
image.tf    extensions -> talos_image_factory_schematic -> urls (iso_url, installer_secureboot)
main.tf     talos_machine_secrets
              -> data.talos_machine_configuration.node[each]   (common patches + install + network)
              -> talos_machine.node[each]                      (apply config, OS upgrades, drain)
              -> talos_cluster.this                            (bootstrap etcd, upgrade-k8s)
              -> talos_cluster_kubeconfig.this / data.talos_client_configuration.this -> outputs
```

Things that are easy to get wrong:

- Patch order lives in `local.common_patches` (`patches/*.yaml`), followed by
  the generated install and network patches. A cluster-wide setting is a new
  file in `patches/`, added to that list. A per-node or parameterized setting
  goes in the `yamlencode` patches in `main.tf`.
- The VIP and each node's static address are in **one** interface entry
  (`deviceSelector.busPath: "0*"`). Do not split them into separate patches;
  if you must, the selector has to be byte-identical or Talos creates two
  interfaces.
- `talos_machine` uses `for_each`, so the nodes can't be chained with
  `depends_on`. Rolling upgrades depend on `apply -parallelism=1`, which the
  README and the workflow both use. Keep it in both places.
- `ignore_kubernetes_upgrade_drift = true` on `talos_machine` makes
  `talos_cluster` the only thing that upgrades Kubernetes. Keep
  `kubernetes_version` shared between `talos_cluster` and the machine
  configuration (it is a single variable).
- `talos_config_contract` (the machine-config schema, e.g. `v1.11`) is
  deliberately separate from `talos_version` (the installed OS). Never bump the
  contract as part of an OS upgrade.
- `talos_machine` connects to the node at its static IP, including the first
  apply in maintenance mode, and it waits at the same address after the
  reboot. That is why the README requires a DHCP reservation equal to the
  static IP. Don't "fix" this by pointing `endpoint` at a DHCP address: the
  wait-for-boot would hang on the old address.
- The talosconfig endpoints are the node IPs, not the VIP, on purpose.
- All-control-plane cluster. No worker configs exist, and
  `patches/allow-scheduling-on-control-planes.yaml` is why workloads run.

## Template values

The checked-in values are one person's homelab. They all live in
`cluster/terraform.tfvars` (bucket, cluster name, `nodes`, VIP, gateway,
versions, extensions). The workflow has its own placeholders: `aws-region` and
`role-to-assume`.

## Secrets

- The state holds the cluster PKI (`talos_machine_secrets`). It is encrypted
  by OpenTofu (`encryption` block, pbkdf2 + AES-GCM, `enforced = true`) with
  `TF_VAR_state_passphrase`, which is the `TOFU_STATE_PASSPHRASE` secret in CI.
  Never weaken `enforced`, never add a fallback, and never put the passphrase
  in a file.
- Never print the `talosconfig`/`kubeconfig` outputs or `machine_configuration`
  values into an issue, PR, commit, or chat. Don't use `nonsensitive()` on them
  in committed code.
- `.gitignore` covers `.terraform/`, state and plan files, and the credential
  files the old `talosctl` workflow produced. Commit
  `cluster/.terraform.lock.hcl`.

## Conventions

- Every file in `cluster/patches/`, and every inline patch in `main.tf`, carries
  a comment linking the upstream Talos or Longhorn doc that justifies it.
  Preserve this when editing, and add the link when introducing a new patch —
  it is how a reader tells a deliberate setting from a copied one.
- The docs target **Talos v1.11**. The version appears in doc URLs,
  `talos_version`/`talos_config_contract` in `terraform.tfvars`, and the
  package manifest comments. Bumping it means updating all of them.
- Provider and OpenTofu versions are exact pins, not ranges. Dependabot bumps
  the provider (`terraform` ecosystem, `/cluster`) and the actions.
- GitHub Actions are pinned to full commit SHAs with a trailing `# v4`-style
  comment. Keep new actions pinned the same way. The workflow runs on a
  self-hosted runner on the LAN. Keep the fork-PR guard in its `if:`.
- Nodes must use static IPs (`dhcp: false`). A node whose address changes drops
  out of the cluster.

## Package manifests

This repo ships a `Brewfile` (macOS: `brew bundle`) and a `pkglist.txt` (Arch Linux) that install the CLI tools the repo uses. Keep them in sync with the docs:

- When the docs start instructing readers to run a new local tool, add the package to BOTH files, with a comment noting what uses it.
- When a tool stops being used, remove it from both files.
- Linux-only tools for the optional virt-manager (QEMU/KVM) path belong in pkglist.txt as commented-out optional entries (Homebrew can't provide them); mirror that pattern for similar additions.
- Verify package names before adding them: `brew info <formula>` for Homebrew, and the official repos/AUR for Arch (e.g. kubectl is Homebrew `kubernetes-cli` but Arch `kubectl`). If a package is AUR-only, note that in pkglist.txt's header instructions.
- Update the "Install required packages" section in README.md if the tool list changes.
