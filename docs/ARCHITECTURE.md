# NEWOS architecture plan

NEWOS (working name) is a live USB Linux distro for security work. It boots amnesic like Tails, forces traffic through Tor like Whonix, ships a Kali tool suite, and has a cyberpunk desktop that mixes a macOS-style top bar and dock with Windows 8 live tiles.

## 1. Layers

```
┌──────────────────────────────────────────────────────────────┐
│ Desktop: KDE Plasma 6 + NEWOS shell theme                    │
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
| Tor model | **Single-system transparent Tor (Tails-style)** with per-purpose SOCKS ports for stream isolation | Works from one USB on any laptop. | **Whonix-style gateway + workstation VMs**: stronger (a compromised tool can't learn your real IP), but needs a hypervisor and ~2× RAM. Planned as an optional "split mode" later. |
| Desktop | **KDE Plasma 6** | Panels, floating dock, global menu, QML widgets and KWin effects cover every UI goal without writing a compositor. | Custom Wayland shell (months of work), GNOME + extensions |
| Persistence | **None in v1** | Amnesic by default. | Optional LUKS persistence partition (live-boot supports it) in v2 |

## 3. Networking modes

The biggest practical conflict: many pentest techniques **cannot run over Tor**. Tor only carries TCP, so raw SYN scans, UDP, ICMP, ARP, and all Wi-Fi attacks won't work. NEWOS makes the mode explicit and always visible:

| Mode | What happens | Use for |
|---|---|---|
| `tor` (default at boot) | All TCP → Tor TransPort, DNS → Tor, everything else dropped and logged | OSINT, web testing, `proxychains nmap -sT` |
| `direct` | Real interface, outbound open, inbound blocked. Needs typed confirmation. Magenta warning everywhere. | Lab/LAN pentests, Wi-Fi, full nmap |
| `offline` | Loopback only | Offline cracking, analysis |

Switch with `newos-netmode {tor|direct|offline|status}`. The rulesets live in `config/includes.chroot/etc/newos/nft/`.

Tor SOCKS ports (stream isolation, so activities don't share circuits):

- 9050 general · 9150 Tor Browser · 9060 pentest tools (proxychains) · 9070 apt updates

## 4. Amnesia checklist

- [x] Boot from read-only squashfs, writes go to RAM (live-boot default)
- [x] `noswap`, `swap.target` masked
- [x] Volatile journald, no core dumps, no shell history
- [x] Kernel hardening flags: `init_on_free=1 page_alloc.shuffle=1 slab_nomerge randomize_kstack_offset=on vsyscall=none`
- [x] Hostname `host`, UTC timezone, random MACs
- [ ] Wipe RAM on shutdown (Tails does this with a kexec/initramfs step)
- [ ] Emergency shutdown when the boot USB is pulled
- [ ] Don't auto-mount internal disks (polkit rule)

## 5. Desktop design: "neon glass"

- **Top bar** (macOS): Plasma panel at top, global menu on the left, then the net-mode badge (cyan TOR / magenta DIRECT / yellow OFFLINE), clock, tray.
- **Dock** (macOS): floating, auto-hiding bottom panel with icon-only task manager and magnification-like hover glow.
- **Live Tiles** (Windows 8): `org.newos.livetiles` plasmoid on the desktop or in a full-screen "Start" overlay. Tiles show live data (network mode, Tor circuit, clock, running jobs) and launch tool categories.
- **Look**: near-black `#0B0B14` glass surfaces, neon cyan / magenta / yellow accents, JetBrains Mono for headings, sharp corners on tiles, subtle scanline/glow KWin effects. Palette in `theme/palette.json`.

## 6. Repository layout

```
auto/config                      live-build options (Kali mirror, boot params)
config/package-lists/*.list.chroot   packages: base, anonymity, pentest, desktop
config/hooks/live/*.hook.chroot  scripts run inside the image at build time
config/includes.chroot/          files copied as-is into the image
  etc/tor/torrc                  Tor ports and isolation
  etc/newos/nft/*.nft            firewall per network mode
  usr/local/bin/newos-netmode    mode switcher
  usr/share/plasma/plasmoids/org.newos.livetiles   live tiles widget
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
