#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

readonly CENTOS_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/centos-release)

# Get the major release version only.
readonly CENTOS_MAJOR_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/centos-release | cut -d . -f 1)

# This is only applicable when building Amazon EC2 image (AMI).
AMAZON_EC2='no'
if wget -q --timeout 1 --tries 2 --wait 1 -O - http://169.254.169.254/ &>/dev/null; then
    AMAZON_EC2='yes'
fi

yum -y update

if [[ $UBUNTU_VERSION == '12.04' ]]; then
    apt-get -y --force-yes install libreadline-dev dpkg
fi

if [[ $CENTOS_MAJOR_VERSION == '7' ]]; then
    timedatectl --no-pager --no-ask-password \
        set-timezone Etc/UTC
else
    ln -sf /usr/share/zoneinfo/Etc/UTC \
           /etc/localtime
fi

LOCALES=(
    en_US.UTF-8
    en_US.Latin1
    en_US.Latin9
    en_US.ISO-8859-1
    en_US.ISO-8859-15
)

for l in "${LOCALES[@]}"; do
    localedef -c -f UTF-8 -i en_US $l || true
done

if [[ $CENTOS_MAJOR_VERSION == '7' ]]; then
    localectl --no-pager --no-ask-password \
        set-locale LANG="en_US.UTF-8"
else
    cat <<'EOF' | tee /etc/locale.conf
LANG="en_US.UTF-8"
EOF

    chown root:root /etc/locale.conf
    chmod 644 /etc/locale.conf
fi

cat <<'EOF' | tee /etc/modprobe.d/blacklist.conf
blacklist pcspkr
blacklist soundcore

# Not widely used any more.
alias block-major-2 off
blacklist floppy

blacklist parport
EOF

cat <<'EOF' | tee /etc/modprobe.d/blacklist-watchdog.conf
# Do not load hardware watchdog drivers automatically.
blacklist wdt
blacklist wdt_pci
blacklist softdog
blacklist iTCO_wdt
EOF

chown root:root \
    /etc/modprobe.d/blacklist*.conf

chmod 644 \
    /etc/modprobe.d/blacklist*.conf

# Make sure that /srv exists.
[[ -d /srv ]] || mkdir -p /srv
chown root:root /srv
chmod 755 /srv
