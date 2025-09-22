# Talos Linux

# Overview

These instructions are for creating a single-node Kubernetes homelab cluster on a machine running [ProxMox](https://www.proxmox.com/). Do not use DHCP - if your node IP address changes, it will no longer be connected to the cluster.

# Prerequisites

- a ProxMox server

# Process

1. Download a custom ISO image for ProxMox [here](https://factory.talos.dev/). Use default settings except for these:
   - Hardware Type: Cloud Server
   - Cloud: Nocloud
   - Machine Architecture:
     - Enable SecureBoot
   - System Extentions:
     - siderolabs/iscsi-tools # Needed for Longhorn
     - siderolabs/qemu-guest-agent
     - siderolabs/util-linux-tools # Needed for Longhorn
1. Follow [these instructions](https://www.talos.dev/v1.11/talos-guides/install/virtualized-platforms/proxmox/#upload-iso) to upload the ISO image to the ProxMox server(s).
1. In ProxMox, click the "Create VM" button. Use default settings except for these:
   - General:
     - Name: Use the naming scheme `${cluster_name}${integer}`, e.g., `mycluster1`.
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
   - Confirm:
     - Enable "Start after created"
1. In ProxMox, select the VM you just created, then click on "Console".
1. Follow [these instructions](https://www.talos.dev/v1.11/introduction/prodnotes/) to create a production cluster. For example:
   1. Set vars and generate secrets and config:
      ```
      CONTROL_PLANE_IP=("192.168.8.4")
      export YOUR_ENDPOINT=192.168.8.7
      talosctl gen secrets -o secrets.yaml
      export CLUSTER_NAME=worclustershire
      talosctl gen config --with-secrets secrets.yaml $CLUSTER_NAME https://$YOUR_ENDPOINT:6443 --install-image=factory.talos.dev/installer-secureboot/376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba:v1.11.1 --install-disk=/dev/sda --config-patch @tpm-disk-encryption.yaml
      ```
   1. Allow scheduling workloads on the control plane node:
      ```
      talosctl machineconfig patch controlplane.yaml --patch @controlplane-patch-allowSchedulingOnControlPlanes.yaml --output controlplane.yaml
      ```
   1. Add cluster_endpoint_ip as a VIP:
      ```
      talosctl machineconfig patch controlplane.yaml --patch @controlplane-patch-vip.yaml --output controlplane.yaml
      ```
   1. Create config for first node:
      ```
      talosctl machineconfig patch controlplane.yaml --patch @controlplane-patch-worclustershire1.yaml --output worclustershire1.yaml
      ```
   1. Apply config to my first node (after booting from ISO, DHCP assigned it 192.168.8.107):
      ```
      talosctl apply-config --insecure --nodes 192.168.8.107 --file worclustershire1.yaml
      ```
   1. Merge talos config:
      ```
      talosctl config merge ./talosconfig
      ```
   1. Set endpoints:
      ```
      talosctl config endpoint 192.168.8.4
      ```
   1. Bootstrap the cluster on your first control plane node:
      ```
      talosctl bootstrap --nodes 192.168.8.4
      ```
   1. Once it's booted up, change the endpoint to your VIP:
      ```
      talosctl config endpoint $YOUR_ENDPOINT
      ```
   1. Get kubeconfig:
      ```
      talosctl kubeconfig --nodes $YOUR_ENDPOINT ~/.kube/worclustershire
      ```
   1. Merge kubeconfig:
      ```
      cp ~/.kube/config ~/.kube/config.$(date +%s) && export KUBECONFIG=$(find "${HOME}/.kube" -maxdepth 1 -type f ! -name config ! -name 'config.*' | tr "\n" ":"); kubectl config view --flatten > ~/.kube/config; chmod 600 ~/.kube/config; unset KUBECONFIG;
      ```
   1. TODO: Encrypt your secrets.yaml file

# Longhorn

1. Patch your nodes:
   ```
   talosctl machineconfig patch worclustershire1.yaml --patch @longhorn-patch.yaml --output worclustershire1.yaml
   ```
1. Apply the patch:
   ```
   talosctl apply-config --nodes 192.168.8.4 --file worclustershire1.yaml
   ```

# Upgrading Talos

Based on:

- https://www.talos.dev/v1.11/talos-guides/upgrading-talos/
- https://longhorn.io/docs/1.9.0/advanced-resources/os-distro-specific/talos-linux-support/#talos-linux-upgrades

```
talosctl upgrade --image ghcr.io/siderolabs/installer:v1.11.0 --nodes "${node_ip}" --preserve
```

# Based on

- https://www.talos.dev/v1.11/talos-guides/install/virtualized-platforms/proxmox/#qemu-guest-agent-support-iso
- https://www.talos.dev/v1.11/introduction/getting-started/
