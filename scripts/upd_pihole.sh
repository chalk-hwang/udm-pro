#!/bin/sh

set -e

DOCKER_TAG=2023.02.0

chmod +r /data/etc-pihole/* /data/pihole/* /data/pihole/etc-dnsmasq.d/*
chmod 0664 /data/etc-pihole/gravity.db
rm -f /data/etc-pihole/macvendor.db
touch /data/etc-pihole/macvendor.db
chown root:root /data/etc-pihole/macvendor.db
chown -R root:root /data/etc-pihole/
mkdir -p /data/etc-pihole/migration_backup/
chmod 0755 /data/etc-pihole/migration_backup/
touch /data/etc-pihole/pihole-FTL.conf
chmod 0664 /data/etc-pihole/pihole-FTL.conf
chown root:root /data/etc-pihole/pihole-FTL.conf

set +e

# Change to boostchicken/pihole:latest for DoH
# Change to boostchicken/pihole-dote:latest for DoTE
IMAGE=pihole/pihole:$DOCKER_TAG

podman pull $IMAGE
echo 'Stopping Pi-hole'
podman stop pihole
echo 'Removing Pi-hole'
podman rm pihole
echo 'Starting new Pi-hole version'
podman run -d --network dns --restart always \
    --name pihole \
    -e TZ="$(cat /data/system/timezone)" \
    -v "/data/etc-pihole:/etc/pihole" \
    -v "/data/pihole/etc-dnsmasq.d:/etc/dnsmasq.d" \
    -v "/data/pihole/hosts:/etc/hosts:ro" \
    --dns=127.0.0.1 \
    --dns=1.1.1.1 \
    --dns=1.0.0.1 \
    --hostname pihole \
    -e PIHOLE_UID=0 \
    -e PIHOLE_GID=0 \
    -e VIRTUAL_HOST="pihole" \
    -e PROXY_LOCATION="pihole" \
    -e FTLCONF_LOCAL_IPV4="192.168.6.254" \
    -e PIHOLE_DNS_="1.1.1.1;1.0.0.1" \
    -e IPv6="False" \
    -e SKIPGRAVITYONBOOT=1 \
    -e DBIMPORT=yes \
    $IMAGE

echo 'Waiting for new Pi-hole version to start'
sleep 5 # Allow Pi-hole to start up

if curl --connect-timeout 0.5 -fsL 192.168.6.254/admin -o /dev/null; then
  podman system prune
else
  code=$?
  echo 'Pi-hole deployment unsuccessful!'
  exit ${code}
fi
