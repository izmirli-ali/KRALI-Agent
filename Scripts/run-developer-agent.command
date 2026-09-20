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
LOCAL_MENTOR_DIR="$HOME/Library/Application Support/KRALI Agent/Mentor"

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
if [ -n "$CLINE_BIN" ]; then
    echo "Cline version: $("$CLINE_BIN" --version 2>&1 || true)" | tee -a "$LOG"
    echo "Cline doctor:" | tee -a "$LOG"
    "$CLINE_BIN" doctor >>"$LOG" 2>&1 || true
fi

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

write_status "checking|Training Lab, Live Eval ve mentor trace karşılaştırılıyor"

DIAGNOSTIC_DECISION="$("$NODE_BIN" - "$ROOT" "$LOCAL_MENTOR_DIR" <<'NODE'
const fs = require("fs");
const path = require("path");

const root = process.argv[2];
const localMentor = process.argv[3];

function readJSON(file) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return null;
  }
}

function readText(file) {
  try {
    return fs.readFileSync(file, "utf8").trim();
  } catch {
    return "";
  }
}

const version = readText(path.join(root, "VERSION"));
const training = readJSON(path.join(localMentor, "training-latest.json"));
const live = readJSON(path.join(localMentor, "live-eval-latest.json"));
const arena = readJSON(path.join(localMentor, "arena-latest.json"));
const mentor = readJSON(path.join(localMentor, "latest.json"));

const trainingGreen =
  training &&
  training.appVersion === version &&
  Number(training.failed || 0) === 0 &&
  Number(training.passed || 0) === Number(training.total || -1);

const liveGreen =
  live &&
  live.appVersion === version &&
  Number(live.failed || 0) === 0 &&
  Number(live.passed || 0) === Number(live.total || -1);

const arenaGreen =
  arena &&
  arena.appVersion === version &&
  Number(arena.failed || 0) === 0 &&
  Number(arena.passed || 0) === Number(arena.total || -1) &&
  Number(arena.reviewerFlagged || 0) === 0;

const mentorCurrent = mentor && mentor.appVersion === version;
const mentorNeedsAttention =
  mentorCurrent &&
  !["passed", "skipped"].includes(String(mentor.verificationState || ""));

const mentorHasCapabilityGap =
  mentorCurrent &&
  Array.isArray(mentor.capabilityGaps) &&
  mentor.capabilityGaps.length > 0;

if (
  trainingGreen &&
  liveGreen &&
  arenaGreen &&
  !mentorNeedsAttention &&
  !mentorHasCapabilityGap
) {
  process.stdout.write("green");
} else {
  process.stdout.write("run");
}
NODE
)"

if [ "$DIAGNOSTIC_DECISION" = "green" ]; then
    write_status "no_change|Training Lab, Live Research Eval ve Arena güncel sürümde yeşil; Developer Agent çalıştırılmadı"
    echo "✅ Güncel diagnostic'ler yeşil. Cline çağrısı gereksiz olduğu için atlandı." | tee -a "$LOG"
    exit 0
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
- Mentor/arena-latest.json (varsa)
- VERSION
- Yerel güncel diagnostic'ler için gerekirse shell ile şu dosyaları da oku:
  ~/Library/Application Support/KRALI Agent/Mentor/training-latest.json
  ~/Library/Application Support/KRALI Agent/Mentor/live-eval-latest.json
  ~/Library/Application Support/KRALI Agent/Mentor/latest.json
  ~/Library/Application Support/KRALI Agent/Mentor/arena-latest.json

Amaç:
KRALİ'nin kullanıcının hedeflediği genel yapay zeka/asistan iskeletini güvenilir biçimde geliştirmek.

Değişmez kurallar:
1. Ücretli API, ücretli servis veya yeni abonelik bağımlılığı ekleme.
2. Main branch'e push/merge yapma. Yalnızca bu izole worktree içinde çalış.
3. VERSION, updater, signing kimliği ve bundle/team ayarlarını değiştirme.
4. Mentor JSON dosyalarını değiştirme.
5. İnternetten rastgele kod indirip çalıştırma.
6. Kanıtı olmayan büyük refactor yapma.
7. Training Lab, Live Research Eval ve KRALİ Arena tamamen yeşilse sırf değişiklik yapmak için kod değiştirme.
8. Mentor/latest.json daha eski appVersion'a aitse ve daha yeni Live Eval/Training raporları ilgili problemi geçmiş gösteriyorsa eski hatayı yeniden düzeltme.
9. Bir değişiklik yaparsan önce nedeni açıkça tanımla, minimum dosyayı değiştir ve regression riskini düşük tut.
10. İşin sonunda Scripts/build-check.command çalıştır. Build geçmiyorsa düzeltmeye devam et; geçiremiyorsan durumu açıkça raporla.

Öncelik sırası:
- Mentor/latest.json içindeki capabilityGaps ve her gap'in developerBrief alanı
- KRALİ Arena açık-dünya semantic planning / reviewer başarısızlıkları
- Gerçek Live Eval başarısızlıkları
- Güncel mentor trace başarısızlıkları
- Training Lab regression'ları
- Son olarak açık ve düşük riskli kalite iyileştirmeleri

Capability Gap kuralları:
- capabilityGaps boş değilse, testler yeşil olsa bile gap'i "değişiklik gerekmedi" diye atlama.
- Önce candidateCapabilityIDs ile mevcut generic strategy gerçekten yeterli mi değerlendir.
- Strategy yeterliyse yeni provider yazmadan generic recipe/strategy geliştir.
- Yeni kod gerekiyorsa developerBrief kabul kriterlerini esas al.
- Tek uygulama/marka/örneğe özel hard-code yazma.
- Main branch'e merge/push yapma; yalnız candidate branch/worktree.

Arena ilkeleri:
- arena-latest.json içindeki deterministic diagnostic ile AI Reviewer görüşünü ayır.
- Tek bir prompt kalıbına özel patch yazma; failure cluster'ın kök nedenini düzelt.
- Reviewer görüşü deterministic sözleşmeyle çelişiyorsa güvenlik ve gerçek capability durumunu esas al.
- Capability bağlı değilse mission'dan silme; blocked/partial olarak dürüstçe taşı.
- Candidate değişiklik yeni hardcoded marka/isim/tek cümle özel-case'i eklememeli.

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
    --thinking medium
    --retries 2
    --timeout 900
)

# Model boş bırakılırsa "cline auth" sırasında bu provider için seçilen model kullanılır.
# Böylece ChatGPT Subscription model seçimi tek yerde yönetilir.
if [ -n "$MODEL" ]; then
    CLINE_ARGS+=(--model "$MODEL")
fi

if ! "$CLINE_BIN" "${CLINE_ARGS[@]}"     "$(cat "$PROMPT_FILE")" >>"$LOG" 2>&1
then
    write_status "failed|Cline görevi başarısız oldu; Mentor developer-log-tail.txt ayrıntısını incele|$BRANCH|$WORKTREE"
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
