#!/usr/bin/env bash

set -ouex pipefail

rpm-ostree override replace --experimental --from repo=copr:copr.fedorainfracloud.org:kylegospo:gnome-vrr \
  mutter \
  mutter-common \
  gnome-control-center \
  gnome-control-center-filesystem

rpm-ostree override replace \
  --experimental \
  --from repo=copr:copr.fedorainfracloud.org:kylegospo:prompt \
  vte291 \
  vte-profile \
  libadwaita

rpm-ostree install \
  prompt
