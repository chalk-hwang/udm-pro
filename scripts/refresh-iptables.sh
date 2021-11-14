#!/bin/sh

set -e

if ! iptables-save | grep -e '\-A PREROUTING.* \--log-prefix "\[' > /dev/null; then
  /mnt/data/on_boot.d/10-dns.sh
else
  echo "iptables already contains DNAT log prefixes, ignoring."
fi

/mnt/data/on_boot.d/30-ipt-enable-logs-launch.sh
