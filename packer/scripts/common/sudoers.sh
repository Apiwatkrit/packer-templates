#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Get the major release version only.
readonly UBUNTU_MAJOR_VERSION=$(lsb_release -r | awk '{ print $2 }' | cut -d . -f 1)

sed -i -e \
    's/^\(.*env_keep = \"\)/\1PATH /' \
    /etc/sudoers

sed -i -e \
    's/^Defaults.*requiretty/Defaults\t!requiretty/' \
    /etc/sudoers

SUDO_GROUP='admin'
if (( $UBUNTU_MAJOR_VERSION > 12 )); then
    SUDO_GROUP='sudo'
fi

sed -i -e \
    "/Defaults\s\+env_reset/a Defaults\texempt_group=${SUDO_GROUP}" \
    /etc/sudoers

sed -i -e \
    "s/%${SUDO_GROUP}\s*ALL=(ALL:ALL) ALL/%${SUDO_GROUP}\tALL=NOPASSWD:ALL/g" \
    /etc/sudoers

if ! grep -q 'env_keep' /etc/sudoers; then
    sed -i -e \
        '/Defaults\s\+env_reset/a Defaults\tenv_keep = "PATH HOME SSH_AGENT_PID SSH_AUTH_SOCK"' \
        /etc/sudoers
fi

if ! grep -q 'requiretty' /etc/sudoers; then
    sed -i -e \
        '/Defaults\s\+env_reset/i Defaults\t!requiretty,!tty_tickets' \
        /etc/sudoers
fi

chown root: /etc/sudoers
chmod 440 /etc/sudoers

for user in root ubuntu; do
    if getent passwd $user &>/dev/null; then
        echo "${user}:$(date | md5sum)" | chpasswd
        passwd -l $user
    fi
done

cat <<'EOF' | tee /etc/securetty
console
tty1
vc/1
EOF

chown root: /etc/securetty
chmod 440 /etc/securetty

# Make sure to disallow access to "su" for everyone
# other than a root user or a decidated group.
dpkg-statoverride --update --add root $SUDO_GROUP 4750 /bin/su
