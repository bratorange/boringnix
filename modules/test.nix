{ config, pkgs, ... }:
{
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud27;
    hostName = "nextcloud.example.com";
    # Add more configuration options here
  };
}
