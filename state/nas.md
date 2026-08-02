## NAS containers
NAMES                      IMAGE                                                            STATUS
immich-server              ghcr.io/immich-app/immich-server:v3.1.0                          Up 3 hours (healthy)
immich-machine-learning    ghcr.io/immich-app/immich-machine-learning:v3.1.0                Up 3 hours (healthy)
n8n                        docker.n8n.io/n8nio/n8n:2.32.7                                   Up 3 hours
bentopdf                   ghcr.io/alam00000/bentopdf-simple:v2.8.6                         Up 6 days
homeassistant              ghcr.io/home-assistant/home-assistant:2026.7.4                   Up 7 days
hermes                     hermes:1.1                                                       Up 2 weeks (healthy)
ops-gateway                ops-gateway:1.5                                                  Up 2 weeks (healthy)
ops-gateway-docker-proxy   tecnativa/docker-socket-proxy:v0.4.2                             Up 2 weeks
immich-database            ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0   Up 2 weeks (healthy)
immich-redis               valkey/valkey:9                                                  Up 2 weeks (healthy)
n8n-outpost-redis          redis:7-alpine                                                   Up 2 weeks
n8n-postgres               postgres:16-alpine                                               Up 2 weeks (healthy)
n8n-outpost                ghcr.io/goauthentik/proxy:2024.8.3                               Up 2 weeks (healthy)

## NAS disk
Filesystem                                      Size  Used Avail Use% Mounted on
/dev/mapper/ug_B584AF_1766063350_pool1-volume1  3.7T  198G  3.5T   6% /volume1

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
     Active: active (waiting) since Sun 2026-07-12 14:11:12 CEST; 2 weeks 6 days ago
    Trigger: Mon 2026-08-03 03:31:36 CEST; 19h left
   Triggers: ● restic-photos-backup.service
