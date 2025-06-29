#!/usr/bin/env bash

# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -euxo pipefail

# https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/variables.sh"

export first_node=$(echo $control_plane_nodes | cut -d' ' -f 1)

if [[ ! -f controlplane.yaml ]]; then

  # Need to be in SCRIPT_DIR so these files are generated in the correct place.
  cd "${SCRIPT_DIR}"

  # https://www.talos.dev/v1.10/introduction/getting-started/#configure-talos-linux
  talosctl gen config "${cluster_name}" "https://${first_node}:6443"
fi

# Allow scheduling workloads on the control plane nodes, because we're too lazy to spin up 3 dedicated control plane nodes.
# https://www.talos.dev/v1.9/talos-guides/howto/workers-on-controlplane/
sed -i.bak 's/# allowSchedulingOnControlPlanes: true/allowSchedulingOnControlPlanes: true/' controlplane.yaml
rm controlplane.yaml.bak

# Add cluster_endpoint_ip as a VIP
# https://www.talos.dev/v1.10/introduction/prodnotes/#layer-2-vip-shared-ip
# https://www.talos.dev/v1.10/talos-guides/network/vip/
yq -i ".machine.network.interfaces = [{\"deviceSelector\": {\"physical\": true}, \"dhcp\": true, \"vip\": {\"ip\": \"${cluster_endpoint_ip}\"}}]" "${SCRIPT_DIR}/controlplane.yaml"

# TODO: This should only be run once. Touch a file maybe? I dunno.
# https://www.talos.dev/v1.10/introduction/getting-started/#apply-configuration
# for node in $control_plane_nodes; do
#   talosctl apply-config --insecure \
#     --nodes "${node}" \
#     --file "${SCRIPT_DIR}/controlplane.yaml"
# done

# TODO: Have to wait a minute or two after application before we can bootstrap... I don't want to put a sleep in here though...

# https://www.talos.dev/v1.10/introduction/getting-started/#kubernetes-bootstrap
# talosctl bootstrap --nodes "${first_node}" --endpoints "${first_node}" \
#   --talosconfig="${SCRIPT_DIR}/talosconfig"

talosctl kubeconfig "${HOME}/.kube/${cluster_name}" --nodes "${first_node}" --endpoints "${first_node}" \
  --talosconfig="${SCRIPT_DIR}/talosconfig"
