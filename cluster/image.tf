# The Talos image: an Image Factory schematic (the set of system extensions),
# rendered into the ISO you boot the VMs from and the installer image the nodes
# install and upgrade from. Both come from the same schematic and version, so a
# freshly booted node never needs an upgrade before its first config apply.
# https://github.com/siderolabs/image-factory?tab=readme-ov-file#post-schematics

data "talos_image_factory_extensions_versions" "this" {
  talos_version = var.talos_version
  filters = {
    names = var.extensions
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = data.talos_image_factory_extensions_versions.this.extensions_info[*].name
      }
    }
  })
}

# nocloud + SecureBoot, which the README's Proxmox VM settings (OVMF, TPM, no
# pre-enrolled keys) and patches/tpm-disk-encryption.yaml rely on.
# https://www.talos.dev/v1.11/talos-guides/install/virtualized-platforms/proxmox/
data "talos_image_factory_urls" "this" {
  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.this.id
  platform      = "nocloud"
}

locals {
  installer_image = data.talos_image_factory_urls.this.urls.installer_secureboot
}
