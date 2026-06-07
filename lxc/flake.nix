{
  description = "NixOS LXC image for Proxmox";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    nixosConfigurations.lxc = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ];
    };

    packages.x86_64-linux.default =
      self.nixosConfigurations.lxc.config.system.build.images.proxmox-lxc;
  };
}
