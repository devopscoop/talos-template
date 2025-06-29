#!/usr/bin/env bash

export cluster_name=worchestershire

# https://www.talos.dev/v1.10/introduction/prodnotes/#layer-2-vip-shared-ip
export cluster_endpoint_ip=192.168.8.7
# Find this on your bare metal machines. In ProxMox, this appeared as ens18.
export network_interface=ens18

# control_plane_nodes must be a space-separated, quoted string containing IP addresses of the three control plane nodes.
export control_plane_nodes="192.168.8.147 192.168.8.136 192.168.8.101"
