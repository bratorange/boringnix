{
  description = "BoringNix Template Server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.rustPlatform.buildRustPackage {
          pname = "boringnix";
          version = "0.1.0";
          src = ./.;
          cargoHash = "sha256-EXTG3eZMH4HpiGRNWCDhzY7kIjzitkcVF3OdkBf/dFY=";
        };
      }
    )
    // {
      nixosModules.server =
        { config, pkgs, ... }:
        {
          boot.isContainer = true;

          services.nginx = {
            enable = true;
            recommendedProxySettings = true;
            virtualHosts."boringnix.store" = {
              enableACME = true;
              forceSSL = true;
              locations."/" = {
                proxyPass = "http://127.0.0.1:8005";
              };
            };
          };

          security.acme = {
            acceptTerms = true;
            defaults.email = "acme@jsch.in";
          };

          networking.firewall.allowedTCPPorts = [
            80
            443
          ];

          systemd.services.boringnix-server = {
            description = "BoringNix Template Server";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              ExecStart = "${self.packages.default}/bin/boringnix";
              WorkingDirectory = self.packages.default;
              User = "boringnix";
              Restart = "on-failure";
            };
          };

          users.users.boringnix = {
            isSystemUser = true;
            group = "boringnix";
          };
          users.groups.boringnix = { };
        };
    };
}
