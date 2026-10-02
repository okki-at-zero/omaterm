# syntax=docker/dockerfile:1
FROM archlinux:latest

COPY arch.packages /tmp/arch.packages

# Update system and install official/Omarchy packages
RUN printf 'Server = https://mirror.omarchy.org/$repo/os/$arch\n' > /etc/pacman.d/mirrorlist && \
    pacman -Sy --needed --noconfirm archlinux-keyring && \
    pacman-key --init && \
    pacman-key --populate archlinux && \
    printf '\n[omarchy]\nSigLevel = Never\nServer = https://pkgs.omarchy.org/edge/$arch\n' >> /etc/pacman.conf && \
    pacman -Sy --needed --noconfirm omarchy-keyring && \
    sed -i 's/^SigLevel = Never$/SigLevel = Optional TrustAll/' /etc/pacman.conf && \
    pacman -Syu --needed --noconfirm $(grep -vE '^[[:space:]]*(#|$)' /tmp/arch.packages) && \
    pacman -Scc --noconfirm

# Create a non-root user with sudoless access
RUN useradd -m -u 1000 -s /bin/bash omaterm && \
    echo "omaterm ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/omaterm && \
    chmod 0440 /etc/sudoers.d/omaterm

USER omaterm
WORKDIR /home/omaterm
ENV SHELL=/bin/bash
# Install omadots
RUN curl -fsSL https://raw.githubusercontent.com/omacom-io/omadots/refs/heads/master/install.sh | bash

# Copy configs and the container-side bins (host/ and dev/ stay out of the image)
COPY --chown=omaterm:omaterm config/ /home/omaterm/.config/
COPY --chown=omaterm:omaterm bin/container/ /home/omaterm/.local/bin/
RUN chmod +x /home/omaterm/.local/bin/*

# Auto-start tmux in .bashrc
RUN cat >> /home/omaterm/.bashrc <<'EOF'

if [[ -z $TMUX ]]; then
  t
fi
EOF

COPY --chown=omaterm:omaterm mise.packages /tmp/mise.packages

# Install AI tooling via mise. The GitHub token is optional: without it mise
# hits the unauthenticated GitHub API, which is rate-limited but usually enough
# for one build.
# Do not bake BuildKit's GPG/keyboxd state into runtime containers.
RUN --mount=type=secret,id=GITHUB_TOKEN,uid=1000,gid=1000 \
    github_token="$(cat /run/secrets/GITHUB_TOKEN 2>/dev/null || true)" && \
    if [ -n "$github_token" ]; then export GITHUB_TOKEN="$github_token" GH_TOKEN="$github_token"; fi && \
    eval "$(mise activate bash)" && \
    mise use -g -y $(grep -vE '^[[:space:]]*(#|$)' /tmp/mise.packages) && \
    (gpgconf --kill all || true) && \
    rm -rf /home/omaterm/.gnupg

ENV PATH="/home/omaterm/.local/share/mise/shims:/home/omaterm/.local/bin:${PATH}"

USER root
ENTRYPOINT ["/home/omaterm/.local/bin/omaterm-entrypoint"]
