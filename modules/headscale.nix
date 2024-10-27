# READ THIS
# In order to use headscale you will have to register each machine you want to connect to the VPN with the headscale server.
# 1. Create a user for each client you want to connect to the VPN: headscalectl user create <clientname>
# 2. Install the tailscale client on your client: https://tailscale.com/download/linux
# 3. connect to headscale server from your client: sudo tailscale login --login-server=https://tailscale.yourdomain.com
# 4. follow the link to authenticate your client on the headscale server
{ pkgs, ... }:
let
  domain = "yourdomain.com"; # REQUIRED: Set your domain name
  fullDomain = "tailscale.${domain}";
  internalListenPort = 8003; # OPTIONAL: adjust this port
  proxyPass = "http://127.0.0.1:${toString internalListenPort}";
in
{
  headscale = {
    enable = true;
    port = 8003;
    settings = {
      server_url = "https://${fullDomain}";
      # REQUIRED: This is the Acces control list between the clients in your vpn
      # this example assumes three clients: yourmachine, someothermachine and someserver
      # these are name of the machines you registered with headscale before
      policy.path = pkgs.writeText "headscale-acls.hujson" ''
        {
          "groups": {
            "group:admin": ["yourmachine"],
            "group:users": ["someothermachine"]
          },
          "acls": [
            {
              "action": "accept",
              "src": ["group:admin"],
              "dst": ["*:*"]
            }
            {
              "action": "accept",
              "src": ["group:users"],
              "dst": ["someserver:22"]
            }
          ]
        }
      '';

      # OPTIONAL: We are using a sqlite database here, you can also use postgres or mysql
      database = {
        type = "sqlite";
        sqlite.path = "/var/lib/headscale/db.sqlite";
      };

      derp.server = {
        enbabled = true;
      };

      dns = {
        # REQUIRED: Set an internal domain name or remove the this section
        magic_dns = true;
        # This is the domain name that will be used for the internal DNS
        base_domain = "somedomain.vpn";
        override_local_dns = false;
        restricted_nameservers = [ ];
        nameservers.global = [ "1.1.1.1" ];
      };

      prefixes = {
        # OPTIONAL: Set the ip prefixes for the VPN
        v4 = "100.64.0.0/10";
        v6 = "fd7a:115c:a1e0::/48";
      };
    };
  };
  services = {
    nginx = {
      enable = true;
      virtualHosts."${fullDomain}" = {
        forceSSL = true;
        kTLS = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString internalListenPort}";
          proxyWebsockets = true;
          extraConfig = ''
            keepalive_timeout 0;
            proxy_buffering off;
          '';
        };
      };
    };
  };
}
