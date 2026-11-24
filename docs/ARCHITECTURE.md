# Ragnarok architecture plan

Ragnarok is a live USB Linux distro for security work. It boots amnesic like Tails, forces traffic through Tor like Whonix, ships a Kali tool suite, and has a dark glass desktop: a Windows 8 layout with live tiles, and macOS-style window buttons. Its symbol is an angular white R.

## 1. Layers

```
┌──────────────────────────────────────────────────────────────┐
│ Desktop: KDE Plasma 6 + Ragnarok shell theme                    │
│   top bar (global menu, net-mode badge) · floating dock ·    │
│   Live Tiles plasmoid · neon color scheme                    │
├──────────────────────────────────────────────────────────────┤
│ Tools: Kali metapackages (kali-tools-*) + proxychains → Tor  │
├──────────────────────────────────────────────────────────────┤
│ Anonymity: Tor (TransPort + DNSPort + isolated SOCKS ports)  │
│   nftables kill switch · netmode: tor / direct / offline     │
│   MAC randomization · no hostname in DHCP · IPv6 off         │
├──────────────────────────────────────────────────────────────┤
│ Amnesia: live-boot from squashfs, overlay in RAM, no swap,   │
│   volatile journal, no core dumps, hardened kernel cmdline   │
├──────────────────────────────────────────────────────────────┤
│ Base: Kali Rolling (Debian testing derivative), built with   │
│   live-build into a hybrid ISO (BIOS + UEFI)                 │
└──────────────────────────────────────────────────────────────┘
```

## 2. Key decisions (proposed, open for review)

| Area | Proposal | Why | Alternative |
|---|---|---|---|
| Base | **Kali Rolling** | Tools come from their native archive. Mixing Kali repos into Debian stable breaks upgrades ("FrankenDebian"). | Debian stable + hand-picked tools (more stable, older/fewer tools) |
| Build tool | **live-build** | What both Tails and Kali use; config is plain files in git. | mkosi, debos |
| Tor model | **Both, picked at boot.** "Ragnarok" = single-system transparent Tor (Tails-style). "Ragnarok Split" = the whole session runs in a sealed workstation namespace behind a Tor gateway (Whonix-style). | Tails-style works everywhere and allows direct mode; Split stops tools from ever seeing the real network. | Full Whonix VMs (gateway + workstation VMs): stronger still, since even root in the workstation can't escape, but needs a hypervisor and ~2x RAM. Possible later. |
| Desktop | **KDE Plasma 6** | Panels, floating dock, global menu, QML widgets and KWin effects cover every UI goal without writing a compositor. | Custom Wayland shell (months of work), GNOME + extensions |
| Persistence | **None in v1** | Amnesic by default. | Optional LUKS persistence partition (live-boot supports it) in v2 |

## 3. Networking modes

The biggest practical conflict: many pentest techniques **cannot run over Tor**. Tor only carries TCP, so raw SYN scans, UDP, ICMP, ARP, and all Wi-Fi attacks won't work. Ragnarok makes the mode explicit and always visible:

| Mode | What happens | Use for |
|---|---|---|
| `tor` (default at boot) | All TCP → Tor TransPort, DNS → Tor, everything else dropped and logged | OSINT, web testing, `proxychains nmap -sT` |
| `direct` | Real interface, outbound open, inbound blocked. Needs typed confirmation. Magenta warning everywhere. | Lab/LAN pentests, Wi-Fi, full nmap |
| `offline` | Loopback only | Offline cracking, analysis |

Switch with `ragnarok-netmode {tor|direct|offline|status}`. The rulesets live in `config/includes.chroot/etc/ragnarok/nft/`.

Tor SOCKS ports (stream isolation, so activities don't share circuits):

- 9050 general · 9150 Tor Browser · 9060 pentest tools (proxychains) · 9070 apt updates

## 3a. Boot sequence: Tor first

1. **sysinit**: `ragnarok-firewall.service` loads the Tor-only ruleset before any network interface comes up. Nothing can leak, even during boot.
2. **network up**: NetworkManager connects with a random MAC and no hostname. Only the `debian-tor` user is allowed out.
3. **Tor starts**: `ragnarok-tor-watch.service` (root) reads bootstrap progress from Tor's control socket and publishes it to `/run/ragnarok/tor-progress`. The desktop user never gets Tor control access.
4. **login**: the first thing on screen is the **Tor connection window** (`ragnarok-tor-connect`, autostart phase 0) with a progress bar. Apps that try to connect before Tor is ready just wait, because their traffic is held at the Tor redirect.
5. **stuck?** After 90 seconds the window offers **bridges** (Snowflake or pasted obfs4 lines), written to `/etc/tor/torrc.d/bridges.conf`, then restarts Tor.
6. **connected**: the window closes with a "Connected to Tor" notification and the desktop is ready.

Tor Browser is set to use the system Tor (`TOR_SKIP_LAUNCH=1`, port 9150), like Tails, so there's no Tor-over-Tor.

## 3b. Per-app network setup

When a new program that can use the network is installed, a **Network setup** window asks how it should connect:

| Choice | How it works |
|---|---|
| Through Tor (recommended) | Default transparent Tor redirect |
| Through Tor, own identity | `torsocks --isolate`, so it gets circuits no other app shares |
| Direct, real IP | Runs with group `ragnarok-direct`, which the firewall lets skip Tor. A second warning must be accepted. |
| No network | Runs with group `ragnarok-offline`, which the firewall drops |

How the pieces fit:

- `DPkg::Post-Invoke` runs `scan-new-apps` after every apt install. It finds new `.desktop` apps that look network-capable (network/Kali menu categories, or linking libcurl, libssl, Qt Network, NSS, libpcap and similar) and writes an override launcher in `/usr/local/share/applications` whose `Exec` goes through `ragnarok-run`.
- The desktop watcher (`ragnarok-netpolicy watch`) sees the new app and pops the setup window right away. If it's missed, the window shows on the app's first launch instead.
- Choices are saved per user in `~/.config/ragnarok/netpolicy`. Preinstalled apps default to Tor (`/etc/ragnarok/netpolicy.default`).
- **App Network Settings** in the menu (`ragnarok-netpolicy`) lists every app and lets you change its choice later.
- Terminal tools have no launcher, so they use Tor by default. You can use `proxychains4` for their own SOCKS port, or the same groups by hand: `sg ragnarok-direct -c "nmap -sS 10.0.0.0/24"`.

Known limits for v1: the windows are plain `kdialog` dialogs and will be replaced with themed QML. Because the live user is in `ragnarok-direct`, malware running as that user could also bypass Tor. The Whonix-style split mode closes that gap.

## 3c. Split mode (Whonix-style)

Pick **Ragnarok Split** in the boot menu (kernel argument `ragnarok.split=1`).

```
 workstation namespace "ws"                 gateway (main system)
 desktop, browser, every tool              NetworkManager, real NIC, Tor
 veth-ws 10.152.152.11  ── virtual cable ──  veth-gw 10.152.152.10 ──► Tor ──► internet
```

- `ragnarok-split.service` creates the namespace and the cable, loads the workstation firewall (`split-ws.nft`: gateway only) and tells Tor to listen on the gateway side (`/etc/tor/torrc.d/50-split.conf`).
- A systemd generator puts `sddm.service` and `user@.service` into the namespace, so the login screen, Plasma and every app start there and never see the real interface.
- On the gateway, `tor.nft` sends all TCP arriving on `veth-gw` into Tor's TransPort and DNS into Tor's DNSPort. Nothing is forwarded or routed.
- `ragnarok-split-forwarders.service` (socat, inside the namespace) keeps the usual `127.0.0.1` DNS and SOCKS ports working for apps.
- Direct mode is disabled: `ragnarok-netmode` refuses to switch, and apps set to "direct" run through Tor with a notice. "No network" still works.

Limits: this is namespace isolation, not a VM. A process that becomes root inside the session could leave the namespace, and apps can still ask NetworkManager over D-Bus for the local LAN address. Full gateway and workstation VMs would close both, at the cost of a hypervisor and about double the RAM.

## 4. Amnesia checklist

- [x] Boot from read-only squashfs, writes go to RAM (live-boot default)
- [x] `noswap`, `swap.target` masked
- [x] Volatile journald, no core dumps, no shell history
- [x] Kernel hardening flags: `init_on_free=1 page_alloc.shuffle=1 slab_nomerge randomize_kstack_offset=on vsyscall=none`
- [x] Hostname `host`, UTC timezone, random MACs
- [x] DNS answered only by Tor (static `/etc/resolv.conf` → 127.0.0.1:53, NetworkManager `dns=none`)
- [ ] Wipe RAM on shutdown (Tails does this with a kexec/initramfs step)
- [ ] Emergency shutdown when the boot USB is pulled
- [ ] Don't auto-mount internal disks (polkit rule)

## 5. Desktop design: "dark glass"

Black and dark grey glass everywhere, white text and icons, no colour accents.

- **Window frames** (macOS feel): Aurorae theme `ragnarok-glass` in `/usr/share/aurorae/themes/`. Title bar and 1px border are translucent dark glass with rounded top corners. Close, minimize and maximize/restore are solid white circles on the **left**, showing their glyph on hover. KWin blur is enabled.
- **Main interface** (Windows 8 layout): one full-width glass taskbar at the bottom with a Start button (white four-square logo) that opens the full-screen app grid (Application Dashboard). The desktop shows the **Live Tiles** "Start" group: wide live tiles for network/Tor status and the clock, then square tiles for Tor Browser, Terminal, Files, Recon, Web, Exploit, Wireless, Passwords, App Network Settings and Settings.
- **Colours**: `RagnarokGlass` colour scheme, Konsole `RagnarokGlass` profile (translucent with blur), Plasma theme breeze-dark, Papirus-Dark icons. Tokens in `theme/palette.json`.
- **Wallpaper**: `Ragnarok` (dark glass panes). The neon city wallpaper is kept as `Ragnarok-Neon`.
- **Startup, in order**: boot menu (GRUB on UEFI, syslinux on BIOS, both themed in `config/bootloaders/`), Plymouth boot splash `ragnarok` (white logo + Windows 8 style orbiting dots), Plasma loading screen (same style, from the `org.ragnarok.glass` look-and-feel package), then the Tor connection window, then the desktop.

Defaults reach the live user through `/etc/skel/.config` (kdeglobals, kwinrc, plasmarc, ksplashrc, konsolerc) and the look-and-feel package's layout script.

## 6. Repository layout

```
auto/config                      live-build options (Kali mirror, boot params)
config/package-lists/*.list.chroot   packages: base, anonymity, pentest, desktop
config/hooks/live/*.hook.chroot  scripts run inside the image at build time
config/includes.chroot/          files copied as-is into the image
  etc/tor/torrc                  Tor ports and isolation
  etc/ragnarok/nft/*.nft            firewall per network mode
  usr/local/bin/ragnarok-netmode    global mode switcher
  usr/local/bin/ragnarok-tor-connect   Tor connection window at login
  usr/local/bin/ragnarok-run, ragnarok-netpolicy   per-app network routing + setup window
  usr/local/lib/ragnarok/           root helpers (Tor progress, bridges, new-app scan)
  usr/share/plasma/plasmoids/org.ragnarok.livetiles   live tiles widget
theme/palette.json               design tokens
build.sh                         builds the ISO in a Kali container
```

## 7. Roadmap

1. **Boots** – ISO builds, boots in QEMU/VirtualBox, Tor-only firewall active, leak test passes (`curl` direct fails, `check.torproject.org` says yes).
2. **Looks** – Plasma global theme package (colors, panel layout, wallpaper, SDDM + Plymouth themes), Live Tiles polished, net-mode badge widget.
3. **Hardens** – RAM wipe on shutdown, USB-pull kill switch, AppArmor profiles, signed ISO releases, reproducible build in CI.
4. **Split mode** – optional Whonix-style Tor gateway VM so tools run in a workstation VM that never sees the real network.
5. **Persistence** – optional encrypted persistent volume for tool configs and notes.

## 8. Legal / ethics

Ship with a first-boot notice: tools are for systems you own or are authorized to test. Tor hides your IP from targets, not your responsibility.
