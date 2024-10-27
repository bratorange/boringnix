# READ THIS FIRST
# This module will install a nextcloud server using nginx as a reverse proxy for ssl termination.
# In order to use nextcloud you will have to set a password for the admin user and one for the database.
# In this example we will be using sops in combination with an age key to store secrets.
# Further information about sops on nixos and age can be found here:
# https://github.com/Mic92/sops-nix
# https://github.com/getsops/sops
# https://github.com/FiloSottile/age
# 1. Install sops and age on your machine
# 2. Create an age key: age-keygen -o ~/.config/sops/age/keys.txt
# 3. Keep this key safe, it is used to encrypt and decrypt your secrets
# 4. Get the public key from your age key:
#    cat .config/sops/age/keys.txt | sed -n 's/.*public key: \(age[^ ]*\).*/\1/p'
# 5. Register your name (or hostname) to the key in your configuration repository.
# Create the following file in your config repository:
#
# .sops.yaml
#===============================================================================
# keys:
#   - &yourname youragepublickey
# creation_rules:
#   - path_regex: secrets/[^/]+\.(yaml|json|env|ini)$
#     key_groups:
#     - pgp:
#       age:
#       - *yourname
#===============================================================================
#
# Make sure to replace yourname with your name (x2) and youragepublickey with the public key from your age key.
# You can also add other users or hosts which shall be able to decrypt the secrets here.
# 6. Create a secrets file in your configuration repository
#    This command will open your $EDITOR in which you have to set two passwords:
#
# sops secrets/nextcloud_admin_pass.yaml
#===============================================================================
# admin_pass: createanadminpasswordhere
# nextcloud_db_pass: createadatabasepasswordhere
#===============================================================================
#
# 7. Save and close the editor
# 8. You will have to include the sops module into your nixos configuration.
#
#    In your flakes.nix add the following lines:
#===============================================================================
# inputs = {
# ...
# nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
# sops-nix = {                                 # <--------- Add this input!
#   url = "github:Mic92/sops-nix";             # <---------
#   inputs.nixpkgs.follows = "nixpkgs";        # <---------
# };                                           # <---------
# ...
# };
#   outputs =
#     {
#       self,
#       nixpkgs,
#       sops-nix,                              # <--------- Add this line!
#       ...
#     }@attrs: {                               # <--------- Make sure this looks like here!
#         nixosConfigurations.somehostname = nixpkgs.lib.nixosSystem {
#                 system = "x86_64-linux";
#                 specialArgs = attrs;         # <--------- Add this line!
#                 modules = [
#                   configuration.nix
#                   sops-nix.nixosModules.sops # <--------- Add this line!
#                   ...
#                 ];
#                 ...
#===============================================================================
#
# 9. Adapt this configuration to your needs

{ config, lib, pkgs, ... }:
let
  domain = "yourdomain.com"; # REQUIRED: Set your domain name
in
{
  services.nextcloud = {
    # REQUIRED: Replace XX with the latest version of nextcloud: https://search.nixos.org/packages
    package = pkgs.nextcloudXX;
    enable = true;
    hostName = fullDomain;
    https = true;

    config = {
      dbtype = "pgsql";
      dbname = "nextcloud";
      dbhost = "localhost";
      dbpassFile = "${config.sops.secrets.nextcloud_db_pass.path}";
      adminuser = "admin";
      adminpassFile = "${config.sops.secrets.nextcloud_admin_pass.path}";
    };
    settings.overwriteprotocol = "https";
    settings.trusted_domains = [ domain ];
    phpOptions = { "opcache.interned_strings_buffer" = "64"; };
  };

  services.postgresql = {
    enable = true;

    ensureUsers = [{
      name = "nextcloud";
      ensureDBOwnership = true;
    }];

    ensureDatabases = [ "nextcloud" ];
  };

  services.nginx.virtualHosts.${config.services.nextcloud.hostName} = {
    forceSSL = true;
    enableACME = true;
  };

  sops.secrets.nextcloud_admin_pass.owner = "nextcloud";
  sops.secrets.nextcloud_db_pass.owner = "nextcloud";
}