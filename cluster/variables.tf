# Backend

variable "bucket" {
  description = "S3 (or S3-compatible) bucket holding the OpenTofu state."
  type        = string
}

variable "region" {
  description = "Region of the state bucket."
  type        = string
}

variable "s3_endpoint" {
  description = "Custom S3 endpoint for non-AWS stores, e.g. https://s3.us-west-1.wasabisys.com. Leave null for AWS."
  type        = string
  default     = null
}

variable "state_passphrase" {
  description = "Passphrase for OpenTofu state/plan encryption (min. 16 characters). Set via TF_VAR_state_passphrase; never put it in terraform.tfvars."
  type        = string
  sensitive   = true
}

# Cluster

variable "cluster_name" {
  description = "Talos/Kubernetes cluster name. Also the state key prefix."
  type        = string
}

variable "nodes" {
  description = <<-EOT
    Control-plane nodes, keyed by hostname. Every node is a control plane that
    also runs workloads. Each VM must already be booted from the ISO in the
    iso_url output and reachable at `ip` (see README: the maintenance-mode
    address must be the same as the static one).
  EOT
  type = map(object({
    ip = string
  }))
}

variable "vip" {
  description = "Shared virtual IP for the Kubernetes API, held by one control plane at a time."
  type        = string
}

variable "gateway" {
  description = "Default gateway for the node network."
  type        = string
}

variable "prefix_length" {
  description = "Prefix length of the node network, e.g. 24 for a /24."
  type        = number
  default     = 24
}

variable "install_disk" {
  description = "Disk Talos installs to."
  type        = string
  default     = "/dev/sda"
}

# Versions

variable "talos_version" {
  description = "Talos version to install and keep nodes on. Changing it upgrades nodes in place (README: Upgrading Talos)."
  type        = string
}

variable "talos_config_contract" {
  description = <<-EOT
    Talos machine-config contract (e.g. v1.11). Pin it to the version the
    cluster was created with and do NOT bump it on routine upgrades: changing it
    regenerates every machine config with the newer version's defaults.
    https://docs.siderolabs.com/talos/latest/configure-your-talos-cluster/system-configuration/reproducible-machine-configuration
  EOT
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version. Changing it runs Talos's upgrade-k8s procedure via talos_cluster."
  type        = string
}

variable "extensions" {
  description = "Official Talos system extensions baked into the Image Factory schematic."
  type        = list(string)
}
