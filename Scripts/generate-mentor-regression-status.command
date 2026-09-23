#!/bin/zsh
set -u

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
VERSION_FILE="$ROOT/VERSION"

if [ ! -f "$VERSION_FILE" ]; then
    echo "generate-mentor-regression-status: VERSION not found at $VERSION_FILE" >&2
    exit 1
fi

CURRENT_APP_VERSION="$(/usr/bin/tr -d '[:space:]' < "$VERSION_FILE")"

if [ -z "$CURRENT_APP_VERSION" ]; then
    echo "generate-mentor-regression-status: VERSION file is empty" >&2
    exit 1
fi

json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}

extract_app_version() {
    local file="$1"
    /usr/bin/grep -o '"appVersion"[[:space:]]*:[[:space:]]*"[^"]*"' "$file" 2>/dev/null |
        /usr/bin/head -n 1 |
        /usr/bin/sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/'
}

ALL_CURRENT=true

resolve_suite() {
    local abs_path="$1"
    local found

    if [ ! -f "$abs_path" ]; then
        SUITE_STATUS="missing"
        SUITE_STALE="true"
        SUITE_VERSION_JSON="null"
        return
    fi

    found="$(extract_app_version "$abs_path")"

    if [ -z "$found" ]; then
        SUITE_STATUS="unreadable"
        SUITE_STALE="true"
        SUITE_VERSION_JSON="null"
        return
    fi

    if [ "$found" = "$CURRENT_APP_VERSION" ]; then
        SUITE_STATUS="ok"
        SUITE_STALE="false"
    else
        SUITE_STATUS="stale"
        SUITE_STALE="true"
    fi

    SUITE_VERSION_JSON="\"$(json_escape "$found")\""
}

build_suite_json() {
    local rel_path="$1"

    printf '{"appVersion":%s,"status":"%s","stale":%s,"sourceFile":"%s"}' \
        "$SUITE_VERSION_JSON" "$SUITE_STATUS" "$SUITE_STALE" "$(json_escape "$rel_path")"
}

resolve_suite "$ROOT/Mentor/training-latest.json"
TRAINING_JSON="$(build_suite_json Mentor/training-latest.json)"
[ "$SUITE_STATUS" != "ok" ] && ALL_CURRENT=false

resolve_suite "$ROOT/Mentor/arena-latest.json"
ARENA_JSON="$(build_suite_json Mentor/arena-latest.json)"
[ "$SUITE_STATUS" != "ok" ] && ALL_CURRENT=false

resolve_suite "$ROOT/Mentor/live-eval-latest.json"
LIVE_EVAL_JSON="$(build_suite_json Mentor/live-eval-latest.json)"
[ "$SUITE_STATUS" != "ok" ] && ALL_CURRENT=false

printf '{"currentAppVersion":"%s","training":%s,"arena":%s,"liveEval":%s,"allCurrent":%s}\n' \
    "$(json_escape "$CURRENT_APP_VERSION")" \
    "$TRAINING_JSON" \
    "$ARENA_JSON" \
    "$LIVE_EVAL_JSON" \
    "$ALL_CURRENT"
