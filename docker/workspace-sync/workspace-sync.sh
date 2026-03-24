#!/bin/bash
# =============================================================================
# OpenClaw Workspace Git Sync
# =============================================================================
# Commits and pushes the workspace to a private git remote.
# Reads config from environment variables (passed by Docker).
# =============================================================================

set -euo pipefail

WORKSPACE_DIR="/workspace"

GIT_WORKSPACE_REPO="${GIT_WORKSPACE_REPO:-}"
GIT_WORKSPACE_REMOTE="${GIT_WORKSPACE_REMOTE:-}"
GIT_WORKSPACE_BRANCH="${GIT_WORKSPACE_BRANCH:-auto}"
GIT_WORKSPACE_TOKEN="${GIT_WORKSPACE_TOKEN:-}"

# -----------------------------------------------------------------------------
# Validate
# -----------------------------------------------------------------------------

if [[ -z "$GIT_WORKSPACE_REPO" ]] && [[ -z "$GIT_WORKSPACE_REMOTE" ]]; then
    echo "[SKIP] Neither GIT_WORKSPACE_REPO nor GIT_WORKSPACE_REMOTE set"
    exit 0
fi

if [[ -n "$GIT_WORKSPACE_REMOTE" ]] && [[ -n "$GIT_WORKSPACE_REPO" ]]; then
    echo "[SKIP] Both GIT_WORKSPACE_REMOTE and GIT_WORKSPACE_REPO are set - please set only one"
    exit 0
fi

if [[ -n "$GIT_WORKSPACE_REPO" ]] && [[ -z "$GIT_WORKSPACE_TOKEN" ]]; then
    echo "[ERROR] GIT_WORKSPACE_TOKEN not set"
    exit 1
fi

if [[ ! -d "$WORKSPACE_DIR" ]]; then
    echo "[SKIP] Workspace directory $WORKSPACE_DIR does not exist"
    exit 0
fi

# -----------------------------------------------------------------------------
# Git setup
# -----------------------------------------------------------------------------

if [[ -n "$GIT_WORKSPACE_REPO" ]]; then
    GIT_WORKSPACE_REMOTE="https://github.com/${GIT_WORKSPACE_REPO}.git"
    export GIT_ASKPASS="/usr/local/bin/git-askpass.sh"
    export GIT_TERMINAL_PROMPT=0
fi

echo "=== OpenClaw Workspace Sync ==="
if [[ -n "$GIT_WORKSPACE_REPO" ]]; then
    echo "Repo: $GIT_WORKSPACE_REPO"
fi
if [[ -n "$GIT_WORKSPACE_REMOTE" ]]; then
    echo "Remote: VARIABLE_HIDDEN_FOR_SECURITY"
fi
echo "Branch: $GIT_WORKSPACE_BRANCH"
echo ""

cd "$WORKSPACE_DIR"

if [[ ! -d ".git" ]]; then
    echo "[...] Initializing git repository..."
    git init -b "$GIT_WORKSPACE_BRANCH" --quiet
fi

if git remote get-url origin &>/dev/null; then
    git remote set-url origin "$GIT_WORKSPACE_REMOTE"
else
    git remote add origin "$GIT_WORKSPACE_REMOTE"
fi

git config user.name "OpenClaw Bot"
git config user.email "openclaw@noreply.local"

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [[ -n "$CURRENT_BRANCH" && "$CURRENT_BRANCH" != "$GIT_WORKSPACE_BRANCH" ]]; then
    git branch -m "$CURRENT_BRANCH" "$GIT_WORKSPACE_BRANCH" 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# Commit and push
# -----------------------------------------------------------------------------

echo "[...] Checking for changes..."

# Remove nested .git dirs created by OpenClaw's ensureGitRepo() in agent workspaces.
# These break `git add -A` (git treats them as submodule refs without .gitmodules).
find "$WORKSPACE_DIR" -mindepth 2 -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true

git add -A

if git diff --cached --quiet; then
    echo "[SKIP] No changes to sync"
    echo "=== Sync Complete ==="
    exit 0
fi

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
FILE_COUNT=$(git diff --cached --numstat | wc -l | tr -d ' ')

echo "[...] Committing $FILE_COUNT changed file(s)..."
git commit -m "workspace sync $TIMESTAMP" --quiet

echo "[...] Pushing to ${GIT_WORKSPACE_REPO:-remote} ($GIT_WORKSPACE_BRANCH)..."

if git ls-remote --exit-code origin "$GIT_WORKSPACE_BRANCH" &>/dev/null; then
    git pull origin "$GIT_WORKSPACE_BRANCH" --rebase --allow-unrelated-histories --quiet 2>/dev/null || true
fi

git push -u origin "$GIT_WORKSPACE_BRANCH" --quiet 2>&1
echo "[OK] Workspace synced successfully"
echo "=== Sync Complete ==="
