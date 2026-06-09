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
      masterIP  = "192.168.2.132"; 
      k3sToken  = "DIT_K3S_TOKEN";
      etcdToken = "etcd-k8s-token";

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
                  name = name;
                  listenClientUrls         = lib.mkForce [ "http://${ip}:2379" "http://127.0.0.1:2379" ];
                  advertiseClientUrls      = lib.mkForce [ "http://${ip}:2379" ];
                  listenPeerUrls           = lib.mkForce [ "http://${ip}:2380" ];
                  initialAdvertisePeerUrls = lib.mkForce [ "http://${ip}:2380" ];
                  initialCluster           = lib.mkForce etcdCluster;
                  initialClusterState      = lib.mkForce (if i == 0 then "new" else "existing");
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
                  # --cluster-init er KUN til embedded etcd — bruges IKKE med ekstern datastore
                  # Sekundære servere skal bruge --server for at hente cluster CA fra hele-01
                  (if i != 0 then [ "--server https://${masterIP}:6443" ] else []) ++ [
                    "--datastore-endpoint=${lib.concatStringsSep "," etcdEndpoints}"
                    "--tls-san ${k3sVip}"
                    "--flannel-backend=wireguard-native"
                    "--disable-cloud-controller"
                    "--disable=local-storage"
                    "--disable=servicelb"
                    "--kubelet-arg=feature-gates=KubeletInUserNamespace=true"
                    "--write-kubeconfig-mode=0644"
                  ]
                );
              };

              services.keepalived = {
                enable = true;
                vrrpInstances.K3S_VIP = {
                  interface = "eth0";
                  state = if i == 0 then "MASTER" else "BACKUP";
                  virtualRouterId = 51;
                  priority = 100 - (i * 10); # hele-01=100, hele-02=90, hele-03=80
                  virtualIps = [{ addr = "${k3sVip}/24"; }];
                  extraConfig = ''
                    authentication {
                      auth_type PASS
                      auth_pass dd11oypT
                    }
                  '';
                };
              };

              networking.firewall.extraInputRules = "meta l4proto 112 accept";
              networking.firewall.extraForwardRules = "meta l4proto 112 accept";
              networking.firewall.allowedUDPPorts = [ 8472 51820 51821 ];
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
            ./k3s-common-configuration.nix
            ({ ... }: {
              networking.hostName = name;
              services.k3s = {
                enable      = true;
                role        = "agent";
                extraFlags  = "--kubelet-arg=feature-gates=KubeletInUserNamespace=true";
                serverAddr = "https://${k3sVip}:6443";
                token      = k3sToken;
              };
              networking.firewall.allowedUDPPorts = [ 51820 ];
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
