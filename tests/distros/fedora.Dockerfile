# Fedora: another family, with its own /etc/zshrc and fish 4.
FROM fedora:latest
RUN dnf install -y --setopt=install_weak_deps=False bash zsh fish tmux jq /usr/bin/script diffutils findutils gawk \
 && dnf clean all \
 && useradd -m tester
USER tester
