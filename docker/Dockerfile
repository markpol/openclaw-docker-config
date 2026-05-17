###############################################################################
# OpenClaw Gateway – Docker Image
#
# IMPORTANT: Runtime installs are lost on container restart. All binaries
# needed by skills MUST be installed here at build time. If you add a skill
# that needs a new binary, update this Dockerfile and rebuild.
###############################################################################

FROM node:24-bookworm-slim

# Install system dependencies as root
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    chromium \
    ca-certificates \
    gnupg \
    tini \
    jq \
  && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (required by github skill)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update && apt-get install -y --no-install-recommends gh \
  && rm -rf /var/lib/apt/lists/*

# Pin OpenClaw version for reproducible builds — bump explicitly when upgrading
ARG OPENCLAW_VERSION=2026.5.12
RUN npm install -g openclaw@${OPENCLAW_VERSION}

# Install ClawHub and CLI tools for skill/plugin management
RUN npm install -g clawhub pnpm @typescript/native-preview

# === STANDALONE LOBSTER CLI (Required for reliable agent-send / openclaw.invoke) ===
# Cloned from official repo per https://docs.openclaw.ai/tools/lobster
RUN git clone --depth 1 https://github.com/openclaw/lobster.git /opt/lobster \
  && cd /opt/lobster \
  && pnpm install --frozen-lockfile \
  && pnpm run build \
  && ln -s /opt/lobster/bin/lobster.js /usr/local/bin/lobster \
  && ln -s /opt/lobster/bin/lobster.js /usr/local/bin/openclaw.invoke \
  && chown -R node:node /opt/lobster

# Create OpenClaw directories owned by node
RUN mkdir -p /home/node/.openclaw/workspace /.clawhub \
  && chown -R node:node /home/node/.openclaw /.clawhub

# Set permissions for OpenClaw plugin extenstions directory
RUN chown -R node:node /usr/local/lib/node_modules/openclaw/dist/extensions

# Copy skills manifest, workspace templates, and entrypoint
COPY config/skills-manifest.txt /opt/config/skills-manifest.txt
COPY workspace-templates/ /opt/workspace-templates/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

USER node

WORKDIR /home/node/.openclaw

RUN cd /home/node/.openclaw && \
    openclaw plugins install lobster

# Install gh-sub-issue extension for GitHub CLI, used by some PM skills
RUN gh extension install yahsan2/gh-sub-issue

ENTRYPOINT ["tini", "--", "entrypoint.sh"]
