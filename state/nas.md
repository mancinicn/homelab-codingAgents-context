## NAS containers
NAMES                      IMAGE                                            STATUS
homeassistant              ghcr.io/home-assistant/home-assistant:2026.7.1   Up 13 hours
n8n-postgres               postgres:16-alpine                               Up 13 hours (healthy)
n8n                        docker.n8n.io/n8nio/n8n:2.29.8                   Up 13 hours
n8n-outpost                ghcr.io/goauthentik/proxy:2024.8.3               Up 17 hours (healthy)
n8n-outpost-redis          redis:7-alpine                                   Up 18 hours
ops-gateway                ops-gateway:1.4                                  Up 19 hours (healthy)
ops-gateway-docker-proxy   tecnativa/docker-socket-proxy:v0.4.2             Up 19 hours

## NAS disk
Filesystem                                      Size  Used Avail Use% Mounted on
/dev/mapper/ug_B584AF_1766063350_pool1-volume1  3.7T  178G  3.5T   5% /volume1

## NAS docker networks
NETWORK ID     NAME                               DRIVER    SCOPE
685f9866d474   bridge                             bridge    local
79ff98b8f3c3   core-net                           bridge    local
2af029010387   host                               host      local
70f4c7a62ad4   lab-net                            bridge    local
7db026b2dd5c   none                               null      local
d52a3ade906c   ops-gateway_ops-gateway-external   bridge    local
afbc1ea27eed   ops-gateway_ops-gateway-internal   bridge    local

## Backup timer
● restic-photos-backup.timer - Daily Restic photo backup
     Loaded: loaded (/etc/systemd/system/restic-photos-backup.timer; enabled; preset: enabled)
     Active: active (waiting) since Sun 2026-07-12 14:11:12 CEST; 19h ago
    Trigger: Tue 2026-07-14 03:34:21 CEST; 18h left
   Triggers: ● restic-photos-backup.service
