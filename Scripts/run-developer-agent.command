#!/bin/zsh
set -u

ROOT="${KRALI_REPO_ROOT:-$HOME/Developer/KRALI-Agent}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BRANCH="krali-dev-agent/$STAMP"
WORKTREE_BASE="${KRALI_DEV_WORKTREE_BASE:-$HOME/Developer}"
WORKTREE="$WORKTREE_BASE/KRALI-Agent-Dev-$STAMP"
LOG_DIR="$HOME/Library/Logs"
LOG="$LOG_DIR/KRALI-Developer-Agent.log"
STATUS_DIR="$HOME/Library/Application Support/KRALI Agent/Developer"
STATUS="$STATUS_DIR/latest.txt"

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.npm-global/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

mkdir -p "$LOG_DIR" "$STATUS_DIR"

write_status() {
    printf "%s\n" "$1" > "$STATUS"
}

echo "" | tee -a "$LOG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG"
echo " KRALİ DEVELOPER AGENT" | tee -a "$LOG"
echo " $STAMP" | tee -a "$LOG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG"

if [ ! -d "$ROOT/.git" ]; then
    write_status "blocked|KRALİ repo bulunamadı"
    echo "❌ Repo bulunamadı: $ROOT" | tee -a "$LOG"
    exit 10
fi

NPM_BIN="$(command -v npm || true)"
NODE_BIN="$(command -v node || true)"
BREW_BIN="$(command -v brew || true)"

if [ -z "$NPM_BIN" ] || [ -z "$NODE_BIN" ]; then
    if [ -n "$BREW_BIN" ]; then
        write_status "setup_node|Node.js/npm bulunamadı|brew install node"
        echo "❌ Node.js/npm bulunamadı." | tee -a "$LOG"
        echo "Kurulum: brew install node" | tee -a "$LOG"
        exit 11
    fi

    write_status "setup_homebrew|Node.js/npm ve Homebrew bulunamadı|Önce Homebrew, sonra Node.js kurulmalı"
    echo "❌ Node.js/npm ve Homebrew bulunamadı." | tee -a "$LOG"
    echo "Önce Homebrew kurulmalı; ardından: brew install node" | tee -a "$LOG"
    exit 11
fi

NODE_MAJOR="$("$NODE_BIN" -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if [ "$NODE_MAJOR" -lt 20 ]; then
    write_status "setup_node_upgrade|Node.js 20+ gerekiyor|brew upgrade node"
    echo "❌ Node.js sürümü eski: $("$NODE_BIN" -v 2>/dev/null || true)" | tee -a "$LOG"
    echo "Cline için Node.js 20+ gerekiyor (22+ önerilir)." | tee -a "$LOG"
    exit 11
fi

CLINE_BIN="$(command -v cline || true)"
if [ -z "$CLINE_BIN" ]; then
    write_status "setup_cline|Cline CLI bulunamadı|npm install -g cline"
    echo "❌ Cline CLI bulunamadı." | tee -a "$LOG"
    echo "Kurulum: npm install -g cline" | tee -a "$LOG"
    echo "Ardından: cline auth → Sign in with ChatGPT" | tee -a "$LOG"
    exit 11
fi

cd "$ROOT"

if ! git diff --quiet || ! git diff --cached --quiet; then
    write_status "blocked|Ana repo temiz değil"
    echo "❌ Ana repo temiz değil; Developer Agent durduruldu." | tee -a "$LOG"
    exit 12
fi

write_status "preparing|Repo ve worktree hazırlanıyor"

if ! git fetch origin main >>"$LOG" 2>&1; then
    write_status "failed|git fetch başarısız"
    exit 13
fi

if ! git pull --ff-only >>"$LOG" 2>&1; then
    write_status "failed|git pull başarısız"
    exit 14
fi

if ! git worktree add -b "$BRANCH" "$WORKTREE" origin/main >>"$LOG" 2>&1; then
    write_status "failed|worktree oluşturulamadı"
    exit 15
fi

PROMPT_FILE="$WORKTREE/.krali-developer-agent-prompt.txt"
cat > "$PROMPT_FILE" <<'EOF'
Sen KRALİ projesinin Developer Agent'ısın.

Önce şunları oku:
- KRALI_ARCHITECTURE.md
- Mentor/training-latest.json (varsa)
- Mentor/live-eval-latest.json (varsa)
- Mentor/latest.json (varsa)
- VERSION

Amaç:
KRALİ'nin kullanıcının hedeflediği genel yapay zeka/asistan iskeletini güvenilir biçimde geliştirmek.

Değişmez kurallar:
1. Ücretli API, ücretli servis veya yeni abonelik bağımlılığı ekleme.
2. Main branch'e push/merge yapma. Yalnızca bu izole worktree içinde çalış.
3. VERSION, updater, signing kimliği ve bundle/team ayarlarını değiştirme.
4. Mentor JSON dosyalarını değiştirme.
5. İnternetten rastgele kod indirip çalıştırma.
6. Kanıtı olmayan büyük refactor yapma.
7. Training Lab ve Live Research Eval tamamen yeşilse sırf değişiklik yapmak için kod değiştirme.
8. Mentor/latest.json daha eski appVersion'a aitse ve daha yeni Live Eval/Training raporları ilgili problemi geçmiş gösteriyorsa eski hatayı yeniden düzeltme.
9. Bir değişiklik yaparsan önce nedeni açıkça tanımla, minimum dosyayı değiştir ve regression riskini düşük tut.
10. İşin sonunda Scripts/build-check.command çalıştır. Build geçmiyorsa düzeltmeye devam et; geçiremiyorsan durumu açıkça raporla.

Öncelik sırası:
- Gerçek Live Eval başarısızlıkları
- Güncel mentor trace başarısızlıkları
- Training Lab regression'ları
- Açık capability gap'leri
- Son olarak açık ve düşük riskli kalite iyileştirmeleri

KRALİ'nin North Star'ı:
Doğal dili anlayan, araştırabilen, kaynakları doğrulayan, içeriğe göre analiz ve yorum üreten, kullanıcı söylemeden gerekçeli fikirler ekleyebilen, eksik yeteneğini fark edip araştırma/öğrenme planı kurabilen ve araçları güvenli biçimde kullanan genel amaçlı kişisel ajan.

Şimdi mevcut diagnostic'leri incele. Gerekliyse minimum güvenli düzeltmeleri yap; gereksizse kodu değiştirmeden neden değişiklik gerekmediğini raporla.
EOF

write_status "running|Cline Developer Agent çalışıyor"

export CLINE_COMMAND_PERMISSIONS='{"allow":["git status*","git diff*","git log*","git show*","xcodebuild *","xcrun *","swift *","grep *","rg *","find *","cat *","head *","tail *","sed *","ls *"],"deny":["sudo *","rm -rf *","git push*","git reset --hard*","git clean*","open *","osascript *"]}'

PROVIDER="${KRALI_DEV_PROVIDER:-openai-codex}"
MODEL="${KRALI_DEV_MODEL:-}"

CLINE_ARGS=(
    --json
    --auto-approve true
    --provider "$PROVIDER"
    --cwd "$WORKTREE"
    --timeout 1800
)

# Model boş bırakılırsa "cline auth" sırasında bu provider için seçilen model kullanılır.
# Böylece ChatGPT Subscription model seçimi tek yerde yönetilir.
if [ -n "$MODEL" ]; then
    CLINE_ARGS+=(--model "$MODEL")
fi

if ! "$CLINE_BIN" "${CLINE_ARGS[@]}"     "$(cat "$PROMPT_FILE")" >>"$LOG" 2>&1
then
    write_status "failed|Cline görevi başarısız oldu|$BRANCH|$WORKTREE"
    echo "❌ Cline görevi başarısız oldu." | tee -a "$LOG"
    exit 20
fi

rm -f "$PROMPT_FILE"

cd "$WORKTREE"

if [ -z "$(git status --porcelain)" ]; then
    write_status "no_change|Diagnostic yeşil; değişiklik gerekmedi|$BRANCH|$WORKTREE"
    echo "✅ Developer Agent değişiklik gerektirmedi." | tee -a "$LOG"
    exit 0
fi

write_status "verifying|Aday değişiklik build ediliyor|$BRANCH|$WORKTREE"

if ! /bin/zsh "$WORKTREE/Scripts/build-check.command" "$WORKTREE" >>"$LOG" 2>&1; then
    git add -A
    git commit -m "Developer Agent candidate (build failed)" >>"$LOG" 2>&1 || true
    git push -u origin "$BRANCH" >>"$LOG" 2>&1 || true
    write_status "build_failed|Aday değişiklik build geçmedi; branch incelemeye gönderildi|$BRANCH|$WORKTREE"
    echo "❌ Build başarısız; aday branch korundu." | tee -a "$LOG"
    exit 21
fi

git add -A
if ! git commit -m "Developer Agent candidate" >>"$LOG" 2>&1; then
    write_status "failed|Aday değişiklik commit edilemedi|$BRANCH|$WORKTREE"
    exit 22
fi

if ! git push -u origin "$BRANCH" >>"$LOG" 2>&1; then
    write_status "failed|Aday branch GitHub'a gönderilemedi|$BRANCH|$WORKTREE"
    exit 23
fi

write_status "ready_for_review|Build geçti; aday branch Mentor incelemesine hazır|$BRANCH|$WORKTREE"
echo "✅ Developer Agent adayı hazır: $BRANCH" | tee -a "$LOG"
echo "ℹ️ Main branch değiştirilmedi." | tee -a "$LOG"
