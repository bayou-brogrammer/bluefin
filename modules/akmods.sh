#!/usr/bin/env bash

set -ouex pipefail

sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/_copr_ublue-os-akmods.repo
wget https://negativo17.org/repos/fedora-multimedia.repo -O /etc/yum.repos.d/negativo17-fedora-multimedia.repo

rpm-ostree install \
  /tmp/akmods-rpms/kmods/*openrazer*.rpm \
  /tmp/akmods-rpms/kmods/*ryzen-smu*.rpm \
  /tmp/akmods-rpms/kmods/*v4l2loopback*.rpm \
  /tmp/akmods-rpms/kmods/*wl*.rpm \
  /tmp/akmods-rpms/kmods/*xone*.rpm \
  /tmp/akmods-rpms/kmods/*xpadneo*.rpm \
  /tmp/akmods-rpms/kmods/*zenergy*.rpm

if grep -qv "asus" <<<"${AKMODS_FLAVOR}"; then
  rpm-ostree install \
    /tmp/akmods-rpms/kmods/*evdi*.rpm
fi
sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/negativo17-fedora-multimedia.repo
