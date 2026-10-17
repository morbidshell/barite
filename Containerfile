FROM ghcr.io/ublue-os/bazzite:stable

ARG FEDORA_VERSION=44
ARG FEDORA_VERSION
ARG OPENSNITCH_VERSION=latest
ARG WINDSCRIBE_VERSION=latest

# Waterfox (BrowserWorks repo), OpenSnitch (GitHub RPMs), Windscribe (GitHub RPM)
#
# OpenSnitch: the daemon RPM's %post ends with an unconditional `systemctl start`,
# which can't work during an image build (no running systemd) and makes dnf fail the
# whole transaction. Its scriptlets only enable/start the unit, so the daemon is
# installed with scriptlets off and the unit is enabled in a later step. The GUI
# RPM's scriptlet is fine (it adds the XDG autostart entry).
#
# Windscribe: the RPM installs to /opt/windscribe. On Fedora bootc images /opt is a
# symlink to /var/opt, and /var is not carried across image updates, so the payload
# is moved to /usr/lib/opt and linked back at boot with tmpfiles.d.
RUN set -euxo pipefail; \
    if [ -L /opt ]; then mkdir -p /var/opt; fi; \
    echo "==> Waterfox"; \
    dnf -y install dnf5-plugins; \
    curl -fsSL -o "/etc/yum.repos.d/isv:BrowserWorks.repo" \
        "https://download.opensuse.org/repositories/isv:/BrowserWorks/Fedora_${FEDORA_VERSION}/isv:BrowserWorks.repo"; \
    dnf -y copr enable ruizhi-lab/latte-dock-ng; \
    dnf -y install latte-dock-ng waterfox unity-gtk2-module kio-admin libdbusmenu; \
    echo "==> OpenSnitch"; \
    ver="${OPENSNITCH_VERSION}"; \
    if [ "${ver}" = latest ]; then \
        tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/evilsocket/opensnitch/releases/latest)"; \
        ver="${tag##*/v}"; \
    fi; \
    base="https://github.com/evilsocket/opensnitch/releases/download/v${ver}"; \
    curl -fsSL -o /tmp/opensnitch.rpm    "${base}/opensnitch-${ver}-1.x86_64.rpm"; \
    curl -fsSL -o /tmp/opensnitch-ui.rpm "${base}/opensnitch-ui-${ver}-1.noarch.rpm"; \
    dnf -y install --setopt=tsflags=noscripts /tmp/opensnitch.rpm; \
    dnf -y install /tmp/opensnitch-ui.rpm grpc grpc-plugins python3-grpcio-tools python3-grpcio python3-slugify python3-inotify python3-protobuf; \
    rm -f /tmp/opensnitch.rpm /tmp/opensnitch-ui.rpm; \
    echo "==> Windscribe"; \
    ver="${WINDSCRIBE_VERSION}"; \
    if [ "${ver}" = latest ]; then \
        tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/Windscribe/Desktop-App/releases/latest)"; \
        ver="${tag##*/v}"; \
    fi; \
    pkg="windscribe_${ver}_amd64_fedora.rpm"; \
    curl -fsSL -o "/tmp/${pkg}" "https://github.com/Windscribe/Desktop-App/releases/download/v${ver}/${pkg}"; \
    curl -fsSL -o /tmp/windscribe.pub https://windscribe.com/windscribe_linux_signing_key.pub; \
    rpm --import /tmp/windscribe.pub; \
    rpmkeys --checksig "/tmp/${pkg}" | tee /dev/stderr | grep -q 'signatures OK'; \
    dnf -y install "/tmp/${pkg}"; \
    rm -f "/tmp/${pkg}" /tmp/windscribe.pub; \
    echo "==> Relocating /opt payloads"; \
    if [ -L /opt ]; then \
        mkdir -p /usr/lib/opt; \
        for d in /var/opt/*; do \
            [ -e "${d}" ] || continue; \
            n="${d##*/}"; \
            mv "${d}" "/usr/lib/opt/${n}"; \
            printf 'L+ /var/opt/%s - - - - /usr/lib/opt/%s\n' "${n}" "${n}" > "/usr/lib/tmpfiles.d/opt-${n}.conf"; \
        done; \
    fi; \
    test -e /usr/lib/systemd/system/opensnitch.service; \
    test -e /opt/windscribe || test -e /usr/lib/opt/windscribe; \
    dnf clean all

# Cleanup
RUN set -euxo pipefail; \
    dnf clean all; \
    rm -rf /var/cache/* /var/log/* /tmp/*; \
    find /boot -mindepth 1 -delete

RUN bootc container lint
