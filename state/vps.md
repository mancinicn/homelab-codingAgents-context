## VPS containers
NAMES                  IMAGE                                 STATUS
authentik-server       ghcr.io/goauthentik/server:2026.5.5   Up 2 minutes (healthy)
authentik-worker       ghcr.io/goauthentik/server:2026.5.5   Up 2 minutes (healthy)
traefik                traefik:v3.2.0                        Up 30 hours
vaultwarden            vaultwarden/server:1.36.0             Up 4 days (healthy)
backup-gateway         rclone/rclone:1.74.4                  Up 4 days
backup-gateway-vps     rclone/rclone:1.74.4                  Up 4 days
authentik-postgresql   postgres:16-alpine                    Up 5 days (healthy)
authentik-redis        redis:7-alpine                        Up 10 days (healthy)

## VPS disk
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        96G   50G   47G  52% /

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
