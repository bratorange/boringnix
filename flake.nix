{
  description = "BoringNix Template Server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, rust-overlay }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ rust-overlay.overlays.default ];
      };
    in
    {
      nixosConfigurations.boringnix = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ({ config, pkgs, ... }: {
            boot.isContainer = true;

            services.nginx = {
              enable = true;
              recommendedProxySettings = true;
              virtualHosts."boringnix.store" = {
                enableACME = true;
                forceSSL = true;
                locations."/" = {
                  proxyPass = "http://127.0.0.1:3000";
                };
              };
            };

            security.acme = {
              acceptTerms = true;
              defaults.email = "acme@jsch.in";
            };

            networking.firewall.allowedTCPPorts = [ 80 443 ];

            environment.systemPackages = with pkgs; [
              (rust-bin.stable.latest.default.override {
                targets = [ "x86_64-unknown-linux-musl" ];
              })
            ];

            systemd.services.boringnix-server = {
              description = "BoringNix Template Server";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                ExecStart = "${pkgs.rust-bin.stable.latest.default}/bin/cargo run --release";
                WorkingDirectory = "/var/lib/boringnix";
                User = "boringnix";
                Restart = "on-failure";
              };
            };

            users.users.boringnix = {
              isSystemUser = true;
              group = "boringnix";
            };
            users.groups.boringnix = {};
          })
        ];
      };
    };
}
