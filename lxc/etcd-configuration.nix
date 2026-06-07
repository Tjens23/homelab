{ config, pkgs, modulesPath, lib, ... }: {
  imports = [ 
    (modulesPath + "/virtualisation/proxmox-lxc.nix") 
  ];

  boot.isContainer = true;

  # URL-konfiguration sættes per-node i flake.nix
  services.etcd.enable = true;

  networking.firewall.allowedTCPPorts = [ 2379 2380 ];
}