# Quickshell on Arch, to run the panel tests against an Omarchy shell tree
# mounted at /omarchy (see tests/omarchy/run). Offscreen: no display needed.
# SNAPSHOT=YYYY/MM/DD installs Arch as it was on that day (the Arch Linux
# Archive), so a release is tested with the Qt it shipped with; empty means
# today's Arch, which is what the default branch is being built for.
FROM archlinux:latest
ARG SNAPSHOT=
RUN if [ -n "$SNAPSHOT" ]; then \
      echo "Server = https://archive.archlinux.org/repos/$SNAPSHOT/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist; \
    fi \
 && pacman -Syuu --noconfirm --needed quickshell qt6-svg jq bash util-linux ttf-jetbrains-mono-nerd \
 && pacman -Scc --noconfirm \
 && useradd -m tester
USER tester
ENV QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR=/tmp/runtime-tester
