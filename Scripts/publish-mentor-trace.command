#!/bin/zsh
set -u

ROOT="${KRALI_REPO_ROOT:-$HOME/Developer/KRALI-Agent}"
SOURCE="$HOME/Library/Application Support/KRALI Agent/Mentor/latest.json"
DEST="$ROOT/Mentor/latest.json"

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

if [ ! -f "$SOURCE" ]; then
    echo "❌ Henüz mentor kaydı yok:"
    echo "$SOURCE"
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
    echo "❌ Git pull başarısız. Mentor kaydı gönderilmedi."
    exit 13
fi

echo "2/4  Mentor kaydı hazırlanıyor..."
mkdir -p "$ROOT/Mentor"
cp "$SOURCE" "$DEST"

if [ -z "$(git status --porcelain -- Mentor/latest.json)" ]; then
    echo "✅ Mentor kaydı zaten güncel."
    exit 0
fi

echo "3/4  Mentor kaydı commit ediliyor..."
git add Mentor/latest.json

if ! git commit --only Mentor/latest.json -m "Sync KRALI mentor trace"; then
    echo "❌ Mentor kaydı commit edilemedi."
    exit 14
fi

echo "4/4  Private GitHub reposuna gönderiliyor..."
if ! git push origin main; then
    echo "❌ Git push başarısız."
    exit 15
fi

echo ""
echo "✅ Mentor kaydı GitHub'a aktarıldı."
echo "📄 Mentor/latest.json"
