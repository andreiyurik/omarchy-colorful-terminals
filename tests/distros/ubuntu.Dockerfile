# Ubuntu LTS: Debian's /etc/zsh/zshrc (with compinit), fish 3.7, and mawk.
FROM ubuntu:24.04
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends zsh fish tmux jq bsdutils \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -m tester
USER tester
