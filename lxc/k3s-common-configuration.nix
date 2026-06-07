{ config, pkgs, modulesPath, lib, ... }: {
  # Shared sysctl settings required by k3s on both masters and workers.
  # Needed for kube-proxy / iptables-based service routing through the bridge.
  boot.kernel.sysctl = {
    "net.bridge.bridge-nf-call-iptables"  = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
    "net.ipv4.ip_forward"                 = 1;
  };
}
