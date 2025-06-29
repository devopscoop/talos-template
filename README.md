# Talos Linux

# Overview

I'm currently creating a Kubernetes cluster using a single machine with [ProxMox](https://www.proxmox.com/) installed. I've created three VMs in ProxMox and booted from a [custom QEMU image](https://www.talos.dev/v1.10/talos-guides/install/virtualized-platforms/proxmox/#qemu-guest-agent-support-iso).

# Create VMs in ProxMox

Create first machine, with these specifications:

- CPU: 4 sockets, 2 cores
- RAM: 2GiB
- 1st drive: 5G
- 2nd drive: 32G
- Enable QEMU Agent
- Change boot order to SCSI, then IDE/CD/DVD.
- Change Display to VirtIO-GPU for a higher resolution terminal.
- Set it to start at boot

Then clone it, creating a total of 3 machines.

# Creating a Kubernetes cluster

See https://www.talos.dev/v1.9/introduction/getting-started/

Run ./deploy.sh.

# SKIP: Configuring dynamic Local Storage

See: 
- https://www.talos.dev/v1.10/kubernetes-guides/configuration/local-storage/
- https://github.com/rancher/local-path-provisioner

```
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.31/deploy/local-path-storage.yaml
```



# Upgrading Talos

https://www.talos.dev/v1.9/talos-guides/upgrading-talos/#talosctl-upgrade

```
talosctl upgrade --image ghcr.io/siderolabs/installer:v1.10.0 --nodes "${node_ip}" --endpoints "${cluster_endpoint_ip}" --talosconfig=./talosconfig
```

Dont forget to change your kubeconfig to have the VIP as the endpoint.

TODO: Still seems to have a single endpoint. Shit is being weird. Maybe because I rebooting too many nodes at once.
