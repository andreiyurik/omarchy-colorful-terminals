# Quickshell on Arch, to run the panel tests against an Omarchy shell tree
# mounted at /omarchy (see tests/omarchy/run). Offscreen: no display needed.
FROM archlinux:latest
RUN pacman -Syu --noconfirm --needed quickshell qt6-svg jq bash util-linux ttf-jetbrains-mono-nerd \
 && pacman -Scc --noconfirm \
 && useradd -m tester
USER tester
ENV QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR=/tmp/runtime-tester
