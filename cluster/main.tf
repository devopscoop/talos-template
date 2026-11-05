# Talos cluster: one set of machine secrets, one machine config per node, then
# talos_machine (apply config, keep the OS at var.talos_version) and
# talos_cluster (bootstrap etcd, keep Kubernetes at var.kubernetes_version).
# https://github.com/siderolabs/terraform-provider-talos/tree/v0.12.0/docs

locals {
  cluster_endpoint = "https://${var.vip}:6443"
  node_ips         = [for node in values(var.nodes) : node.ip]
  # talos_cluster bootstraps etcd on exactly one node. Sorting the hostnames
  # makes this stable (worclustershire1 for the checked-in values).
  bootstrap_node = var.nodes[sort(keys(var.nodes))[0]].ip

  # Applied to every node, in order. Each file opens with the upstream doc that
  # justifies it.
  common_patches = [
    file("${path.module}/patches/tpm-disk-encryption.yaml"),
    file("${path.module}/patches/allow-scheduling-on-control-planes.yaml"),
    file("${path.module}/patches/longhorn.yaml"),
  ]
}

# The cluster's CAs and tokens. This lives in state, which is why versions.tf
# encrypts it. To adopt an existing cluster, import its secrets.yaml instead of
# generating new ones (README: Adopting an existing cluster).
resource "talos_machine_secrets" "this" {
  talos_version = var.talos_config_contract
}

data "talos_machine_configuration" "node" {
  for_each = var.nodes

  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_config_contract
  kubernetes_version = var.kubernetes_version

  config_patches = concat(local.common_patches, [
    # https://www.talos.dev/v1.11/talos-guides/install/bare-metal-platforms/secureboot/
    yamlencode({
      machine = {
        install = {
          disk  = var.install_disk
          image = local.installer_image
        }
      }
    }),
    # Hostname, static address and the shared VIP, all on the one NIC. Static
    # only: a node whose address changes drops out of the cluster. Keeping the
    # VIP and the address in a single interface entry avoids relying on two
    # patches merging by an identical deviceSelector.
    # https://www.talos.dev/v1.11/talos-guides/network/vip/
    # https://www.talos.dev/v1.11/talos-guides/network/predictable-interface-names/
    yamlencode({
      machine = {
        network = {
          hostname = each.key
          interfaces = [{
            # Selects any hardware network device; with a single NIC, that one.
            deviceSelector = { busPath = "0*" }
            dhcp           = false
            addresses      = ["${each.value.ip}/${var.prefix_length}"]
            routes         = [{ network = "0.0.0.0/0", gateway = var.gateway }]
            vip            = { ip = var.vip }
          }]
        }
      }
    }),
  ])
}

# Admin kubeconfig generated locally from the Kubernetes CA, with no live
# cluster needed and nothing written to state. talos_machine needs it to drain
# a node before an OS upgrade reboots it.
ephemeral "talos_cluster_kubeconfig" "drain" {
  cluster_name    = var.cluster_name
  endpoint        = local.cluster_endpoint
  machine_secrets = talos_machine_secrets.this.machine_secrets
}

# One per node. Changing var.talos_version (or the extensions) upgrades nodes
# in place: pull, install, drain, reboot, uncordon. for_each can't chain the
# nodes with depends_on, so run apply with -parallelism=1 (the workflow and the
# README do) to upgrade one node at a time and keep etcd quorum.
resource "talos_machine" "node" {
  for_each = var.nodes

  node                  = each.value.ip
  client_configuration  = talos_machine_secrets.this.client_configuration
  machine_configuration = data.talos_machine_configuration.node[each.key].machine_configuration
  image                 = local.installer_image

  drain_on_upgrade = true
  kubeconfig_wo    = ephemeral.talos_cluster_kubeconfig.drain.kubeconfig_raw

  # Leave Kubernetes component image tags to talos_cluster's upgrade-k8s, so
  # bumping kubernetes_version doesn't re-apply every node's config at once.
  ignore_kubernetes_upgrade_drift = true
}

resource "talos_cluster" "this" {
  depends_on = [talos_machine.node]

  node                 = local.bootstrap_node
  control_plane_nodes  = local.node_ips
  client_configuration = talos_machine_secrets.this.client_configuration
  kubernetes_version   = var.kubernetes_version
}

# talosconfig for talosctl. Endpoints are the node IPs rather than the VIP: the
# VIP depends on etcd and Kubernetes, so it is unavailable exactly when talosctl
# is most needed.
# https://www.talos.dev/v1.11/talos-guides/network/vip/#caveats
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = local.node_ips
  nodes                = local.node_ips
}

# The kubeconfig handed to humans. A resource rather than the data source so
# its client certificate is renewed before it expires.
resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_cluster.this]

  node                 = local.bootstrap_node
  client_configuration = talos_machine_secrets.this.client_configuration
}
