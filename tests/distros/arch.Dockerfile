# Arch Linux, what Omarchy is built on: the newest bash, zsh and fish.
FROM archlinux:latest
RUN pacman -Syu --noconfirm --needed bash zsh fish tmux jq util-linux diffutils findutils gawk \
 && pacman -Scc --noconfirm \
 && useradd -m tester
USER tester
