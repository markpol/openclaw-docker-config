#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_PARENT_ROOT="$(cd "$REPO_ROOT/.." && pwd)"

cd "$REPO_ROOT"

usage() {
    echo "Usage: $0 [tag] [service]"
    echo ""
    echo "tag:     Optional image tag. Defaults to latest."
    echo "service: Optional service selector. One of: all, gateway, workspace-sync, hubproxy, regulator"
}

is_service() {
    case "$1" in
        all|gateway|workspace-sync|hubproxy|regulator)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

TAG="latest"
SERVICE="all"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ -n "${1:-}" ]]; then
    if is_service "$1"; then
        SERVICE="$1"
    else
        TAG="$1"
    fi
fi

if [[ -n "${2:-}" ]]; then
    if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        usage
        exit 0
    fi

    if is_service "$2"; then
        SERVICE="$2"
    else
        echo "ERROR: Unknown service '$2'"
        echo ""
        usage
        exit 1
    fi
fi


# GHCR_USERNAME must be set
if [[ -z "${GHCR_USERNAME:-}" ]]; then
    echo "ERROR: GHCR_USERNAME environment variable is not set"
    echo "Set it in docker/.env or your shell profile"
    exit 1
fi

GHCR_PREFIX="ghcr.io/${GHCR_USERNAME}/openclaw-docker-config"
SHA=$(git -C "$REPO_ROOT" rev-parse --short HEAD)

echo "==> Validating config ..."
"$REPO_ROOT/scripts/validate-config.sh"
echo ""
"$REPO_ROOT/scripts/check-secrets.sh"
echo ""

# --- Gateway image ---
GW_IMAGE="$GHCR_PREFIX/openclaw-gateway"
if [[ "$SERVICE" == "all" || "$SERVICE" == "gateway" ]]; then
    echo "==> Building gateway image ..."
    echo "    Image: $GW_IMAGE"
    echo "    Tags:  $TAG, $SHA"
    echo ""

    docker buildx build --platform linux/amd64 -f "$REPO_ROOT/docker/Dockerfile" -t "$GW_IMAGE:$TAG" -t "$GW_IMAGE:$SHA" --push "$REPO_ROOT"

    echo ""
    echo "✓ Built and pushed $GW_IMAGE:$TAG (linux/amd64)"
    echo "✓ Built and pushed $GW_IMAGE:$SHA (linux/amd64)"
fi

# --- Workspace-sync image ---
WS_IMAGE="$GHCR_PREFIX/workspace-sync"
if [[ "$SERVICE" == "all" || "$SERVICE" == "workspace-sync" ]]; then
    echo ""
    echo "==> Building workspace-sync image ..."
    echo "    Image: $WS_IMAGE"
    echo "    Tags:  $TAG, $SHA"
    echo "    Dockerfile: $REPO_ROOT/docker/workspace-sync/Dockerfile"
    echo ""

    docker buildx build --platform linux/amd64 -f "$REPO_ROOT/docker/workspace-sync/Dockerfile" -t "$WS_IMAGE:$TAG" -t "$WS_IMAGE:$SHA" --push "$REPO_ROOT/docker/workspace-sync"

    echo ""
    echo "✓ Built and pushed $WS_IMAGE:$TAG (linux/amd64)"
    echo "✓ Built and pushed $WS_IMAGE:$SHA (linux/amd64)"
fi

# --- Hubproxy image ---
HP_IMAGE="$GHCR_PREFIX/hubproxy"
if [[ "$SERVICE" == "all" || "$SERVICE" == "hubproxy" ]]; then
    echo ""
    echo "==> Building hubproxy image ..."
    echo "    Image: $HP_IMAGE"
    echo "    Tags:  $TAG, $SHA"
    echo "    Dockerfile: $REPO_PARENT_ROOT/hubproxy/Dockerfile"
    echo ""

    cd "$REPO_PARENT_ROOT/hubproxy"
    docker buildx build --platform linux/amd64 -f Dockerfile -t "$HP_IMAGE:$TAG" -t "$HP_IMAGE:$SHA" --push "$REPO_PARENT_ROOT/hubproxy"

    echo ""
    echo "✓ Built and pushed $HP_IMAGE:$TAG (linux/amd64)"
    echo "✓ Built and pushed $HP_IMAGE:$SHA (linux/amd64)"
fi

# --- Regulator image ---
REG_IMAGE="$GHCR_PREFIX/regulator"
if [[ "$SERVICE" == "all" || "$SERVICE" == "regulator" ]]; then
    echo ""
    echo "==> Building regulator image ..."
    echo "    Image: $REG_IMAGE"
    echo "    Tags:  $TAG, $SHA"
    echo "    Dockerfile: $REPO_PARENT_ROOT/openclaw-hubproxy-event-regulator/Dockerfile"
    echo ""

    cd "$REPO_PARENT_ROOT/openclaw-hubproxy-event-regulator"
    docker buildx build --platform linux/amd64 -f Dockerfile -t "$REG_IMAGE:$TAG" -t "$REG_IMAGE:$SHA" --push "$REPO_PARENT_ROOT/openclaw-hubproxy-event-regulator"

    echo ""
    echo "✓ Built and pushed $REG_IMAGE:$TAG (linux/amd64)"
    echo "✓ Built and pushed $REG_IMAGE:$SHA (linux/amd64)"
fi
