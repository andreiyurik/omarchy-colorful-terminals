# Debian stable: older fish (3.6) and tmux.
FROM debian:12
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends zsh fish tmux jq bsdutils \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -m tester
USER tester
