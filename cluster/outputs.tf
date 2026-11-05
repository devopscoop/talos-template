output "schematic_id" {
  description = "Image Factory schematic ID (the extension set)."
  value       = talos_image_factory_schematic.this.id
}

output "iso_url" {
  description = "SecureBoot nocloud ISO to upload to Proxmox and boot new VMs from."
  value       = data.talos_image_factory_urls.this.urls.iso_secureboot
}

output "installer_image" {
  description = "Installer image the nodes install and upgrade from."
  value       = local.installer_image
}

output "talosconfig" {
  description = "talosctl client config. Write it out with: tofu output -raw talosconfig > ~/.talos/config"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "kubeconfig" {
  description = "Admin kubeconfig. Write it out with: tofu output -raw kubeconfig > ~/.kube/<cluster_name>"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}
