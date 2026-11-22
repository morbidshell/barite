# fedora-kde-bootc
Warning: Built with heavy AI help.

Personal Fedora bootc image: KDE Plasma (Wayland) with Plasma Login Manager, CachyOS LTO kernel,
RPM Fusion + codecs, Steam, Lutris, Bottles, OpenSnitch, Windscribe and Waterfox.
x86_64 only.

## What comes from where

| Piece | Source |
|---|---|
| KDE Plasma (individual packages, no Discover: Plasma, KWin, Dolphin, Konsole, Plasma Login Manager, KWallet), lutris | Fedora repos |
| steam, ffmpeg, codecs, libdvdcss | RPM Fusion (free, nonfree, free-tainted) |
| bottles | COPR `vertigo-red/bottles` |
| kernel-cachyos-lto, -devel-matched | COPR `bieszczaders/kernel-cachyos-lto` |
| waterfox | `isv:BrowserWorks` repo (download.opensuse.org) |
| opensnitch + opensnitch-ui | GitHub release RPMs, fetched by `scripts/fetch-rpms.sh` (latest, or `OPENSNITCH_VERSION=1.8.0`) |
| windscribe | GitHub release RPM, fetched by `scripts/fetch-rpms.sh`, signature-checked (latest, or `WINDSCRIBE_VERSION=...`) |
| umu-launcher | GitHub release RPM, fetched by `scripts/fetch-rpms.sh` (latest, or `UMU_VERSION=...`) |

## Build

```
GH_TOKEN=... bash scripts/fetch-rpms.sh      # downloads the GitHub RPMs into ./rpms
sudo podman build --pull=newer -t fedora-kde-bootc .
```

Or push this repo to GitHub: `.github/workflows/build.yml` builds on every push and daily,
and publishes to `ghcr.io/morbidshell/barite:latest`.

## Install

From an existing Fedora bootc / Atomic system:

```
sudo bootc switch ghcr.io/morbidshell/barite:latest && sudo systemctl reboot
```

For a fresh install, make a disk image or ISO with `bootc-image-builder` and a `config.toml`
that creates your user (bootc images ship without one):

```toml
[[customizations.user]]
name = "you"
password = "change-me"
groups = ["wheel"]
```

## Things to know

- **Secure Boot:** the CachyOS kernel is not signed for Fedora's shim. Disable Secure Boot,
  or sign the kernel and enrol your key.
- **Login manager and first boot:** Fedora 44's KDE uses Plasma Login Manager
  (`plasmalogin.service`), not SDDM. Plasma Setup, the first-boot wizard that creates a user,
  runs before it unless `/etc/plasma-setup-done` exists. The image creates that file, because
  users come from the installer config (or already exist after `bootc switch`) and the wizard
  would add a second admin account. To get the wizard on fresh installs instead, remove the
  `touch /etc/plasma-setup-done` line from the Containerfile.
- **Wayland only:** recent Plasma (6.8) no longer ships an X11 session. X11 apps run through
  XWayland.
- **No Discover:** Plasma is installed package by package, without `plasma-discover`, which
  cannot update an image-based system. Update Flatpaks with `flatpak update` and the system with
  `bootc upgrade`.
- **Global Menu:** a brand-new Plasma profile gets a thin top panel with the Global Menu
  widget (KDE's own "Application Menu Bar" layout template, loaded by step 8a of the
  Containerfile). A profile that already exists keeps its panels; add it by hand with
  right-click on the desktop, Enter Edit Mode, the drop-down next to Add Panel, Application
  Menu Bar. It works for Qt/KDE apps (Dolphin, Kate, Konsole...). GTK apps cannot export their
  menus on Plasma Wayland ([KDE bug 424485](https://bugs.kde.org/show_bug.cgi?id=424485)), so
  native Wayland GTK apps stay out of it. `unity-gtk3-module` (Fedora's `appmenu-gtk3`) is
  installed for GTK3 apps that run through XWayland; if a GTK3 app ever loses its menu bar,
  remove that package, since it has been reported to hide menu bars on Wayland. Waterfox 6.7 is
  the exception: its release notes say it enables the global menu bar on Linux desktops that
  provide one, including on Wayland (not tested here). Firefox has a similar option behind
  `about:config` switches.
- **Secrets:** gnome-keyring is not installed. KWallet provides the Secret Service. Give the
  wallet the same password as your login so `pam-kwallet` unlocks it at login.
- **OpenSnitch:** the daemon (`opensnitch.service`) is enabled; start the GUI with `opensnitch-ui`.
- **Windscribe:** the RPM installs into `/opt`, which on Fedora bootc points at `/var/opt`.
  The Containerfile moves it to `/usr/lib/opt` and relinks it at boot.
