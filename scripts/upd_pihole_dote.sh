#!/bin/sh

set -e

DOCKER_TAG=2023.02.2
tmpdir="$(mktemp -d)"
curl -sSLo "${tmpdir}/dote" https://github.com/chrisstaite/DoTe/releases/latest/download/dote_arm64

cat > "${tmpdir}/Dockerfile" <<EOF
FROM pihole/pihole:${DOCKER_TAG}
ENV DOTE_OPTS="-s 127.0.0.1:5053"
COPY dote /opt/dote
RUN usermod -aG pihole www-data; \
  mkdir -p /etc/cont-init.d && \
  echo -e "#!/bin/sh\nchmod +x /opt/dote\n/opt/dote \\\$DOTE_OPTS -d\n" > /etc/cont-init.d/10-dote.sh && \
  chmod +x /etc/cont-init.d/10-dote.sh
EOF

echo 'Pulling new Pi-hole base image'
podman pull pihole/pihole:${DOCKER_TAG}
echo 'Building new Pi-hole image'
podman build -t pihole:latest --format docker -f "${tmpdir}/Dockerfile" "${tmpdir}"
rm -rf "${tmpdir}"

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
    --hostname pihole \
    --cap-add=SYS_NICE \
    -e PIHOLE_UID=0 \
    -e PIHOLE_GID=0 \
    -e DOTE_OPTS="-s 127.0.0.1:5053 --forwarder 1.1.1.1 --forwarder 1.0.0.1 --connections 10 --hostname cloudflare-dns.com --pin XdhSFdS2Zao99m31qAd/19S0SDzT2D52btXyYWqnJn4=" \
    -e VIRTUAL_HOST="pihole" \
    -e PROXY_LOCATION="pihole" \
    -e FTLCONF_LOCAL_IPV4="192.168.6.254" \
    -e PIHOLE_DNS_="127.0.0.1#5053" \
    -e IPv6="False" \
    -e SKIPGRAVITYONBOOT=1 \
    -e DBIMPORT=yes \
    pihole:latest

echo 'Waiting for new Pi-hole version to start'
sleep 5 # Allow Pi-hole to start up

if curl --connect-timeout 0.5 -fsL 192.168.6.254/admin -o /dev/null; then
  podman system prune
else
  code=$?
  echo 'Pi-hole deployment unsuccessful!'
  exit ${code}
fi
