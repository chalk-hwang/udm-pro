#!/bin/bash
# Get DataDir location
DATA_DIR="/data"
case "$(ubnt-device-info firmware || true)" in
1*)
    DATA_DIR="/mnt/data"
    ;;
2*)
    DATA_DIR="/data"
    ;;
3*)
    DATA_DIR="/data"
    ;;
*)
    echo "ERROR: No persistent storage found." 1>&2
    exit 1
    ;;
esac

# Check if the directory exists
if [ ! -d "${DATA_DIR}/pihole" ]; then
    # If it does not exist, create the directory
    mkdir -p "${DATA_DIR}/pihole"
    mkdir -p "${DATA_DIR}/pihole/etc"
    echo "Directory '${DATA_DIR}/pihole' created."
else
    # If it already exists, print a message
    echo "Directory '${DATA_DIR}/pihole' already exists. Moving on."
fi
set -e

DOCKER_IMAGE=cbcrowe/pihole-unbound
DOCKER_TAG=latest

echo 'Pulling new Pi-hole base image'
podman pull ${DOCKER_IMAGE}:${DOCKER_TAG}

chmod +r ${DATA_DIR}/etc-pihole/* ${DATA_DIR}/pihole/* ${DATA_DIR}/pihole/etc-dnsmasq.d/*
chmod 0664 ${DATA_DIR}/etc-pihole/gravity.db
rm -f ${DATA_DIR}/etc-pihole/macvendor.db
touch ${DATA_DIR}/etc-pihole/macvendor.db
chown -R root:1000 ${DATA_DIR}/etc-pihole/
mkdir -p ${DATA_DIR}/etc-pihole/migration_backup/
chmod 0755 ${DATA_DIR}/etc-pihole/migration_backup/
touch ${DATA_DIR}/etc-pihole/pihole-FTL.conf
chmod 0664 ${DATA_DIR}/etc-pihole/pihole-FTL.conf
chown root:1000 ${DATA_DIR}/etc-pihole/pihole-FTL.conf

set +e

echo 'Stopping Pi-hole'
podman stop pihole
echo 'Removing Pi-hole'
podman rm pihole
echo 'Starting new Pi-hole version'
podman run -d --network dns --restart always \
    --name pihole \
    -e TZ="$(cat /data/system/timezone)" \
    -v "/data/etc-pihole:/etc/pihole" \
    -v "/data/pihole/etc-dnsmasq.d/01-pihole.conf:/etc/dnsmasq.d/01-pihole.conf" \
    -v "/data/pihole/etc-dnsmasq.d/03-user.conf:/etc/dnsmasq.d/03-user.conf" \
    -v "/data/pihole/hosts:/etc/hosts:ro" \
    -v "/data/pihole/etc-unbound/unbound.conf.d:/etc/unbound/unbound.conf.d" \
    --dns=127.0.0.1 \
    --hostname pihole \
    --cap-add=SYS_NICE \
    -e PIHOLE_UID=0 \
    -e PIHOLE_GID=0 \
    -e VIRTUAL_HOST="pihole" \
    -e PROXY_LOCATION="pihole" \
    -e FTLCONF_LOCAL_IPV4="192.168.6.254" \
    -e PIHOLE_DNS_="127.0.0.1#5335" \
    -e DNSMASQ_LISTENING="single" \
    -e IPv6="False" \
    -e SKIPGRAVITYONBOOT=1 \
    -e DBIMPORT=yes \
    ${DOCKER_IMAGE}:${DOCKER_TAG}

echo 'Waiting for new Pi-hole version to start'
sleep 5 # Allow Pi-hole to start up

if curl --connect-timeout 0.5 -fsL 192.168.6.254/admin -o /dev/null; then
  podman system prune --all --volumes
else
  code=$?
  echo 'Pi-hole deployment unsuccessful!'
  exit ${code}
fi
