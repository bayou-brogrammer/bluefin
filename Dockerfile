ARG BASE_HUB="ghcr.io/ublue-os"
ARG IMAGE_FLAVOR="${IMAGE_FLAVOR:-main}"
ARG AKMODS_FLAVOR="${AKMODS_FLAVOR:-main}"
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-silverblue}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-39}"
ARG SOURCE_IMAGE="${SOURCE_IMAGE:-$BASE_IMAGE_NAME-$IMAGE_FLAVOR}"
ARG BASE_IMAGE="${BASE_HUB}/${SOURCE_IMAGE}"

## bluefin image section
FROM ${BASE_HUB}/akmods:${AKMODS_FLAVOR}-${FEDORA_MAJOR_VERSION} AS bluefin-akmods
FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} AS bluefin

ARG IMAGE_FLAVOR
ARG AKMODS_FLAVOR
ARG BASE_IMAGE_NAME
ARG FEDORA_MAJOR_VERSION
ARG IMAGE_NAME="${IMAGE_NAME}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR}"
ARG PACKAGE_LIST="bluefin"

COPY usr /usr
COPY etc /etc
COPY just /tmp/just
COPY scripts/ /tmp/scripts
COPY packages.json /tmp/packages.json
# Copy ublue-update.toml to tmp first, to avoid being overwritten.
COPY usr/etc/ublue-update/ublue-update.toml /tmp/ublue-update.toml

# Setup Copr repos
RUN wget https://copr.fedorainfracloud.org/coprs/kylegospo/prompt/repo/fedora-$(rpm -E %fedora)/kylegospo-prompt-fedora-$(rpm -E %fedora).repo?arch=x86_64 -O /etc/yum.repos.d/_copr_kylegospo-prompt.repo && \
  wget https://copr.fedorainfracloud.org/coprs/kylegospo/gnome-vrr/repo/fedora-"${FEDORA_MAJOR_VERSION}"/kylegospo-gnome-vrr-fedora-"${FEDORA_MAJOR_VERSION}".repo -O /etc/yum.repos.d/_copr_kylegospo-gnome-vrr.repo && \
  wget https://copr.fedorainfracloud.org/coprs/che/nerd-fonts/repo/fedora-"${FEDORA_MAJOR_VERSION}"/che-nerd-fonts-fedora-"${FEDORA_MAJOR_VERSION}".repo -O /etc/yum.repos.d/_copr_che-nerd-fonts-"${FEDORA_MAJOR_VERSION}".repo && \
  wget https://copr.fedorainfracloud.org/coprs/ublue-os/staging/repo/fedora-"${FEDORA_MAJOR_VERSION}"/ublue-os-staging-fedora-"${FEDORA_MAJOR_VERSION}".repo -O /etc/yum.repos.d/ublue-os-staging-fedora-"${FEDORA_MAJOR_VERSION}".repo

# Remove unneeded packages
RUN --mount=type=cache,target=/var/cache/rpm-ostree \
  rpm-ostree override remove \
  power-profiles-daemon \
  || true && \
  rpm-ostree override remove \
  tlp \
  tlp-rdw \
  || true

# Setup firmware and asusctl for ASUS devices
RUN --mount=type=cache,target=/var/cache/asus-firmware \
  if [[ "${IMAGE_FLAVOR}" =~ "asus" ]]; then \
  wget https://copr.fedorainfracloud.org/coprs/lukenukem/asus-linux/repo/fedora-$(rpm -E %fedora)/lukenukem-asus-linux-fedora-$(rpm -E %fedora).repo -O /etc/yum.repos.d/_copr_lukenukem-asus-linux.repo && \
  rpm-ostree install \
  asusctl \
  asusctl-rog-gui && \
  git clone https://gitlab.com/asus-linux/firmware.git --depth 1 /tmp/asus-firmware && \
  cp -rf /tmp/asus-firmware/* /usr/lib/firmware/ && \
  rm -rf /tmp/asus-firmware \
  ; fi

# Add ublue kmods, add needed negativo17 repo and then immediately disable due to incompatibility with RPMFusion
COPY --from=bluefin-akmods /rpms /tmp/akmods-rpms
RUN --mount=type=cache,target=/var/cache/akmods \
  sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/_copr_ublue-os-akmods.repo && \
  wget https://negativo17.org/repos/fedora-multimedia.repo -O /etc/yum.repos.d/negativo17-fedora-multimedia.repo && \
  rpm-ostree install \
  /tmp/akmods-rpms/kmods/*xpadneo*.rpm \
  /tmp/akmods-rpms/kmods/*xone*.rpm \
  /tmp/akmods-rpms/kmods/*openrazer*.rpm \
  /tmp/akmods-rpms/kmods/*v4l2loopback*.rpm \
  /tmp/akmods-rpms/kmods/*wl*.rpm \
  /tmp/akmods-rpms/kmods/*evdi*.rpm && \
  sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/negativo17-fedora-multimedia.repo

# RUN <<EOF
#     wget https://negativo17.org/repos/fedora-multimedia.repo -O /etc/yum.repos.d/negativo17-fedora-multimedia.repo && \
#     sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/_copr_ublue-os-akmods.repo
#     rpm-ostree install \
#         /tmp/akmods-rpms/kmods/*evdi*.rpm \
#         /tmp/akmods-rpms/kmods/*xpadneo*.rpm \
#         /tmp/akmods-rpms/kmods/*xone*.rpm \
#         /tmp/akmods-rpms/kmods/*openrazer*.rpm \
#         /tmp/akmods-rpms/kmods/*ryzen-smu*.rpm \
#         /tmp/akmods-rpms/kmods/*v4l2loopback*.rpm \
#         /tmp/akmods-rpms/kmods/*zenergy*.rpm \
#         /tmp/akmods-rpms/kmods/*wl*.rpm
#     sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/negativo17-fedora-multimedia.repo
# EOF

# GNOME VRR & Prompt
RUN --mount=type=cache,target=/var/cache/gnome-prompt \
  rpm-ostree override replace \
  --experimental \
  --from repo=copr:copr.fedorainfracloud.org:kylegospo:gnome-vrr \
  mutter \
  mutter-common \
  gnome-control-center \
  gnome-control-center-filesystem && \
  # Prompt
  rpm-ostree override replace \
  --experimental \
  --from repo=copr:copr.fedorainfracloud.org:kylegospo:prompt \
  vte291 \
  vte-profile && \
  rpm-ostree install \
  prompt && \
  rm -f /etc/yum.repos.d/_copr_kylegospo-gnome-vrr.repo && \
  rm -f /etc/yum.repos.d/_copr_kylegospo-prompt.repo

RUN  --mount=type=cache,target=/var/cache/bluefin \
  /tmp/scripts/starship.sh && \
  /tmp/scripts/build.sh && \
  /tmp/scripts/image-info.sh && \
  /tmp/scripts/fetch-quadlets.sh && \
  pip install --prefix=/usr yafti && \
  pip install --prefix=/usr topgrade && \
  rpm-ostree install ublue-update && \
  mkdir -p /usr/etc/flatpak/remotes.d && \
  wget -q https://dl.flathub.org/repo/flathub.flatpakrepo -P /usr/etc/flatpak/remotes.d && \
  cp /tmp/ublue-update.toml /usr/etc/ublue-update/ublue-update.toml && \
  if [[ "${FEDORA_MAJOR_VERSION}" -ge "39" ]]; then \
  systemctl enable tuned.service \
  ; fi && \
  systemctl enable rpm-ostree-countme.service && \
  systemctl enable tailscaled.service && \
  systemctl enable dconf-update.service && \
  systemctl enable ublue-update.timer && \
  systemctl enable ublue-system-setup.service && \
  systemctl enable ublue-system-flatpak-manager.service && \
  systemctl --global enable ublue-user-flatpak-manager.service && \
  systemctl --global enable ublue-user-setup.service && \
  fc-cache -f /usr/share/fonts/ubuntu && \
  fc-cache -f /usr/share/fonts/inter && \
  find /tmp/just -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >> /usr/share/ublue-os/just/60-custom.just && \
  rm -f /etc/yum.repos.d/tailscale.repo && \
  rm -f /etc/yum.repos.d/charm.repo && \
  rm -f /etc/yum.repos.d/ublue-os-staging-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
  echo "Hidden=true" >> /usr/share/applications/fish.desktop && \
  echo "Hidden=true" >> /usr/share/applications/htop.desktop && \
  echo "Hidden=true" >> /usr/share/applications/nvtop.desktop && \
  echo "Hidden=true" >> /usr/share/applications/gnome-system-monitor.desktop && \
  rm -f /etc/yum.repos.d/_copr_che-nerd-fonts-"${FEDORA_MAJOR_VERSION}".repo && \
  sed -i 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=15s/' /etc/systemd/user.conf && \
  sed -i 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=15s/' /etc/systemd/system.conf && \
  sed -i '/^PRETTY_NAME/s/Silverblue/Bluefin/' /usr/lib/os-release

# Clean up repos
RUN rm -f /etc/yum.repos.d/charm.repo \
  rm -f /etc/yum.repos.d/tailscale.repo \
  rm -f /etc/yum.repos.d/_copr_che-nerd-fonts-"${FEDORA_MAJOR_VERSION}".repo \
  rm -f /etc/yum.repos.d/ublue-os-staging-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
  rm -rf /tmp/* /var/* && \
  ostree container commit && \
  mkdir -p /var/tmp && \
  chmod -R 1777 /var/tmp

# bluefin-dx developer edition image section
FROM bluefin AS bluefin-dx

ARG IMAGE_FLAVOR
ARG BASE_IMAGE_NAME
ARG FEDORA_MAJOR_VERSION
ARG IMAGE_NAME="${IMAGE_NAME}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR}"
ARG PACKAGE_LIST="bluefin-dx"

# dx specific files come from the dx directory in this repo
COPY dx/usr /usr
COPY dx/etc /etc/
COPY scripts /tmp/scripts
COPY packages.json /tmp/packages.json
COPY --from=cgr.dev/chainguard/ko:latest /usr/bin/ko /usr/bin/ko
COPY --from=cgr.dev/chainguard/dive:latest /usr/bin/dive /usr/bin/dive
COPY --from=cgr.dev/chainguard/flux:latest /usr/bin/flux /usr/bin/flux
COPY --from=cgr.dev/chainguard/helm:latest /usr/bin/helm /usr/bin/helm
COPY --from=cgr.dev/chainguard/minio-client:latest /usr/bin/mc /usr/bin/mc
COPY --from=cgr.dev/chainguard/kubectl:latest /usr/bin/kubectl /usr/bin/kubectl

# Apply IP Forwarding before installing Docker to prevent messing with LXC networking
RUN sysctl -p

RUN wget https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -O /tmp/docker-compose && \
  wget https://copr.fedorainfracloud.org/coprs/ganto/lxc4/repo/fedora-"${FEDORA_MAJOR_VERSION}"/ganto-lxc4-fedora-"${FEDORA_MAJOR_VERSION}".repo -O /etc/yum.repos.d/ganto-lxc4-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
  wget https://copr.fedorainfracloud.org/coprs/karmab/kcli/repo/fedora-"${FEDORA_MAJOR_VERSION}"/karmab-kcli-fedora-"${FEDORA_MAJOR_VERSION}".repo -O /etc/yum.repos.d/karmab-kcli-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
  wget https://copr.fedorainfracloud.org/coprs/ublue-os/staging/repo/fedora-"${FEDORA_MAJOR_VERSION}"/ublue-os-staging-fedora-"${FEDORA_MAJOR_VERSION}".repo -O /etc/yum.repos.d/ublue-os-staging-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
  wget https://copr.fedorainfracloud.org/coprs/atim/ubuntu-fonts/repo/fedora-"${FEDORA_MAJOR_VERSION}"/atim-ubuntu-fonts-fedora-"${FEDORA_MAJOR_VERSION}".repo -O /etc/yum.repos.d/atim-ubuntu-fonts-fedora-"${FEDORA_MAJOR_VERSION}".repo

# Handle packages via packages.json
RUN /tmp/scripts/build.sh && /tmp/scripts/image-info.sh

# docker-compose and kind
RUN install -c -m 0755 /tmp/docker-compose /usr/bin && \
  curl -Lo ./kind "https://github.com/kubernetes-sigs/kind/releases/latest/download/kind-$(uname)-amd64" && \
  chmod +x ./kind && \
  mv ./kind /usr/bin/kind

# Install kns/kctx and add completions for Bash
RUN wget https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx -O /usr/bin/kubectx && \
  wget https://raw.githubusercontent.com/ahmetb/kubectx/master/kubens -O /usr/bin/kubens && \
  chmod +x /usr/bin/kubectx /usr/bin/kubens

# Set up services
RUN systemctl disable pmie.service && \
  systemctl enable podman.socket && \
  systemctl enable docker.socket && \
  systemctl disable pmlogger.service && \
  systemctl enable swtpm-workaround.service && \
  systemctl enable bluefin-dx-groups.service && \
  systemctl enable --global bluefin-dx-user-vscode.service

RUN /tmp/scripts/workarounds.sh

# Clean up repos, everything is on the image so we don't need them
RUN rm -f /etc/yum.repos.d/ublue-os-staging-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
  rm -f /etc/yum.repos.d/ganto-lxc4-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
  rm -f /etc/yum.repos.d/karmab-kcli-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
  rm -f /etc/yum.repos.d/atim-ubuntu-fonts-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
  rm -f /etc/yum.repos.d/vscode.repo && \
  rm -f /etc/yum.repos.d/docker-ce.repo && \
  rm -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:phracek:PyCharm.repo && \
  rm -f /etc/yum.repos.d/fedora-cisco-openh264.repo && \
  rm -rf /tmp/* /var/* && \
  ostree container commit