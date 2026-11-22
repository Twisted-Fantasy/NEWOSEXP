#!/bin/sh
# Build the Ragnarok ISO inside a Kali Rolling container.
# Needs Docker (or Podman) and ~30 GB free disk. Output: ./live-image-amd64.hybrid.iso
set -eu
ENGINE="${ENGINE:-docker}"
"$ENGINE" run --rm --privileged \
  -v "$(pwd)":/build -w /build \
  docker.io/kalilinux/kali-rolling:latest \
  sh -c 'apt-get update && apt-get install -y live-build cpio && lb clean && lb config && lb build'
