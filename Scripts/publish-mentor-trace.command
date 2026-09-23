#!/bin/zsh
set -u

ROOT="${KRALI_REPO_ROOT:-$HOME/Developer/KRALI-Agent}"
TRACE_SOURCE="$HOME/Library/Application Support/KRALI Agent/Mentor/latest.json"
HISTORY_SOURCE="$HOME/Library/Application Support/KRALI Agent/Mentor/History"
# HISTORY_SOURCE is the durable local history. Mentor Sync never writes to
# or deletes it, and individual History JSON files are not mirrored into git.
TRAINING_SOURCE="$HOME/Library/Application Support/KRALI Agent/Mentor/training-latest.json"
LIVE_EVAL_SOURCE="$HOME/Library/Application Support/KRALI Agent/Mentor/live-eval-latest.json"
ARENA_SOURCE="$HOME/Library/Application Support/KRALI Agent/Mentor/arena-latest.json"
ARENA_PROGRESS_SOURCE="$HOME/Library/Application Support/KRALI Agent/Mentor/arena-progress.txt"
SCREEN_SOURCE="$HOME/Library/Application Support/KRALI Agent/Mentor/screen-perception-latest.json"
SCREEN_STATUS_SOURCE="$HOME/Library/Application Support/KRALI Agent/Mentor/screen-perception-status.txt"
DESKTOP_SOURCE="$HOME/Library/Application Support/KRALI Agent/Mentor/desktop-control-latest.json"
DESKTOP_STATUS_SOURCE="$HOME/Library/Application Support/KRALI Agent/Mentor/desktop-control-status.txt"
RESOLUTION_TRACE_SOURCE="$HOME/Library/Application Support/KRALI Agent/Mentor/application-resolution-latest.json"
DEVELOPER_STATUS_SOURCE="$HOME/Library/Application Support/KRALI Agent/Developer/latest.txt"
DEVELOPER_RUN_LOG_DIR="$HOME/Library/Logs/KRALI-Developer-Agent-Runs"
DEVELOPER_LOG_POINTER="$HOME/Library/Application Support/KRALI Agent/Developer/active-run-log.txt"
DEVELOPER_LOG_SOURCE="$HOME/Library/Logs/KRALI-Developer-Agent.log"

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

SEMANTIC_LOG_SOURCE="$HOME/Library/Logs/KRALI-Semantic-Planner.log"
REGRESSION_STATUS_SCRIPT="$ROOT/Scripts/generate-mentor-regression-status.command"
TRACE_DEST="$ROOT/Mentor/latest.json"
TRAINING_DEST="$ROOT/Mentor/training-latest.json"
LIVE_EVAL_DEST="$ROOT/Mentor/live-eval-latest.json"
ARENA_DEST="$ROOT/Mentor/arena-latest.json"
ARENA_PROGRESS_DEST="$ROOT/Mentor/arena-progress.txt"
SCREEN_DEST="$ROOT/Mentor/screen-perception-latest.json"
SCREEN_STATUS_DEST="$ROOT/Mentor/screen-perception-status.txt"
DESKTOP_DEST="$ROOT/Mentor/desktop-control-latest.json"
DESKTOP_STATUS_DEST="$ROOT/Mentor/desktop-control-status.txt"
RESOLUTION_TRACE_DEST="$ROOT/Mentor/application-resolution-latest.json"
DEVELOPER_STATUS_DEST="$ROOT/Mentor/developer-status.txt"
DEVELOPER_LOG_DEST="$ROOT/Mentor/developer-log-tail.txt"
SEMANTIC_LOG_DEST="$ROOT/Mentor/semantic-planner-log-tail.txt"
REGRESSION_STATUS_DEST="$ROOT/Mentor/regression-status.json"

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

if [ ! -f "$TRACE_SOURCE" ] && [ ! -f "$TRAINING_SOURCE" ] && [ ! -f "$LIVE_EVAL_SOURCE" ] && [ ! -f "$ARENA_SOURCE" ] && [ ! -f "$SCREEN_SOURCE" ] && [ ! -f "$SCREEN_STATUS_SOURCE" ] && [ ! -f "$DESKTOP_SOURCE" ] && [ ! -f "$DESKTOP_STATUS_SOURCE" ] && [ ! -f "$RESOLUTION_TRACE_SOURCE" ]; then
    echo "❌ Gönderilecek mentor trace, Training Lab, Live Research Eval, Arena veya Screen Perception raporu yok."
    exit 11
fi

cd "$ROOT"

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "❌ Repo temiz değil. Mentor senkronu başka değişiklikleri commit etmemek için durduruldu."
    echo "Önce mevcut değişiklikleri tamamla veya temizle."
    exit 12
fi

echo "1/4  Uzak repo güncelleniyor..."
if ! git pull --ff-only; then
    echo "❌ Git pull başarısız. Mentor verisi gönderilmedi."
    exit 13
fi

echo "2/4  Mentor verisi hazırlanıyor..."
mkdir -p "$ROOT/Mentor"

FILES=()

# Local Mentor/History is intentionally not mirrored into the repository.
# See Mentor/History/README.md for the repo-side retention policy.

if [ -f "$TRACE_SOURCE" ]; then
    cp "$TRACE_SOURCE" "$TRACE_DEST"
    FILES+=("Mentor/latest.json")
fi

if [ -f "$TRAINING_SOURCE" ]; then
    cp "$TRAINING_SOURCE" "$TRAINING_DEST"
    FILES+=("Mentor/training-latest.json")
fi

if [ -f "$LIVE_EVAL_SOURCE" ]; then
    cp "$LIVE_EVAL_SOURCE" "$LIVE_EVAL_DEST"
    FILES+=("Mentor/live-eval-latest.json")
fi

if [ -f "$ARENA_SOURCE" ]; then
    cp "$ARENA_SOURCE" "$ARENA_DEST"
    FILES+=("Mentor/arena-latest.json")
fi

if [ -f "$ARENA_PROGRESS_SOURCE" ]; then
    cp "$ARENA_PROGRESS_SOURCE" "$ARENA_PROGRESS_DEST"
    FILES+=("Mentor/arena-progress.txt")
fi

if [ -f "$SCREEN_SOURCE" ]; then
    cp "$SCREEN_SOURCE" "$SCREEN_DEST"
    FILES+=("Mentor/screen-perception-latest.json")
fi

if [ -f "$SCREEN_STATUS_SOURCE" ]; then
    cp "$SCREEN_STATUS_SOURCE" "$SCREEN_STATUS_DEST"
    FILES+=("Mentor/screen-perception-status.txt")
fi

if [ -f "$DESKTOP_SOURCE" ]; then
    cp "$DESKTOP_SOURCE" "$DESKTOP_DEST"
    FILES+=("Mentor/desktop-control-latest.json")
fi

if [ -f "$DESKTOP_STATUS_SOURCE" ]; then
    cp "$DESKTOP_STATUS_SOURCE" "$DESKTOP_STATUS_DEST"
    FILES+=("Mentor/desktop-control-status.txt")
fi

if [ -f "$RESOLUTION_TRACE_SOURCE" ]; then
    cp "$RESOLUTION_TRACE_SOURCE" "$RESOLUTION_TRACE_DEST"
    FILES+=("Mentor/application-resolution-latest.json")
fi

if [ -f "$DEVELOPER_STATUS_SOURCE" ]; then
    cp "$DEVELOPER_STATUS_SOURCE" "$DEVELOPER_STATUS_DEST"
    FILES+=("Mentor/developer-status.txt")
fi

if [ -f "$DEVELOPER_LOG_SOURCE" ]; then
    tail -n 120 "$DEVELOPER_LOG_SOURCE" > "$DEVELOPER_LOG_DEST"
    FILES+=("Mentor/developer-log-tail.txt")
fi

if [ -f "$SEMANTIC_LOG_SOURCE" ]; then
    tail -n 120 "$SEMANTIC_LOG_SOURCE" > "$SEMANTIC_LOG_DEST"
    FILES+=("Mentor/semantic-planner-log-tail.txt")
fi

if [ -f "$REGRESSION_STATUS_SCRIPT" ]; then
    REGRESSION_STATUS_TMP="$REGRESSION_STATUS_DEST.tmp.$"

    if /bin/zsh "$REGRESSION_STATUS_SCRIPT" "$ROOT" > "$REGRESSION_STATUS_TMP"; then
        /bin/mv -f "$REGRESSION_STATUS_TMP" "$REGRESSION_STATUS_DEST"
        FILES+=("Mentor/regression-status.json")

        if ! /usr/bin/grep -q '"allCurrent"[[:space:]]*:[[:space:]]*true' "$REGRESSION_STATUS_DEST"; then
            echo ""
            echo "⚠️  WARNING: Training Lab / Arena / Live Research Eval sonuçlarından en az biri güncel VERSION ile eşleşmiyor veya eksik."
            echo "    Detay: Mentor/regression-status.json"
        fi
    else
        /bin/rm -f "$REGRESSION_STATUS_TMP"
        echo ""
        echo "⚠️  WARNING: Mentor/regression-status.json üretilemedi; mevcut rapora dokunulmadan Mentor sync devam ediyor."
    fi
fi

if [ -z "$(git status --porcelain -- ${FILES[@]})" ]; then
    echo "✅ Mentor verileri zaten güncel."
    exit 0
fi

echo "3/4  Mentor verileri commit ediliyor..."
git add -- ${FILES[@]}

if ! git commit -m "Sync KRALI mentor diagnostics" -- ${FILES[@]}; then
    echo "❌ Mentor verileri commit edilemedi."
    exit 14
fi

echo "4/4  Private GitHub reposuna gönderiliyor..."
if ! git push origin main; then
    echo "❌ Git push başarısız."
    exit 15
fi

echo ""
echo "✅ Mentor verileri GitHub'a aktarıldı."
for file in ${FILES[@]}; do
    echo "📄 $file"
done
