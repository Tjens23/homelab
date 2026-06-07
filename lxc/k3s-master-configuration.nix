{ config, pkgs, modulesPath, lib, ... }: {
  imports = [ 
    (modulesPath + "/virtualisation/proxmox-lxc.nix") 
  ];

  boot.isContainer = true;

  # Nødvendige netværksindstillinger for K8s i LXC
  boot.kernel.sysctl = {
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
    "net.ipv4.ip_forward" = 1;
  };

  services.k3s = {
    enable = true;
    role = "server";
  };

  networking.firewall.allowedTCPPorts = [ 6443 10250 ];
  networking.firewall.allowedUDPPorts = [ 8472 ];
}
