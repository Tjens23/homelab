{ modulesPath, pkgs, lib, ... }:
{
  imports = [ "${modulesPath}/virtualisation/proxmox-lxc.nix" ];

  proxmoxLXC.manageNetwork = false;

  # Bake a DHCP networkd config for eth0 into the image.
  # Proxmox injects this for unprivileged containers but not privileged ones,
  # so we provide it ourselves to cover both cases.
  systemd.network.networks."10-eth0" = {
    matchConfig.Name = "eth0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    dhcpV4Config.UseDNS = true;
  };

  users.users.tej = {
    isNormalUser = true;
    extraGroups  = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGQHAYShU3d+SgaCfiLM2m1erBAQOXTDuC4asZVVcLgt pve"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHX7n/xNCE3pZOFR8ddzR3pNVixwvG6yMzsSrTtt2GhmAAAAC3NzaDpob21lbGFi btsp_@homelab"
    ];
  };

  nix.settings.trusted-users = [ "tej" ];

  services.openssh.enable = true;
  security.sudo.extraRules = [
    {
      users = [ "tej" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
    }
  ];

  environment.systemPackages = with pkgs; [ curl git jq vim htop ];

  system.stateVersion = "26.05";
}
