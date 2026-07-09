## NAS containers
NAMES           IMAGE                                            STATUS
homeassistant   ghcr.io/home-assistant/home-assistant:2026.7.1   Up 22 hours
n8n             docker.n8n.io/n8nio/n8n:2.29.8                   Up 22 hours
n8n-postgres    postgres:16-alpine                               Up 22 hours (healthy)

## NAS disk
Filesystem                                      Size  Used Avail Use% Mounted on
/dev/mapper/ug_B584AF_1766063350_pool1-volume1  3.7T  178G  3.5T   5% /volume1

## NAS docker networks
NETWORK ID     NAME       DRIVER    SCOPE
a79ec5f1c6cc   bridge     bridge    local
79ff98b8f3c3   core-net   bridge    local
2af029010387   host       host      local
70f4c7a62ad4   lab-net    bridge    local
7db026b2dd5c   none       null      local

## Backup timer
● restic-photos-backup.timer - Daily Restic photo backup
     Loaded: loaded (/etc/systemd/system/restic-photos-backup.timer; enabled; preset: enabled)
     Active: active (waiting) since Mon 2026-07-06 10:32:09 CEST; 3 days ago
    Trigger: Fri 2026-07-10 03:29:54 CEST; 6h left
   Triggers: ● restic-photos-backup.service
