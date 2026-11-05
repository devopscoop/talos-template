# Talos Linux

# Overview

These instructions are for creating a Kubernetes homelab cluster of [Talos Linux](https://www.talos.dev/) VMs on [ProxMox](https://www.proxmox.com/). Every node is a control plane that also runs workloads.

You create the VMs by hand. [OpenTofu](https://opentofu.org/) and the [siderolabs/talos provider](https://github.com/siderolabs/terraform-provider-talos/tree/v0.12.0) do everything else, all from `cluster/`:

- build the Talos image (an Image Factory schematic with the system extensions) and give you its ISO URL
- generate the cluster secrets and one machine config per node
- apply the configs, bootstrap etcd, and wait for the cluster
- upgrade Talos (change `talos_version`) and Kubernetes (change `kubernetes_version`) in place
- output `talosconfig` and `kubeconfig`

Do not use DHCP: if a node's IP address changes, it drops out of the cluster.

Based on:

- https://www.talos.dev/v1.11/introduction/getting-started/
- https://www.talos.dev/v1.11/introduction/prodnotes/
- https://github.com/siderolabs/terraform-provider-talos/tree/v0.12.0/docs

# Prerequisites

- a ProxMox server
- an S3 (or S3-compatible, e.g. Wasabi) bucket for the OpenTofu state
- a wasabisys.com account for offsite backups for Longhorn
- for CI: a [self-hosted GitHub Actions runner](https://docs.github.com/en/actions/hosting-your-own-runners) on the node network (see [CI](#ci))

## Install required packages

This repo ships package manifests that install the CLI tools it uses (`tenv`, which provides `tofu`; `talosctl`; `kubectl`; and `zizmor` for auditing the workflow):

- macOS, using [Homebrew](https://brew.sh/) and the `Brewfile`:

  ```shell
  brew bundle
  ```

- Arch Linux, using the `pkglist.txt` (`tenv-bin` is in the AUR, so use an AUR helper):

  ```shell
  grep -vE '^(#|$)' pkglist.txt | yay -S --needed -
  ```

Then install the pinned OpenTofu version. Don't install `opentofu` directly; `tenv` reads `cluster/.opentofu-version`:

```shell
tenv tofu install "$(cat cluster/.opentofu-version)"
```

On other operating systems, install the tools listed above manually. The optional virt-manager (QEMU/KVM) path below additionally needs `virt-manager`, `swtpm`, and NetworkManager — Linux-only tools listed as commented-out entries in `pkglist.txt`.

## The state passphrase

The OpenTofu state contains the cluster's PKI (the etcd, Kubernetes and Talos CA keys), so `cluster/versions.tf` encrypts the state and plan files with a passphrase, on top of the bucket's own encryption. Generate one, keep it in your password manager, and export it whenever you run `tofu`:

```shell
openssl rand -base64 32   # once; store the result
export TF_VAR_state_passphrase='<the passphrase>'
```

If you lose the passphrase, you lose the state, and with it the only copy of the cluster CA keys. Never put it in `terraform.tfvars`.

# Process

1. Edit `cluster/terraform.tfvars`. The checked-in values are one homelab: change the bucket, cluster name, node hostnames and IPs, VIP, and gateway. For a non-AWS bucket, set `s3_endpoint`.
1. Initialize, and build just the image, so you have an ISO to boot the VMs from:
   ```shell
   cd cluster
   tofu init
   tofu apply -target=talos_image_factory_schematic.this -target=data.talos_image_factory_urls.this
   tofu output -raw iso_url
   ```
   The schematic bakes in these extensions (see `extensions` in `terraform.tfvars`):
   - `siderolabs/iscsi-tools` and `siderolabs/util-linux-tools`, for [Longhorn](https://longhorn.io/docs/1.9.0/advanced-resources/os-distro-specific/talos-linux-support/)
   - `siderolabs/qemu-guest-agent`, for [ProxMox](https://www.talos.dev/v1.11/talos-guides/install/virtualized-platforms/proxmox/#qemu-guest-agent-support-iso)
1. In ProxMox, download the ISO from that URL into your ISO storage ("Download from URL"), or follow [these instructions](https://www.talos.dev/v1.11/talos-guides/install/virtualized-platforms/proxmox/#upload-iso) to upload it.
1. For each node, click the "Create VM" button in ProxMox. Use default settings except for these:
   - General:
     - Name: the node's hostname from `nodes` in `terraform.tfvars`, e.g. `worclustershire1`.
     - Check the Advanced box
     - Enable "Start at boot"
   - OS:
     - ISO image: nocloud-amd64-secureboot.iso
   - System:
     - Graphic card: VirtIO-GPU (for a higher resolution terminal)
     - BIOS: OVMF (UEFI)
     - EFI Storage: local-lvm
     - Disable "Pre-Enroll keys"
     - Enable "QEMU Agent"
     - Enable "Add TPM"
     - TPM Storage: local-lvm
   - Disks:
     - 1st drive: 5G
     - 2nd drive: 500G
   - CPU:
     - Cores: 2
   - Memory: as much as possible, but reserve at least 1GB for the ProxMox host.
   - Network: note the VM's MAC address (Hardware > Network Device).
   - Confirm:
     - Do **not** enable "Start after created" yet.
1. In your router, add a DHCP reservation that gives each VM's MAC address the same IP as its entry in `nodes`. The VM boots from the ISO into maintenance mode with a DHCP address, and OpenTofu has to find it there: the provider connects to the node at that IP, applies the config, and then waits for the node at the *same* address while it reboots with its static IP. Then start the VMs.
1. Create the cluster. `-parallelism=1` makes OpenTofu configure and later upgrade one node at a time:
   ```shell
   tofu plan -out=plan.file
   tofu apply -parallelism=1 plan.file
   ```
   This applies each node's config (TPM disk encryption, scheduling on control planes, Longhorn prerequisites, install image, and a static IP plus the VIP), bootstraps etcd on the first node, and waits until etcd, apid and kubelet are healthy on all of them.
1. Save the talosconfig:
   ```shell
   tofu output -raw talosconfig > ~/.talos/config.worclustershire
   talosctl config merge ~/.talos/config.worclustershire && rm ~/.talos/config.worclustershire
   talosctl health
   ```
   Its endpoints are the node IPs, not the VIP. The [VIP depends on etcd and Kubernetes](https://www.talos.dev/v1.11/talos-guides/network/vip/#caveats), so it is down exactly when you most need `talosctl`.
1. Get the kubeconfig:
   ```shell
   tofu output -raw kubeconfig > ~/.kube/worclustershire
   ```
1. Merge kubeconfig:
   ```shell
   cp ~/.kube/config ~/.kube/config.$(date +%s) && export KUBECONFIG=$(find "${HOME}/.kube" -maxdepth 1 -type f ! -name config ! -name 'config.*' | tr "\n" ":"); kubectl config view --flatten > ~/.kube/config; chmod 600 ~/.kube/config; unset KUBECONFIG;
   ```

# Adding more nodes

1. Add the node to `nodes` in `cluster/terraform.tfvars`.
1. Create its VM and DHCP reservation as above.
1. Plan and apply with `-parallelism=1`. Only the new `talos_machine` (and `talos_cluster`'s list of control-plane nodes) should change.

# Adopting an existing cluster

To move a cluster built with the old `talosctl gen config` runbook into OpenTofu without rebuilding it, import its secrets instead of generating new ones. Do this before the first full apply:

```shell
cd cluster
tofu init
tofu import talos_machine_secrets.this /path/to/secrets.yaml
tofu plan
```

`talos_machine` and `talos_cluster` have no import. On the first apply, `talos_machine` applies the generated config to each running node, and `talos_cluster` treats "already bootstrapped" as success. Before you apply, check the plan and the rendered configs:

- `kubernetes_version` must be what is running (`kubectl version`), or the apply upgrades Kubernetes.
- The generated configs replace whatever was applied by hand. Any setting that exists only on the nodes is lost, so port it into `cluster/patches/` or `main.tf` first.
- For the checked-in extensions and `talos_version`, the installer image is identical to the one the old runbook used (`…/88d1f7a5c4f1…:v1.11.5`), so no OS upgrade is triggered.

After the apply, delete the old `secrets.yaml`, `talosconfig` and `*.yaml` node configs. The state now holds the only copy that matters.

# virt-manager (QEMU/KVM)

1. Ensure that you have the swtpm package installed.
1. Create a new VM with these settings:
   - Local install media
   - Choose ISO: Use the one downloaded above
   - Uncheck "Automatically detect from installation media"
   - Choose the operating system you are installing: Generic Linux 2024
   - Memory: 6144
   - CPUs: 2
   - In Overview, change Firmware to "UEFI x86_64: /usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd"
   - Click Add Hardware, and choose TPM.
1. Create a bridge:
   ```
   nmcli con add type bridge con-name br0 ifname br0
   nmcli con add type bridge-slave ifname enp0s31f6 master br0
   nmcli connection delete Wired\ connection\ 1
   # Wait a minute or two for DHCP to work.
   ```

# Longhorn

The Longhorn prerequisites (an rshared bind mount of `/var/lib/longhorn`, hugepages, and the `nvme_tcp`/`vfio_pci` kernel modules) are in `cluster/patches/longhorn.yaml`, which every node gets. See [Longhorn's Talos guide](https://longhorn.io/docs/1.9.0/advanced-resources/os-distro-specific/talos-linux-support/).

# Upgrading Talos

Based on:

- https://www.talos.dev/v1.11/talos-guides/upgrading-talos/
- https://github.com/siderolabs/terraform-provider-talos/blob/v0.12.0/docs/resources/machine.md

Change `talos_version` in `cluster/terraform.tfvars`, then plan and apply with `-parallelism=1` (the workflow does this). For each node, in turn, `talos_machine` pulls the new installer, drains the node, reboots it, and uncordons it. Changing `extensions` works the same way: it changes the schematic, and that triggers an upgrade.

Leave `talos_config_contract` alone. It is the machine-config schema the cluster was created with, not the installed version, and bumping it regenerates every config with the newer version's defaults.

The old runbook passed `--preserve` so Longhorn data survives. On Talos v1.11, `talosctl` hides that flag and the node ignores it: upgrades always keep the EPHEMERAL partition, where `/var/lib/longhorn` lives.

# Upgrading Kubernetes

Change `kubernetes_version` in `cluster/terraform.tfvars`, then plan and apply. `talos_cluster` runs Talos's [upgrade-k8s](https://www.talos.dev/v1.11/kubernetes-guides/upgrading-kubernetes/) procedure, which upgrades the control-plane components and kubelets one at a time with health checks.

# Upgrading OpenTofu

```shell
cluster/update_opentofu.sh
```

This writes the latest stable version to `cluster/.opentofu-version` and `required_version` in `cluster/versions.tf`, then installs it with `tenv`.

# CI

`.github/workflows/opentofu-talos.yml` runs `tofu plan` on pull requests to `main` and comments the plan on the PR. When the PR merges to `main`, it applies that plan with `-parallelism=1`. It doesn't run in the `devopscoop/talos-template` repo itself. To set it up:

1. Register a [self-hosted runner](https://docs.github.com/en/actions/hosting-your-own-runners) on the node network. GitHub-hosted runners can't reach the nodes, and both plan and apply talk to them. The workflow skips PRs from forks so their code never runs on your LAN; also keep the repo private, or require approval for outside collaborators.
1. Add the state passphrase as the repository secret `TOFU_STATE_PASSPHRASE`.
1. Give the runner credentials for the state bucket. For AWS, set `role-to-assume` and `aws-region` in the workflow to an IAM role that trusts GitHub's OIDC provider and can read and write the bucket. For a non-AWS store, replace that step with `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` repository secrets, as the comment in the workflow describes.
