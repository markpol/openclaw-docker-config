#!/bin/bash
set -euo pipefail

# If repo is not configured, idle forever (don't restart-loop)
if [[ -z "${GIT_WORKSPACE_REPO:-}" ]] && [[ -z "${GIT_WORKSPACE_REMOTE:-}" ]]; then
    echo "[workspace-sync] GIT_WORKSPACE_REPO and GIT_WORKSPACE_REMOTE not set — idling"
    exec sleep infinity
fi

# Volume is owned by host user (UID 1000), container runs as root
git config --global --add safe.directory /workspace

SCHEDULE="${GIT_WORKSPACE_SYNC_SCHEDULE:-0 4 * * *}"

if [[ -n "$GIT_WORKSPACE_REPO" ]]; then
    echo "[workspace-sync] Repo: $GIT_WORKSPACE_REPO"
fi
if [[ -n "$GIT_WORKSPACE_REMOTE" ]]; then
    echo "[workspace-sync] Remote: VARIABLE_HIDDEN_FOR_SECURITY"
fi
echo "[workspace-sync] Branch: ${GIT_WORKSPACE_BRANCH:-auto}"
echo "[workspace-sync] Schedule: $SCHEDULE"
echo ""

# Run initial sync to verify credentials
echo "[workspace-sync] Running initial sync..."
/usr/local/bin/workspace-sync.sh
echo ""

# Set up cron — pass env vars through to the cron job
# Save env in a file that can be safely sourced
export -p > /tmp/env.sh
chmod 600 /tmp/env.sh

cat > /usr/local/bin/run-sync.sh << 'WRAPPER'
#!/bin/bash
. /tmp/env.sh
exec /usr/local/bin/workspace-sync.sh
WRAPPER
chmod +x /usr/local/bin/run-sync.sh

echo "$SCHEDULE /usr/local/bin/run-sync.sh >> /proc/1/fd/1 2>> /proc/1/fd/2" > /etc/crontabs/root

echo "[workspace-sync] Cron configured, starting scheduler..."
exec crond -f -l 2
