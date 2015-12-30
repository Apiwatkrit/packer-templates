#!/bin/bash

set -e
set -x

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# This is only applicable when building Amazon EC2 image (AMI).
AMAZON_EC2='no'
if wget -q --timeout 1 --tries 2 --wait 1 -O - http://169.254.169.254/ &>/dev/null; then
    AMAZON_EC2='yes'
fi

logrotate -f /etc/logrotate.conf || true

# Remove old Kernel images that are not the current one.
rpm -q --whatprovides kernel | grep -Fv $(uname -r) | \
    xargs -I'{}' bash -c \
        "if rpm -q '{}' &>/dev/null; then yum -y remove '{}' || true; fi"

GROUPS_TO_PURGE=(
    'Editors'
    'Printing Support'
    'Dialup Networking Support'
    'Additional Development'
)

PACKAGES_TO_PURGE=(
    gcc cpp kernel-devel kernel-headers erase gtk2
    libX11 avahi hicolor-icon-theme bitstream-vera-fonts
    efibootmgr iscsi-initiator-utils
    plymouth plymouth-scripts plymouth-core-libs
    device-mapper-multipath-libs bridge-utils
    cryptsetup-luks fuse mdadm yum-utils
    libmpc mpfr zlib-devel openssl-devel
    iptables-ipv6 readline-devel
    system-config-firewall-base
    biosdevname prelink
    yum-plugin-remove-with-leaves
    man man-db
)

for group in "${GROUPS_TO_PURGE[@]}"; do
    yum -y groupremove "'$group'" 2> /dev/null || true
done

for package in "${PACKAGES_TO_PURGE[@]}"; do
    yum -y remove "'$package'" 2> /dev/null || true
done

for option in 'clean all' 'history new'; do
    yum -y --enablerepo='*' $option
done

rpmdb --rebuilddb

rm -f /var/lib/rpm/__db*

rm -f /core*

rm -f /boot/grub/menu.lst_*

rm -f VBoxGuestAdditions_*.iso \
      VBoxGuestAdditions_*.iso.?

rm -f /root/.bash_history \
      /root/.rnd* \
      /root/.hushlogin \
      /root/*.tar \
      /root/.*_history \
      /root/.lesshst \
      /root/.gemrc

rm -rf /root/.cache \
       /root/.{gem,gems} \
       /root/.vim* \
       /root/.ssh \
       /root/*

for u in vagrant ubuntu; do
    if getent passwd $u &>/dev/null; then
        rm -f /home/${u}/.bash_history \
              /home/${u}/.rnd* \
              /home/${u}/.hushlogin \
              /home/${u}/*.tar \
              /home/${u}/.*_history \
              /home/${u}/.lesshst \
              /home/${u}/.gemrc

        rm -rf /home/${u}/.cache \
               /home/${u}/.{gem,gems} \
               /home/${u}/.vim* \
               /home/${u}/*
    fi
done

rm -rf /etc/lvm/cache/.cache

# Clean if there are any Python software installed there.
if ls /opt/*/share &>/dev/null; then
  find /opt/*/share -type d -name 'man' -exec rm -rf '{}' \;
fi

if [[ $AMAZON_EC2 == 'no' ]]; then
    rm -rf /tmp/* /var/tmp/* /usr/tmp/*
else
    if [[ $PACKER_BUILDER_TYPE =~ ^amazon-ebs$ ]]; then
        # Will be excluded during the volume bundling process
        # only when building Instance Store type image, thus
        # we clean-up manually.
        rm -rf /tmp/* /var/tmp/* /usr/tmp/*
    fi
fi

rm -rf /usr/share/{doc,man}/* \
       /usr/local/share/{doc,man}

sed -i -e \
    '/^.\+fd0/d;/^.\*floppy0/d' \
    /etc/fstab

sed -i -e \
    '/^#/!s/\s\+/\t/g' \
    /etc/fstab

rm -rf /var/lib/man-db \
       /var/lib/ntp/ntp.drift

rm -rf /lib/recovery-mode

rm -rf /var/lib/cloud/data/scripts \
       /var/lib/cloud/scripts/per-instance \
       /var/lib/cloud/data/user-data*

# Prevent storing of the MAC address as part of the
# network interface details saved by udev.
rm -f /etc/udev/rules.d/70-persistent-net.rules \
      /etc/udev/rules.d/80-net-name-slot.rules \
      /lib/udev/rules.d/75-persistent-net-generator.rules

ln -sf /dev/null \
       /etc/udev/rules.d/70-persistent-net.rules

ln -sf /dev/null \
       /etc/udev/rules.d/80-net-name-slot.rules

rm -rf /dev/.udev \
       /var/lib/{dhcp,dhcp3}/* \
       /var/lib/dhclient/*

# Remove surplus locale (and only retain the English one).
mkdir -p /tmp/locale
mv /usr/share/locale/{en,en_US} /tmp/locale/
rm -rf /usr/share/locale/*
mv /tmp/locale/{en,en_US} /usr/share/locale/
rm -rf /tmp/locale

find /etc /var /usr -type f -name '*~' -exec rm -f '{}' \;
find /var/log /var/cache -type f -exec rm -rf '{}' \;

if [[ $AMAZON_EC2 == 'yes' ]]; then
    find /etc /root /home -type f -name 'authorized_keys' -exec rm -f '{}' \;
else
  # Only the Vagrant user should keep its SSH key. Everything
  # else will either use the user left form the image creation
  # time, or a new key will be fetched and stored by means of
  # cloud-init, etc.
  if ! getent passwd vagrant &> /dev/null; then
      find /etc /root /home -type f -name 'authorized_keys' -exec rm -f '{}' \;
  fi
fi

touch /var/log/{lastlog,wtmp,btmp}

chown root:root /var/log/{lastlog,wtmp,btmp}
chmod 644 /var/log/{lastlog,wtmp,btmp}
