# NEWOS (working name)

An amnesic, Tor-first live Linux for security research with a cyberpunk desktop.

- **Amnesic** like Tails: runs from RAM, leaves nothing on the machine.
- **Tor by default** like Whonix: all traffic goes through Tor or is blocked. Switch to `direct` mode for lab work that needs your real interface.
- **Pentest suite** from Kali Rolling's tool metapackages.
- **Desktop**: KDE Plasma 6 themed as a neon macOS-style top bar + dock with Windows 8 style live tiles.

Read the plan: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Build

Needs Docker or Podman, about 30 GB of disk, and a good connection.

```sh
./build.sh            # or ENGINE=podman ./build.sh
```

The ISO lands at `live-image-amd64.hybrid.iso`. Test it in QEMU:

```sh
qemu-system-x86_64 -enable-kvm -m 6G -cdrom live-image-amd64.hybrid.iso
```

## Status

Early scaffold. Nothing has been built or booted yet.

## Use responsibly

Only test systems you own or have written permission to test.
