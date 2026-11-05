terraform {
  # Kept identical to .opentofu-version by update_opentofu.sh.
  required_version = "1.13.2"

  required_providers {
    talos = {
      source = "siderolabs/talos"
      # https://github.com/siderolabs/terraform-provider-talos/tree/v0.12.0
      # 0.12.0 adds talos_machine (config + OS upgrades) and talos_cluster
      # (bootstrap + Kubernetes upgrades), which main.tf is built on.
      version = "0.12.0"
    }
  }

  # The state holds the cluster's PKI (talos_machine_secrets: etcd, Kubernetes
  # and Talos CA keys), so it is encrypted client-side below as well as at rest
  # in the bucket. Any S3-compatible store works; set s3_endpoint for non-AWS
  # providers such as Wasabi.
  # https://opentofu.org/docs/language/settings/backends/s3/
  backend "s3" {
    bucket       = var.bucket
    key          = "${var.cluster_name}/terraform.tfstate"
    region       = var.region
    use_lockfile = true
    encrypt      = true
    endpoints = {
      s3 = var.s3_endpoint
    }
  }

  # OpenTofu-native state and plan encryption. The passphrase comes from
  # TF_VAR_state_passphrase (a GitHub Actions secret in CI). Losing it means
  # losing the state, and with it the only copy of the cluster CA keys unless
  # you keep a backup elsewhere.
  # https://opentofu.org/docs/language/state/encryption/
  encryption {
    key_provider "pbkdf2" "state" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "state" {
      keys = key_provider.pbkdf2.state
    }
    state {
      method   = method.aes_gcm.state
      enforced = true
    }
    plan {
      method   = method.aes_gcm.state
      enforced = true
    }
  }
}
