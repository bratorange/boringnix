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
          cargoHash = "sha256-vclHM9JYLaUvz+yG2KkR8rGqr9NMJuypIV9AlD7Cy+A=";
        };
      }
    );
}
