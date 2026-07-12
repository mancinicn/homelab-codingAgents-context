## VPS containers
NAMES                  IMAGE                                 STATUS
backup-gateway         rclone/rclone:1.74.4                  Up 15 hours
authentik-worker       ghcr.io/goauthentik/server:2024.8.3   Up 5 days (healthy)
authentik-server       ghcr.io/goauthentik/server:2024.8.3   Up 5 days (healthy)
authentik-postgresql   postgres:16-alpine                    Up 5 days (healthy)
authentik-redis        redis:7-alpine                        Up 5 days (healthy)
vaultwarden            vaultwarden/server:1.32.7             Up 6 days (healthy)
n8n-zuij-n8n-1         docker.n8n.io/n8nio/n8n               Up 6 days
traefik                traefik:v3.2.0                        Up 2 days

## VPS disk
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        96G   47G   50G  49% /

## VPS public listeners (expected: 22, 80, 443, 41641/udp)
udp   UNCONN 0      0                       127.0.0.54:53         0.0.0.0:*          
udp   UNCONN 0      0                    127.0.0.53%lo:53         0.0.0.0:*          
udp   UNCONN 0      0                          0.0.0.0:41641      0.0.0.0:*          
tcp   LISTEN 0      4096                 100.94.111.98:8200       0.0.0.0:*          
tcp   LISTEN 0      4096                 100.94.111.98:32781      0.0.0.0:*          
tcp   LISTEN 0      4096                       0.0.0.0:80         0.0.0.0:*          
tcp   LISTEN 0      4096                       0.0.0.0:22         0.0.0.0:*          
tcp   LISTEN 0      4096                       0.0.0.0:443        0.0.0.0:*          
tcp   LISTEN 0      4096                 100.94.111.98:4000       0.0.0.0:*          
tcp   LISTEN 0      4096                 100.94.111.98:8080       0.0.0.0:*          
tcp   LISTEN 0      4096                 100.94.111.98:11434      0.0.0.0:*          
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
n8n-zuij_default
none
proxy
tools_default
universal-capture_brain_net
