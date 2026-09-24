#!/bin/zsh
set -u

ROOT="${KRALI_REPO_ROOT:-$HOME/Developer/KRALI-Agent}"
STATE_DIR="$HOME/Library/Application Support/KRALI Agent"
TRACE_SOURCE="$STATE_DIR/Mentor/latest.json"
HISTORY_SOURCE="$STATE_DIR/Mentor/History"
TRAINING_SOURCE="$STATE_DIR/Mentor/training-latest.json"
LIVE_EVAL_SOURCE="$STATE_DIR/Mentor/live-eval-latest.json"
ARENA_SOURCE="$STATE_DIR/Mentor/arena-latest.json"
ARENA_PROGRESS_SOURCE="$STATE_DIR/Mentor/arena-progress.txt"
SCREEN_SOURCE="$STATE_DIR/Mentor/screen-perception-latest.json"
SCREEN_STATUS_SOURCE="$STATE_DIR/Mentor/screen-perception-status.txt"
DESKTOP_SOURCE="$STATE_DIR/Mentor/desktop-control-latest.json"
DESKTOP_STATUS_SOURCE="$STATE_DIR/Mentor/desktop-control-status.txt"
RESOLUTION_TRACE_SOURCE="$STATE_DIR/Mentor/application-resolution-latest.json"
DEVELOPER_STATUS_SOURCE="$STATE_DIR/Developer/latest.txt"
CURSOR_ARCHITECT_SOURCE="$STATE_DIR/Mentor/cursor-architect-latest.json"
DEVELOPER_RUN_LOG_DIR="$HOME/Library/Logs/KRALI-Developer-Agent-Runs"
DEVELOPER_LOG_POINTER="$STATE_DIR/Developer/active-run-log.txt"
DEVELOPER_LOG_SOURCE="$HOME/Library/Logs/KRALI-Developer-Agent.log"
SEMANTIC_LOG_SOURCE="$HOME/Library/Logs/KRALI-Semantic-Planner.log"
REGRESSION_STATUS_SCRIPT="$ROOT/Scripts/generate-mentor-regression-status.command"

SYNC_BRANCH="${KRALI_MENTOR_BRANCH:-mentor/diagnostics}"
SYNC_WORKTREE="$STATE_DIR/MentorSyncWorktree"

cleanup_worktree() {
    if [ -d "$SYNC_WORKTREE" ]; then
        git -C "$ROOT" worktree remove --force "$SYNC_WORKTREE" >/dev/null 2>&1 ||             /bin/rm -rf "$SYNC_WORKTREE"
    fi
    git -C "$ROOT" worktree prune >/dev/null 2>&1 || true
}

trap cleanup_worktree EXIT

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " KRALİ MENTOR SYNC"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ! -d "$ROOT/.git" ]; then
    echo "❌ KRALİ GitHub çalışma kopyası bulunamadı:"
    echo "$ROOT"
    exit 10
fi

if [ ! -f "$TRACE_SOURCE" ] &&
   [ ! -f "$TRAINING_SOURCE" ] &&
   [ ! -f "$LIVE_EVAL_SOURCE" ] &&
   [ ! -f "$ARENA_SOURCE" ] &&
   [ ! -f "$SCREEN_SOURCE" ] &&
   [ ! -f "$SCREEN_STATUS_SOURCE" ] &&
   [ ! -f "$DESKTOP_SOURCE" ] &&
   [ ! -f "$DESKTOP_STATUS_SOURCE" ] &&
   [ ! -f "$RESOLUTION_TRACE_SOURCE" ]; then
    echo "❌ Gönderilecek Mentor/Training/Live Eval/Arena/Screen raporu yok."
    exit 11
fi

echo "1/5  Diagnostics branch hazırlanıyor..."

BASE_REF="HEAD"

if git -C "$ROOT" ls-remote --exit-code --heads origin "refs/heads/$SYNC_BRANCH" >/dev/null 2>&1; then
    if ! git -C "$ROOT" fetch origin "${SYNC_BRANCH}:refs/remotes/origin/${SYNC_BRANCH}"; then
        echo "❌ Diagnostics branch fetch başarısız."
        exit 12
    fi
    BASE_REF="refs/remotes/origin/$SYNC_BRANCH"
fi

cleanup_worktree

if ! git -C "$ROOT" worktree add --detach "$SYNC_WORKTREE" "$BASE_REF" >/dev/null; then
    echo "❌ Mentor diagnostics worktree oluşturulamadı."
    exit 13
fi

MENTOR_DIR="$SYNC_WORKTREE/Mentor"
mkdir -p "$MENTOR_DIR"

TRACE_DEST="$MENTOR_DIR/latest.json"
TRAINING_DEST="$MENTOR_DIR/training-latest.json"
LIVE_EVAL_DEST="$MENTOR_DIR/live-eval-latest.json"
ARENA_DEST="$MENTOR_DIR/arena-latest.json"
ARENA_PROGRESS_DEST="$MENTOR_DIR/arena-progress.txt"
SCREEN_DEST="$MENTOR_DIR/screen-perception-latest.json"
SCREEN_STATUS_DEST="$MENTOR_DIR/screen-perception-status.txt"
DESKTOP_DEST="$MENTOR_DIR/desktop-control-latest.json"
DESKTOP_STATUS_DEST="$MENTOR_DIR/desktop-control-status.txt"
RESOLUTION_TRACE_DEST="$MENTOR_DIR/application-resolution-latest.json"
DEVELOPER_STATUS_DEST="$MENTOR_DIR/developer-status.txt"
CURSOR_ARCHITECT_DEST="$MENTOR_DIR/cursor-architect-latest.json"
DEVELOPER_LOG_DEST="$MENTOR_DIR/developer-log-tail.txt"
SEMANTIC_LOG_DEST="$MENTOR_DIR/semantic-planner-log-tail.txt"
REGRESSION_STATUS_DEST="$MENTOR_DIR/regression-status.json"

FILES=()

copy_if_present() {
    local source="$1"
    local destination="$2"
    local relative="$3"

    if [ -f "$source" ]; then
        /bin/cp "$source" "$destination"
        FILES+=("$relative")
    fi
}

echo "2/5  Mentor verisi hazırlanıyor..."

copy_if_present "$TRACE_SOURCE" "$TRACE_DEST" "Mentor/latest.json"
copy_if_present "$TRAINING_SOURCE" "$TRAINING_DEST" "Mentor/training-latest.json"
copy_if_present "$LIVE_EVAL_SOURCE" "$LIVE_EVAL_DEST" "Mentor/live-eval-latest.json"
copy_if_present "$ARENA_SOURCE" "$ARENA_DEST" "Mentor/arena-latest.json"
copy_if_present "$ARENA_PROGRESS_SOURCE" "$ARENA_PROGRESS_DEST" "Mentor/arena-progress.txt"
copy_if_present "$SCREEN_SOURCE" "$SCREEN_DEST" "Mentor/screen-perception-latest.json"
copy_if_present "$SCREEN_STATUS_SOURCE" "$SCREEN_STATUS_DEST" "Mentor/screen-perception-status.txt"
copy_if_present "$DESKTOP_SOURCE" "$DESKTOP_DEST" "Mentor/desktop-control-latest.json"
copy_if_present "$DESKTOP_STATUS_SOURCE" "$DESKTOP_STATUS_DEST" "Mentor/desktop-control-status.txt"
copy_if_present "$RESOLUTION_TRACE_SOURCE" "$RESOLUTION_TRACE_DEST" "Mentor/application-resolution-latest.json"
copy_if_present "$DEVELOPER_STATUS_SOURCE" "$DEVELOPER_STATUS_DEST" "Mentor/developer-status.txt"
copy_if_present "$CURSOR_ARCHITECT_SOURCE" "$CURSOR_ARCHITECT_DEST" "Mentor/cursor-architect-latest.json"

if [ -f "$DEVELOPER_STATUS_SOURCE" ]; then
    DEVELOPER_RUN_ID="$(
        /usr/bin/sed -n 's/.*|run=\([^|]*\).*$/\1/p' "$DEVELOPER_STATUS_SOURCE" |
        /usr/bin/tail -n 1
    )"

    if [ -n "$DEVELOPER_RUN_ID" ] &&
       [ -f "$DEVELOPER_RUN_LOG_DIR/$DEVELOPER_RUN_ID.log" ]; then
        DEVELOPER_LOG_SOURCE="$DEVELOPER_RUN_LOG_DIR/$DEVELOPER_RUN_ID.log"
    elif [ -f "$DEVELOPER_LOG_POINTER" ]; then
        POINTER_LOG="$(/bin/cat "$DEVELOPER_LOG_POINTER" 2>/dev/null || true)"
        if [ -n "$POINTER_LOG" ] &&
           [ -f "$POINTER_LOG" ]; then
            DEVELOPER_LOG_SOURCE="$POINTER_LOG"
        fi
    fi
fi

if [ -f "$DEVELOPER_LOG_SOURCE" ]; then
    /usr/bin/tail -n 120 "$DEVELOPER_LOG_SOURCE" > "$DEVELOPER_LOG_DEST"
    FILES+=("Mentor/developer-log-tail.txt")
fi

if [ -f "$SEMANTIC_LOG_SOURCE" ]; then
    /usr/bin/tail -n 120 "$SEMANTIC_LOG_SOURCE" > "$SEMANTIC_LOG_DEST"
    FILES+=("Mentor/semantic-planner-log-tail.txt")
fi

if [ -f "$REGRESSION_STATUS_SCRIPT" ]; then
    REGRESSION_STATUS_TMP="$REGRESSION_STATUS_DEST.tmp.$$"

    if /bin/zsh "$REGRESSION_STATUS_SCRIPT" "$ROOT" > "$REGRESSION_STATUS_TMP"; then
        /bin/mv -f "$REGRESSION_STATUS_TMP" "$REGRESSION_STATUS_DEST"
        FILES+=("Mentor/regression-status.json")
    else
        /bin/rm -f "$REGRESSION_STATUS_TMP"
        echo "⚠️ Mentor/regression-status.json üretilemedi; sync devam ediyor."
    fi
fi

cd "$SYNC_WORKTREE"

if [ -z "$(git status --porcelain -- ${FILES[@]})" ]; then
    echo "✅ Mentor diagnostics zaten güncel."
    exit 0
fi

echo "3/5  Diagnostics commit hazırlanıyor..."
git add -- ${FILES[@]}

if ! git commit -m "Sync KRALI mentor diagnostics" -- ${FILES[@]}; then
    echo "❌ Mentor diagnostics commit edilemedi."
    exit 14
fi

echo "4/5  Diagnostics branch GitHub'a gönderiliyor..."

if ! git push origin "HEAD:refs/heads/$SYNC_BRANCH"; then
    echo "❌ Mentor diagnostics push başarısız."
    exit 15
fi

echo "5/5  Kaynak branch doğrulanıyor..."

SOURCE_HEAD="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || true)"
SOURCE_BRANCH="$(git -C "$ROOT" branch --show-current 2>/dev/null || true)"

echo ""
echo "✅ Mentor diagnostics GitHub'a aktarıldı."
echo "📡 Branch: $SYNC_BRANCH"
echo "🧠 Source branch değişmedi: ${SOURCE_BRANCH:-detached}"
echo "🔒 Source HEAD değişmedi: ${SOURCE_HEAD:-unknown}"

for file in ${FILES[@]}; do
    echo "📄 $file"
done
