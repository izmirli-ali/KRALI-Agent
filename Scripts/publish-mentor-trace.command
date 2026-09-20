#!/bin/zsh
set -u

ROOT="${KRALI_REPO_ROOT:-$HOME/Developer/KRALI-Agent}"
TRACE_SOURCE="$HOME/Library/Application Support/KRALI Agent/Mentor/latest.json"
TRAINING_SOURCE="$HOME/Library/Application Support/KRALI Agent/Mentor/training-latest.json"
LIVE_EVAL_SOURCE="$HOME/Library/Application Support/KRALI Agent/Mentor/live-eval-latest.json"
ARENA_SOURCE="$HOME/Library/Application Support/KRALI Agent/Mentor/arena-latest.json"
TRACE_DEST="$ROOT/Mentor/latest.json"
TRAINING_DEST="$ROOT/Mentor/training-latest.json"
LIVE_EVAL_DEST="$ROOT/Mentor/live-eval-latest.json"
ARENA_DEST="$ROOT/Mentor/arena-latest.json"

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

if [ ! -f "$TRACE_SOURCE" ] && [ ! -f "$TRAINING_SOURCE" ] && [ ! -f "$LIVE_EVAL_SOURCE" ] && [ ! -f "$ARENA_SOURCE" ]; then
    echo "❌ Gönderilecek mentor trace, Training Lab, Live Research Eval veya Arena raporu yok."
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
