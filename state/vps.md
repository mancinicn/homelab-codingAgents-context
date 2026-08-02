## VPS containers
NAMES                  IMAGE                                 STATUS
vaultwarden            vaultwarden/server:1.37.1             Up About an hour (healthy)
traefik                traefik:v3.2.0                        Up About an hour
authentik-server       ghcr.io/goauthentik/server:2026.5.6   Up 7 days (healthy)
authentik-worker       ghcr.io/goauthentik/server:2026.5.6   Up 7 days (healthy)
backup-gateway         rclone/rclone:1.74.4                  Up 2 weeks
backup-gateway-vps     rclone/rclone:1.74.4                  Up 2 weeks
authentik-postgresql   postgres:16-alpine                    Up 2 weeks (healthy)
authentik-redis        redis:7-alpine                        Up 3 weeks (healthy)

## VPS disk
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        96G   46G   51G  48% /

## VPS public listeners (expected: 22, 80, 443, 41641/udp)
udp   UNCONN 0      0                       127.0.0.54:53         0.0.0.0:*          
udp   UNCONN 0      0                    127.0.0.53%lo:53         0.0.0.0:*          
udp   UNCONN 0      0                          0.0.0.0:41641      0.0.0.0:*          
tcp   LISTEN 0      4096                 100.94.111.98:8200       0.0.0.0:*          
tcp   LISTEN 0      4096                       0.0.0.0:80         0.0.0.0:*          
tcp   LISTEN 0      4096                       0.0.0.0:22         0.0.0.0:*          
tcp   LISTEN 0      4096                       0.0.0.0:443        0.0.0.0:*          
tcp   LISTEN 0      4096                 100.94.111.98:4000       0.0.0.0:*          
tcp   LISTEN 0      4096                 100.94.111.98:8080       0.0.0.0:*          
tcp   LISTEN 0      4096                 100.94.111.98:11434      0.0.0.0:*          
tcp   LISTEN 0      4096                     127.0.0.1:8201       0.0.0.0:*          
tcp   LISTEN 0      4096                 100.94.111.98:44468      0.0.0.0:*          
tcp   LISTEN 0      4096                 127.0.0.53%lo:53         0.0.0.0:*          
tcp   LISTEN 0      4096                    127.0.0.54:53         0.0.0.0:*          

## VPS docker networks
authentik-ops_default
backup-gateway_default
bridge
host
identity_authentik-internal
identity_default
none
proxy
tools_default
