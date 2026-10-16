FROM ghcr.io/ublue-os/bazzite:stable

ARG FEDORA_VERSION=44
ARG FEDORA_VERSION
ARG OPENSNITCH_VERSION=latest
ARG WINDSCRIBE_VERSION=latest

# Waterfox
RUN set -euxo pipefail; \
    dnf -y install dnf5-plugins; \
    curl -fsSL -o "/etc/yum.repos.d/isv:BrowserWorks.repo" \
        "https://download.opensuse.org/repositories/isv:/BrowserWorks/Fedora_${FEDORA_VERSION}/isv:BrowserWorks.repo"; \
    dnf -y install waterfox grpc grpc-plugins python3-grpcio unity-gtk2-module libdbusmenu

#OpenSnitch (GitHub release RPMs: daemon + Qt6 GUI) ─────────────────────
# "latest" is resolved via the /releases/latest redirect (no API rate limits).
# The daemon RPM's %post ends with an unconditional `systemctl start`, which can't
# work during an image build (no running systemd) and makes dnf fail the whole
# transaction. Its scriptlets only enable/start the unit, so install it with
# scriptlets off and enable the unit in step 7. The GUI RPM's scriptlet is fine
# (it adds the XDG autostart entry), so that one installs normally.

RUN set -euxo pipefail; \
    ver="${OPENSNITCH_VERSION}"; \
    if [ "${ver}" = latest ]; then \
        tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/evilsocket/opensnitch/releases/latest)"; \
        ver="${tag##*/v}"; \
    fi; \
    base="https://github.com/evilsocket/opensnitch/releases/download/v${ver}"; \
    curl -fsSL -o /tmp/opensnitch.rpm    "${base}/opensnitch-${ver}-1.x86_64.rpm"; \
    curl -fsSL -o /tmp/opensnitch-ui.rpm "${base}/opensnitch-ui-${ver}-1.noarch.rpm"; \
    dnf -y install --setopt=tsflags=noscripts /tmp/opensnitch.rpm; \
    dnf -y install /tmp/opensnitch-ui.rpm; \
    rm -f /tmp/opensnitch.rpm /tmp/opensnitch-ui.rpm; \
    test -e /usr/lib/systemd/system/opensnitch.service


#Windscribe (GitHub release RPM, signature-checked) ─────────────────────
# The RPM installs to /opt/windscribe. On Fedora bootc images /opt is a symlink to
# /var/opt, and /var is not carried across image updates, so the payload is moved
# to /usr/lib/opt and linked back at boot with tmpfiles.d.

RUN set -euxo pipefail; \
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
    if [ -L /opt ]; then mkdir -p /var/opt; fi; \
    dnf -y install "/tmp/${pkg}"; \
    rm -f "/tmp/${pkg}" /tmp/windscribe.pub; \
    if [ -L /opt ]; then \
        mkdir -p /usr/lib/opt; \
        for d in /var/opt/*; do \
            [ -e "${d}" ] || continue; \
            n="${d##*/}"; \
            mv "${d}" "/usr/lib/opt/${n}"; \
            printf 'L+ /var/opt/%s - - - - /usr/lib/opt/%s\n' "${n}" "${n}" > "/usr/lib/tmpfiles.d/opt-${n}.conf"; \
        done; \
    fi; \
    test -e /opt/windscribe || test -e /usr/lib/opt/windscribe

RUN bootc container lint
