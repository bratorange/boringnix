{ config, pkgs, ... }:
let
  domain = "yourdomain.com"; # REQUIRED: Set your domain name
  internalListenPort = 8004; # OPTIONAL: adjust this port
in
{
  services.matrix-conduit = {
    enable = true;
    package = pkgs.conduwuit;
    settings = {
      global = {
        server_name = domain;
        port = internalListenPort;
        address = "127.0.0.1";
      };
    };
  };

  # Nginx reverse proxy configuration
  services.nginx.virtualHosts = {
    "matrix.${domain}" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://${config.services.matrix-conduit.settings.global.address}:${toString internalListenPort}";
      };
    };
    "${domain}" = {
      enableACME = true;
      forceSSL = true;
      locations."/.well-known/matrix/server" = {
        extraConfig = ''
          add_header Content-Type application/json;
          return 200 '{"m.server": "matrix.${domain}:443"}';
        '';
      };
    };
  };
}
