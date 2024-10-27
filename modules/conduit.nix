# READ THIS FIRST
# This module will install a matrix server using conduit
# Ngnix is used as a reverse proxy for ssl termination
# two domains are used: matrix.yourdomain and yourdomain.com
# matrix.yourdomain is used to serve the matrix server
# yourdomain.com is just redirect federating servers
{ config, pkgs, ... }:
let
  domain = "yourdomain.com"; # REQUIRED: Set your domain name
  internalListenPort = 8004; # OPTIONAL: adjust this port
in
{
  services.matrix-conduit = {
    enable = true;
    package = pkgs.conduit;
    settings = {
      global = {
        server_name = domain;
        port = internalListenPort;
        address = "127.0.0.1";
      };
    };
  };

  security.acme.defaults.email = "your-email@letsencrypt-will-contact-you.at"; # REQUIRED: Set your email address
  security.acme.acceptTerms = false; # REQUIRED: Read the terms of service and set this to true. https://letsencrypt.org/repository/.

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
