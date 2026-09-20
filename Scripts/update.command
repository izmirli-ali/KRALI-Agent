#!/bin/zsh
set -u

ROOT="$HOME/Developer/KRALI-Agent"
TARGET="/Applications/KRALI Agent.app"
LOG="$HOME/Library/Logs/KRALI-Agent-Updater.log"
STATE_DIR="$HOME/Library/Application Support/KRALI Agent"
FAILURE_MARKER="$STATE_DIR/update-failure.txt"

cd "$ROOT"

reopen_existing_app() {
    if [ -d "$TARGET" ]; then
        echo ""
        echo "↩️ Güncelleme tamamlanamadı; mevcut KRALİ yeniden açılıyor..."
        /usr/bin/open -n "$TARGET" >/dev/null 2>&1 || true
    fi
}

record_failure() {
    local message="$1"
    local version="unknown"

    if [ -f "$ROOT/VERSION" ]; then
        version="$(tr -d '[:space:]' < "$ROOT/VERSION")"
    fi

    mkdir -p "$STATE_DIR"
    printf '%s|%s\n' "$version" "$message" > "$FAILURE_MARKER"
}

fail() {
    local code="$1"
    local message="$2"
    echo ""
    echo "❌ $message"
    record_failure "$message"
    reopen_existing_app
    exit "$code"
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " KRALİ UPDATE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if git remote get-url origin >/dev/null 2>&1; then
    echo "Kaynak güncellemeleri kontrol ediliyor..."
    git pull --ff-only || fail 10 "GitHub güncellemesi alınamadı."
else
    echo "ℹ️ Henüz GitHub remote bağlı değil."
fi

/bin/zsh "$ROOT/Scripts/build-install.command" || fail $? "Build / kurulum tamamlanamadı."

rm -f "$FAILURE_MARKER"
