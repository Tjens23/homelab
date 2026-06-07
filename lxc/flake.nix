{
  description = "NixOS homelab cluster - Fuldstændig dynamisk via .local DNS og korrekte porte";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: 
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;

      etcdCount   = 3; 
      masterCount = 3; 
      workerCount = 5; 

      k3sVip    = "192.168.2.120";
      k3sToken  = "DIT_K3S_TOKEN";
      etcdToken = "etcd-k8s-token";

      # Statiske IP-adresser for etcd-noder (mDNS virker ikke i minimalistiske containere)
      etcdIPs = [ "192.168.2.163" "192.168.2.176" "192.168.2.186" ];

      etcdCluster = builtins.genList (i:
        let
          name = "porcian-${padInt (i + 1)}";
          ip   = builtins.elemAt etcdIPs i;
        in "${name}=http://${ip}:2380"
      ) etcdCount;

      etcdEndpoints = builtins.genList (i:
        "http://${builtins.elemAt etcdIPs i}:2379"
      ) etcdCount;

      padInt = i: lib.fixedWidthString 2 "0" (builtins.toString i);

      # =======================================================================
      # DYNAMISKE GENERATOR-FUNKTIONER
      # =======================================================================
      makeEtcdNodes = builtins.listToAttrs (builtins.genList (i:
        let
          name = "porcian-${padInt (i + 1)}";
          ip   = builtins.elemAt etcdIPs i;
        in {
          inherit name;
          value = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [ 
              ./configuration.nix 
              ./etcd-configuration.nix 
              ({ ... }: {
                networking.hostName = name;

                services.etcd = {
                  enable = true;
                  # Navn SKAL sættes — ellers bruger alle noder "default" og cluster fejler
                  name = name;
                  # Brug kun den specifikke IP — 0.0.0.0 tilføjes automatisk og giver konflikt
                  listenClientUrls         = lib.mkForce [ "http://${ip}:2379" "http://127.0.0.1:2379" ];
                  advertiseClientUrls      = lib.mkForce [ "http://${ip}:2379" ];
                  listenPeerUrls           = lib.mkForce [ "http://${ip}:2380" ];
                  initialAdvertisePeerUrls = lib.mkForce [ "http://${ip}:2380" ];
                  initialCluster           = lib.mkForce etcdCluster;
                  # "new" for alle noder på første bootstrap.
                  # Sæt til "existing" for noder der rejoiner efter at cluster allerede er dannet.
                  initialClusterState      = lib.mkForce (if i == 1 then "existing" else "new");
                  initialClusterToken      = etcdToken;
                };

                networking.firewall.allowedTCPPorts = [ 2379 2380 ];
              }) 
            ];
          };
        }
      ) etcdCount);

      makeMasterNodes = builtins.listToAttrs (builtins.genList (i: rec {
        name = "hele-${padInt (i + 1)}";
        value = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ 
            ./configuration.nix 
            ./k3s-master-configuration.nix 
            ({ ... }: {
              networking.hostName = name;
              services.k3s = {
                token = k3sToken;
                extraFlags = toString (
                  (if i == 0 then [ "--cluster-init" ] else []) ++ [
                    "--datastore-endpoint=${lib.concatStringsSep "," etcdEndpoints}"
                    "--tls-san ${k3sVip}"
                    "--flannel-backend=wireguard-native"
                    "--disable-cloud-controller"
                    "--disable=local-storage"
                    "--disable=servicelb"
                  ]
                );
              };
            }) 
          ];
        };
      }) masterCount);

      makeWorkerNodes = builtins.listToAttrs (builtins.genList (i: rec {
        name = "heroku-${padInt (i + 1)}";
        value = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ 
            ./configuration.nix 
            ({ ... }: {
              networking.hostName = name;
              services.k3s = {
                enable     = true;
                role       = "agent";
                serverAddr = "https://${k3sVip}:6443";
                token      = k3sToken;
              };
            }) 
          ];
        };
      }) workerCount);

    in {
      nixosConfigurations = makeEtcdNodes // makeMasterNodes // makeWorkerNodes;

      packages.${system}.default =
        (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ ./configuration.nix ];
        }).config.system.build.images.proxmox-lxc;
    };
}
