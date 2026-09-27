# QEMU with a virtio GPU and UEFI firmware, to install and boot the real
# Omarchy ISO for the release test (see tests/release-vm/run). Needs /dev/kvm.
FROM archlinux:latest
# virtio-vga crashes QEMU without the virtio-gpu modules, which its Arch
# package does not pull in.
RUN pacman -Syu --noconfirm --needed qemu-base qemu-hw-display-virtio-vga \
      qemu-hw-display-virtio-gpu qemu-hw-display-virtio-gpu-pci edk2-ovmf \
      openssh socat jq openssl dosfstools mtools imagemagick tesseract tesseract-data-eng \
 && pacman -Scc --noconfirm
