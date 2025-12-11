# Talos Linux

# Overview

These instructions are for creating a single-node Kubernetes homelab cluster on a machine running [ProxMox](https://www.proxmox.com/). Do not use DHCP - if your node IP address changes, it will no longer be connected to the cluster.

Based on:

- https://www.talos.dev/v1.11/introduction/getting-started/

# Prerequisites

- a ProxMox server
- a wasabisys.com account for offsite backups for Longhorn

# Process

1. Download a custom ISO image for ProxMox [here](https://factory.talos.dev/). Use default settings except for these:
   - Hardware Type: Cloud Server
   - Cloud: Nocloud
   - Machine Architecture:
     - Enable SecureBoot
   - System Extentions:
     - siderolabs/iscsi-tools # https://longhorn.io/docs/1.9.0/advanced-resources/os-distro-specific/talos-linux-support/
     - siderolabs/qemu-guest-agent # https://www.talos.dev/v1.11/talos-guides/install/virtualized-platforms/proxmox/#qemu-guest-agent-support-iso
     - siderolabs/util-linux-tools # https://longhorn.io/docs/1.9.0/advanced-resources/os-distro-specific/talos-linux-support/
1. Note the "Initial Installation" image - something like `factory.talos.dev/nocloud-installer-secureboot/88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b:v1.11.5` - you will need thast the for `talosctl gen config` command below.
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

      # Set the install-image to the image that
      talosctl gen config --with-secrets secrets.yaml $CLUSTER_NAME https://$YOUR_ENDPOINT:6443 --install-image=factory.talos.dev/nocloud-installer-secureboot/88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b:v1.11.5 --install-disk=/dev/sda --config-patch @tpm-disk-encryption.yaml
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

# Adding more nodes

1. Create config for first node:
   ```
   talosctl machineconfig patch controlplane.yaml --patch @controlplane-patch-worclustershire2.yaml --output worclustershire2.yaml
   talosctl machineconfig patch controlplane.yaml --patch @controlplane-patch-worclustershire3.yaml --output worclustershire3.yaml
   ```
1. SKIP (This doesn't appear to actually work): If you are using QEMU, change the image in your worclustershire3.yaml file to this:
   ```
   machine:
       install:
           image: factory.talos.dev/metal-installer/88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b:v1.11.5
   ```
1. Apply config:
   ```
   talosctl apply-config --insecure -n 192.168.8.163 -e 192.168.8.4 -f worclustershire2.yaml
   talosctl apply-config --insecure -n 192.168.8.216 -e 192.168.8.4 -f worclustershire3.yaml
   ```
1. Upgrade nodes so they have the proper extensions. See the Upgrading Talos section below.
1. Add the other nodes to the VIP???

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
talosctl upgrade --image factory.talos.dev/nocloud-installer-secureboot/88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b:v1.11.5 --nodes "${node_ip}" --preserve
```
