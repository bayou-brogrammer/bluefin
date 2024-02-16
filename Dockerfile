# syntax=docker/dockerfile:1.3-labs

ARG AKMODS_FLAVOR="asus"
ARG FEDORA_MAJOR_VERSION="39"

ARG IMAGE_FLAVOR="asus"
ARG BASE_IMAGE_NAME="silverblue"
ARG BASE_IMAGE="ghcr.io/ublue-os/$BASE_IMAGE_NAME-$IMAGE_FLAVOR"

FROM ghcr.io/ublue-os/akmods:${AKMODS_FLAVOR}-${FEDORA_MAJOR_VERSION} as orora-akmods
FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} as orora-base

# ==================================================================================================================================================== #
#                                                                 orora image section
# ==================================================================================================================================================== #

ARG IMAGE_FLAVOR
ARG AKMODS_FLAVOR
ARG BASE_IMAGE_NAME
ARG FEDORA_MAJOR_VERSION
ARG IMAGE_NAME="${IMAGE_NAME}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR}"
ARG PACKAGE_LIST="bluefin"

# Setup Copr repos
RUN wget https://copr.fedorainfracloud.org/coprs/varlad/zellij/repo/fedora-"${FEDORA_MAJOR_VERSION}"/varlad-zellij-fedora-"${FEDORA_MAJOR_VERSION}".repo -O /etc/yum.repos.d/zellij.repo && \
  wget https://copr.fedorainfracloud.org/coprs/kylegospo/prompt/repo/fedora-$(rpm -E %fedora)/kylegospo-prompt-fedora-$(rpm -E %fedora).repo?arch=x86_64 -O /etc/yum.repos.d/_copr_kylegospo-prompt.repo && \
  wget https://copr.fedorainfracloud.org/coprs/kylegospo/gnome-vrr/repo/fedora-"${FEDORA_MAJOR_VERSION}"/kylegospo-gnome-vrr-fedora-"${FEDORA_MAJOR_VERSION}".repo -O /etc/yum.repos.d/_copr_kylegospo-gnome-vrr.repo && \
  wget https://copr.fedorainfracloud.org/coprs/che/nerd-fonts/repo/fedora-"${FEDORA_MAJOR_VERSION}"/che-nerd-fonts-fedora-"${FEDORA_MAJOR_VERSION}".repo -O /etc/yum.repos.d/_copr_che-nerd-fonts-"${FEDORA_MAJOR_VERSION}".repo && \
  wget https://copr.fedorainfracloud.org/coprs/ublue-os/staging/repo/fedora-"${FEDORA_MAJOR_VERSION}"/ublue-os-staging-fedora-"${FEDORA_MAJOR_VERSION}".repo -O /etc/yum.repos.d/ublue-os-staging-fedora-"${FEDORA_MAJOR_VERSION}".repo

# Setup firmware and asusctl for ASUS devices
RUN --mount=type=cache,target=/var/cache/asus \
  if [[ "${IMAGE_FLAVOR}" =~ "asus" ]]; then \
  wget https://copr.fedorainfracloud.org/coprs/lukenukem/asus-linux/repo/fedora-$(rpm -E %fedora)/lukenukem-asus-linux-fedora-$(rpm -E %fedora).repo -O /etc/yum.repos.d/_copr_lukenukem-asus-linux.repo && \
  rpm-ostree install \
  asusctl \
  asusctl-rog-gui && \
  git clone https://gitlab.com/asus-linux/firmware.git --depth 1 /tmp/asus-firmware && \
  cp -rf /tmp/asus-firmware/* /usr/lib/firmware/ && \
  rm -rf /tmp/asus-firmware \
  ; fi

# ========================
# Copy Helper Folders
# ========================
COPY modules /tmp/modules
COPY scripts /tmp/scripts

# Remove unneeded software
RUN rpm-ostree override remove \
  power-profiles-daemon \
  || true && \
  rpm-ostree override remove \
  tlp \
  tlp-rdw \
  || true

# Add ublue kmods, add needed negativo17 repo and then immediately disable due to incompatibility with RPMFusion
COPY --from=orora-akmods /rpms /tmp/akmods-rpms
RUN --mount=type=cache,target=/var/cache/akmods \
  /tmp/modules/akmods.sh

# GNOME VRR & Prompt
RUN --mount=type=cache,target=/var/cache/packages \
  /tmp/modules/gnome-vrr-prompt.sh && \
  /tmp/modules/starship.sh

# ========================
# Copy Helper Files
# ========================
COPY packages.json /tmp/packages.json
COPY etc /etc

# Install packages and setup the image
RUN --mount=type=cache,target=/var/cache/bluefin-rpm \
  /tmp/scripts/build.sh && \
  # UBlue Update
  pip install --prefix=/usr topgrade yafti && \
  rpm-ostree install ublue-update 

# ========================
# Copy Core Files
# ========================
COPY usr /usr
COPY just /tmp/just

# Copy atuin from bluefin-cli
COPY --from=ghcr.io/ublue-os/bluefin-cli /usr/bin/atuin /usr/bin/atuin
COPY --from=ghcr.io/ublue-os/bluefin-cli /usr/share/bash-prexec /usr/share/bash-prexec

RUN \
  /tmp/scripts/image-info.sh && \
  /tmp/scripts/fetch-quadlets.sh && \
  # Just File
  find /tmp/just -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >> /usr/share/ublue-os/just/60-custom.just && \
  # Flatpak Remotes
  mkdir -p /usr/etc/flatpak/remotes.d && \
  wget -q https://dl.flathub.org/repo/flathub.flatpakrepo -P /usr/etc/flatpak/remotes.d && \
  # Fonts
  fc-cache -f \
  /usr/share/fonts/ubuntu \
  /usr/share/fonts/inter && \
  # Hide Apps
  echo "Hidden=true" >> /usr/share/applications/fish.desktop && \
  echo "Hidden=true" >> /usr/share/applications/htop.desktop && \
  echo "Hidden=true" >> /usr/share/applications/nvtop.desktop && \
  echo "Hidden=true" >> /usr/share/applications/gnome-system-monitor.desktop && \
  sed -i '/^PRETTY_NAME/s/Silverblue/Bluefin/' /usr/lib/os-release && \
  sed -i 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=15s/' /etc/systemd/user.conf && \
  sed -i 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=15s/' /etc/systemd/system.conf

RUN systemctl enable tuned.service && \
  systemctl enable tailscaled.service && \
  systemctl enable dconf-update.service && \
  systemctl enable ublue-update.timer && \
  systemctl enable ublue-system-setup.service && \
  systemctl enable rpm-ostree-countme.service && \
  systemctl enable ublue-system-flatpak-manager.service && \
  systemctl --global enable ublue-user-setup.service && \
  systemctl --global enable ublue-user-flatpak-manager.service

RUN rm -f /etc/yum.repos.d/charm.repo && \
  rm -f /etc/yum.repos.d/tailscale.repo && \
  rm -f /etc/yum.repos.d/_copr_kylegospo-prompt.repo && \
  rm -f /etc/yum.repos.d/_copr_kylegospo-gnome-vrr.repo && \
  rm -f /etc/yum.repos.d/_copr_che-nerd-fonts-"${FEDORA_MAJOR_VERSION}".repo && \
  rm -f /etc/yum.repos.d/ublue-os-staging-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
  rm -rf /tmp/* /var/* && \
  ostree container commit && \
  mkdir -p /var/tmp && \
  chmod -R 1777 /var/tmp

# ==================================================================================================================================================== #
#                                                         bluefin-dx developer edition image section
# ==================================================================================================================================================== #
## bluefin-dx developer edition image section
FROM orora-base AS bluefin-dx

ARG IMAGE_FLAVOR
ARG AKMODS_FLAVOR
ARG BASE_IMAGE_NAME
ARG FEDORA_MAJOR_VERSION
ARG IMAGE_NAME="${IMAGE_NAME}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR}"
ARG PACKAGE_LIST="bluefin-dx"

# Apply IP Forwarding before installing Docker to prevent messing with LXC networking
RUN sysctl -p

RUN wget https://copr.fedorainfracloud.org/coprs/ganto/lxc4/repo/fedora-"${FEDORA_MAJOR_VERSION}"/ganto-lxc4-fedora-"${FEDORA_MAJOR_VERSION}".repo -O /etc/yum.repos.d/ganto-lxc4-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
  wget https://copr.fedorainfracloud.org/coprs/ublue-os/staging/repo/fedora-"${FEDORA_MAJOR_VERSION}"/ublue-os-staging-fedora-"${FEDORA_MAJOR_VERSION}".repo -O /etc/yum.repos.d/ublue-os-staging-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
  wget https://copr.fedorainfracloud.org/coprs/karmab/kcli/repo/fedora-"${FEDORA_MAJOR_VERSION}"/karmab-kcli-fedora-"${FEDORA_MAJOR_VERSION}".repo -O /etc/yum.repos.d/karmab-kcli-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
  wget https://copr.fedorainfracloud.org/coprs/atim/ubuntu-fonts/repo/fedora-"${FEDORA_MAJOR_VERSION}"/atim-ubuntu-fonts-fedora-"${FEDORA_MAJOR_VERSION}".repo -O /etc/yum.repos.d/atim-ubuntu-fonts-fedora-"${FEDORA_MAJOR_VERSION}".repo


COPY dx/etc /etc
COPY scripts /tmp/scripts
COPY packages.json /tmp/packages.json

# Handle packages via packages.json
RUN /tmp/scripts/build.sh && \
  /tmp/scripts/image-info.sh

# Docker Desktop
RUN wget https://desktop.docker.com/linux/main/amd64/137060/docker-desktop-4.27.2-x86_64.rpm -O /tmp/docker-desktop.rpm && \
  rpm-ostree install /tmp/docker-desktop.rpm && \
  # Docker Compose
  wget https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -O /tmp/docker-compose && \
  install -c -m 0755 /tmp/docker-compose /usr/bin

# Kind
RUN curl -Lo ./kind "https://github.com/kubernetes-sigs/kind/releases/latest/download/kind-$(uname)-amd64" && \
  chmod +x ./kind && \
  mv ./kind /usr/bin/kind

# Install kns/kctx and add completions for Bash
RUN wget https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx -O /usr/bin/kubectx && \
  wget https://raw.githubusercontent.com/ahmetb/kubectx/master/kubens -O /usr/bin/kubens && \
  chmod +x /usr/bin/kubectx /usr/bin/kubens

# dx specific files come from the dx directory in this repo
COPY dx/usr /usr
COPY --from=cgr.dev/chainguard/ko:latest /usr/bin/ko /usr/bin/ko
COPY --from=cgr.dev/chainguard/dive:latest /usr/bin/dive /usr/bin/dive
COPY --from=cgr.dev/chainguard/flux:latest /usr/bin/flux /usr/bin/flux
COPY --from=cgr.dev/chainguard/helm:latest /usr/bin/helm /usr/bin/helm
COPY --from=cgr.dev/chainguard/minio-client:latest /usr/bin/mc /usr/bin/mc
COPY --from=cgr.dev/chainguard/kubectl:latest /usr/bin/kubectl /usr/bin/kubectl

# Set up services
RUN systemctl enable docker.socket && \
  systemctl enable podman.socket && \
  systemctl enable swtpm-workaround.service && \
  systemctl enable bluefin-dx-groups.service && \
  # Global
  systemctl enable --global bluefin-dx-user-vscode.service && \
  # Disable
  systemctl disable pmie.service && \
  systemctl disable pmlogger.service

RUN rm -f /etc/yum.repos.d/vscode.repo && \
  rm -f /etc/yum.repos.d/docker-ce.repo && \
  rm -f /etc/yum.repos.d/fedora-cisco-openh264.repo && \
  rm -f /etc/yum.repos.d/ganto-lxc4-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
  rm -f /etc/yum.repos.d/karmab-kcli-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
  rm -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:phracek:PyCharm.repo && \
  rm -f /etc/yum.repos.d/ublue-os-staging-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
  rm -f /etc/yum.repos.d/atim-ubuntu-fonts-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
  rm -rf /tmp/* /var/* && \
  ostree container commit

# ==================================================================================================================================================== #
#                                                         orora-dx developer edition image section
# ==================================================================================================================================================== #


FROM bluefin-dx AS orora-bluefin

ARG IMAGE_FLAVOR
ARG AKMODS_FLAVOR
ARG BASE_IMAGE_NAME
ARG FEDORA_MAJOR_VERSION
ARG IMAGE_NAME="${IMAGE_NAME}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR}"
ARG PACKAGE_LIST="orora"

COPY scripts /tmp/scripts
COPY packages.json /tmp/packages.json

# Handle packages via packages.json
RUN /tmp/scripts/build.sh && \
  /tmp/scripts/image-info.sh && \
  /tmp/scripts/workarounds.sh

# Clean up repos, everything is on the image so we don't need them
RUN rm -rf /tmp/* /var/* && \
  ostree container commit