# Arch Linux, what Omarchy is built on: the newest bash, zsh and fish.
FROM archlinux:latest
RUN pacman -Syu --noconfirm --needed bash zsh fish tmux jq python util-linux diffutils findutils gawk \
 && pacman -Scc --noconfirm \
 && useradd -m tester
USER tester
