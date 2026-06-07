{ config, pkgs, modulesPath, lib, ... }: {
  imports = [ 
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ./k3s-common-configuration.nix
  ];

  boot.isContainer = true;

  services.k3s = {
    enable = true;
    role = "server";
  };

  networking.firewall.allowedTCPPorts = [ 6443 10250 ];
  networking.firewall.allowedUDPPorts = [ 8472 ];
}
