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
      rec {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "boringnix";
          src = ./.;
          version = packages.binary.version;
          phases = [ "installPhase" ];
          installPhase = ''
            mkdir -p $out/bin
            ln -s ${packages.binary}/bin/boringnix $out/bin
            cp -r $src/modules $out
            cp -r $src/static $out
          '';
        };
        packages.binary = pkgs.rustPlatform.buildRustPackage {
          pname = "boringnix-binary";
          version = "0.1.0";
          src = ./.;
          cargoHash = "sha256-jWDym9/u/2gS57TkkLlo3JErUQIQgWOmtJF3JMEfUcQ=";
        };
      }
    )
    //
     {
      nixosModules.server =
        { config, pkgs, ... }:
        let
            defaultPackage = self.packages."${pkgs.system}".default;
        in
        {
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

          networking.firewall.allowedTCPPorts = [
            80
            443
          ];

          systemd.services.boringnix-server = {
            description = "BoringNix Module Server";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              ExecStart = "${defaultPackage}/bin/boringnix";
              WorkingDirectory = defaultPackage;
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
