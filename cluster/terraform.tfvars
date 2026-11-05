# Template values: these are one homelab's settings. Change them for a new
# cluster. state_passphrase is deliberately absent; see variables.tf.

# Backend
bucket = "worclustershire-tofu-state"
region = "us-west-1"
# For a non-AWS S3-compatible store, set its endpoint, e.g. Wasabi:
# s3_endpoint = "https://s3.us-west-1.wasabisys.com"

# Cluster
cluster_name = "worclustershire"

nodes = {
  worclustershire1 = { ip = "192.168.8.4" }
  worclustershire2 = { ip = "192.168.8.5" }
  worclustershire3 = { ip = "192.168.8.6" }
}

vip           = "192.168.8.7"
gateway       = "192.168.8.1"
prefix_length = 24
install_disk  = "/dev/sda"

# Versions
talos_version         = "v1.11.5"
talos_config_contract = "v1.11"
# The default for Talos v1.11.5. For an existing cluster, set this to what is
# actually running (`kubectl version`), or the first apply will upgrade it.
kubernetes_version = "1.34.1"

extensions = [
  # https://longhorn.io/docs/1.9.0/advanced-resources/os-distro-specific/talos-linux-support/
  "siderolabs/iscsi-tools",
  "siderolabs/util-linux-tools",
  # https://www.talos.dev/v1.11/talos-guides/install/virtualized-platforms/proxmox/#qemu-guest-agent-support-iso
  "siderolabs/qemu-guest-agent",
]
