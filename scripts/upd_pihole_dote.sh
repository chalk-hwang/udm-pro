#!/bin/sh

set -e

tmpdir="$(mktemp -d)"
curl -sSLo "${tmpdir}/dote" https://github.com/chrisstaite/DoTe/releases/latest/download/dote_arm64

cat > "${tmpdir}/Dockerfile" <<EOF
FROM pihole/pihole:latest
ENV DOTE_OPTS="-s 127.0.0.1:5053"
COPY dote /opt/dote
RUN chmod +x /opt/dote && echo -e  "#!/bin/sh\n/opt/dote \\\$DOTE_OPTS -d\n" > /etc/cont-init.d/10-dote.sh
EOF

podman pull pihole/pihole:latest
podman build -t pihole:latest --format docker -f "${tmpdir}/Dockerfile" "${tmpdir}"
rm -rf "${tmpdir}"

set +e

podman stop pihole
podman rm pihole
podman run -d --network dns --restart always \
    --name pihole \
    -e TZ="Europe/Zurich" \
    -v "/mnt/data/etc-pihole/:/etc/pihole/" \
    -v "/mnt/data/pihole/etc-dnsmasq.d/:/etc/dnsmasq.d/" \
    -v "/mnt/data/pihole/hosts:/etc/hosts:ro" \
    --dns=127.0.0.1 \
    --hostname pihole \
    -e DOTE_OPTS="-s 127.0.0.1:5053 --forwarder 1.1.1.1:853 --connections 10 --hostname cloudflare-dns.com --pin XdhSFdS2Zao99m31qAd/19S0SDzT2D52btXyYWqnJn4=" \
    -e VIRTUAL_HOST="pihole" \
    -e PROXY_LOCATION="pihole" \
    -e ServerIP="192.168.6.254" \
    -e PIHOLE_DNS_="127.0.0.1#5053" \
    -e IPv6="False" \
    pihole:latest
