#!/bin/zsh
set -u

ROOT="${KRALI_REPO_ROOT:-$HOME/Developer/KRALI-Agent}"
TRACE_SOURCE="$HOME/Library/Application Support/KRALI Agent/Mentor/latest.json"
HISTORY_SOURCE="$HOME/Library/Application Support/KRALI Agent/Mentor/History"
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
DEVELOPER_LOG_SOURCE="$HOME/Library/Logs/KRALI-Developer-Agent.log"
SEMANTIC_LOG_SOURCE="$HOME/Library/Logs/KRALI-Semantic-Planner.log"
TRACE_DEST="$ROOT/Mentor/latest.json"
HISTORY_DEST="$ROOT/Mentor/History"
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

if [ -d "$HISTORY_SOURCE" ]; then
    mkdir -p "$HISTORY_DEST"
    rm -f "$HISTORY_DEST"/*.json(N)
    cp "$HISTORY_SOURCE"/*.json(N) "$HISTORY_DEST"/ 2>/dev/null || true
    FILES+=("Mentor/History")
fi

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
