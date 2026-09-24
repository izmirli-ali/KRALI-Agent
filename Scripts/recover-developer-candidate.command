#!/bin/zsh
set -u

ROOT="${KRALI_REPO_ROOT:-$HOME/Developer/KRALI-Agent}"
STATUS="$HOME/Library/Application Support/KRALI Agent/Developer/latest.txt"
LOG="$HOME/Library/Logs/KRALI-Developer-Agent-Recovery.log"
STATUS_DIR="$(dirname "$STATUS")"
NODE_BIN="${KRALI_NODE_BIN:-$(command -v node || true)}"
REPAIR_MODEL="${KRALI_RECOVERY_MODEL:-}"
DEV_TASK_FILE="${KRALI_DEV_TASK_FILE:-}"
LEARNING_PATH="${KRALI_LEARNING_PATH:-integration}"
MAX_REPAIR_ATTEMPTS="${KRALI_CANDIDATE_REPAIR_ATTEMPTS:-2}"
SURFACE_GUARD_FAILED=0

mkdir -p "$STATUS_DIR"
mkdir -p "$(dirname "$LOG")"

write_status() {
    APP_VERSION="$(
        /bin/cat "$ROOT/VERSION" 2>/dev/null |
        /usr/bin/tr -d '[:space:]'
    )"
    NOW_EPOCH="$(/bin/date +%s)"

    printf "%s|@meta|app=%s|at=%s|run=%s\n" \
        "$1" \
        "${APP_VERSION:-unknown}" \
        "$NOW_EPOCH" \
        "${RUN_ID:-recovery}" > "$STATUS"
}

if [ ! -f "$STATUS" ]; then
    exit 0
fi

RAW="$(/bin/cat "$STATUS" 2>/dev/null || true)"
BASE="${RAW%%|@meta*}"

STATE="$(printf '%s' "$BASE" | /usr/bin/awk -F'|' '{print $1}')"
MESSAGE="$(printf '%s' "$BASE" | /usr/bin/awk -F'|' '{print $2}')"
BRANCH="$(printf '%s' "$BASE" | /usr/bin/awk -F'|' '{print $3}')"
WORKTREE="$(printf '%s' "$BASE" | /usr/bin/awk -F'|' '{print $4}')"
RUN_ID="$(printf '%s' "$RAW" | /usr/bin/sed -n 's/.*|run=\([^|]*\).*/\1/p')"

if [ -z "$WORKTREE" ] || [ -z "$BRANCH" ]; then
    exit 0
fi

case "$WORKTREE" in
    "$HOME/Developer/KRALI-Agent-Dev-"*) ;;
    *)
        echo "Recovery reddedildi; worktree yolu beklenen alanın dışında: $WORKTREE" >>"$LOG"
        exit 0
        ;;
esac

if [ ! -d "$WORKTREE/.git" ] && [ ! -f "$WORKTREE/.git" ]; then
    exit 0
fi

# Orchestration artifacts must never turn an empty worktree into a fake candidate.
rm -f "$WORKTREE/.krali-developer-agent-prompt.txt"
rm -rf "$WORKTREE/.build-check"

DIRTY="$(git -C "$WORKTREE" status --porcelain --untracked-files=all 2>/dev/null || true)"
if [ -z "$DIRTY" ]; then
    write_status "no_change|Recovery öncesi gerçek kaynak candidate bulunamadı|$BRANCH|$WORKTREE"
    echo "Recovery atlandı; yalnız orchestration artifact'ları vardı." >>"$LOG"
    exit 0
fi

write_status "recovering_candidate|Önceki Developer Agent değişiklikleri güvenli candidate branch'e kurtarılıyor|$BRANCH|$WORKTREE"
echo "=== $(date) ===" >>"$LOG"
echo "Recovering $BRANCH at $WORKTREE" >>"$LOG"

CURRENT_BRANCH="$(git -C "$WORKTREE" branch --show-current 2>/dev/null || true)"
RECOVERY_BASE_COMMIT="$(git -C "$WORKTREE" rev-parse HEAD 2>/dev/null || true)"
if [ -z "$RECOVERY_BASE_COMMIT" ]; then
    write_status "candidate_recovery_failed|Candidate base commit çözülemedi; otomatik kurtarma durduruldu|$BRANCH|$WORKTREE"
    exit 31
fi

if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    echo "Branch uyuşmazlığı: current=$CURRENT_BRANCH expected=$BRANCH" >>"$LOG"
    write_status "candidate_recovery_failed|Candidate worktree branch eşleşmedi; otomatik kurtarma durduruldu|$BRANCH|$WORKTREE"
    exit 31
fi

git -C "$WORKTREE" add -A >>"$LOG" 2>&1 || {
    write_status "candidate_recovery_failed|Candidate değişiklikleri stage edilemedi|$BRANCH|$WORKTREE"
    exit 32
}

if git -C "$WORKTREE" diff --cached --quiet; then
    write_status "no_change|Recovery sonrası anlamlı kaynak değişikliği kalmadı|$BRANCH|$WORKTREE"
    echo "Recovery sonrası yalnız geçici build artifact'ları vardı; candidate sayılmadı." >>"$LOG"
    exit 0
fi

if ! git -C "$WORKTREE" diff --cached --quiet; then
    git -C "$WORKTREE" commit -m "Recovered Developer Agent candidate $RUN_ID" >>"$LOG" 2>&1 || {
        write_status "candidate_recovery_failed|Candidate değişiklikleri commit edilemedi|$BRANCH|$WORKTREE"
        exit 33
    }
fi

if ! git -C "$WORKTREE" push -u origin "$BRANCH" >>"$LOG" 2>&1; then
    write_status "candidate_recovery_failed|Candidate branch GitHub'a yedeklenemedi|$BRANCH|$WORKTREE"
    exit 34
fi

write_status "candidate_recovered|Candidate GitHub'a yedeklendi; build doğrulanıyor|$BRANCH|$WORKTREE"

BUILD_LOG="$STATUS_DIR/candidate-build-$RUN_ID.log"
REPAIR_PROMPT="$STATUS_DIR/candidate-repair-$RUN_ID.txt"

run_candidate_build() {
    rm -f "$BUILD_LOG"
    SURFACE_GUARD_FAILED=0

    if [ -n "$NODE_BIN" ] &&
       [ -x "$NODE_BIN" ] &&
       [ -f "$ROOT/Scripts/developer-candidate-surface-guard.mjs" ]; then
        SURFACE_GUARD_ARGS=(--root "$WORKTREE" --base "$RECOVERY_BASE_COMMIT")
        if [ -n "$DEV_TASK_FILE" ] && [ -f "$DEV_TASK_FILE" ]; then
            SURFACE_GUARD_ARGS+=(--task "$DEV_TASK_FILE")
        fi

        KRALI_LEARNING_PATH="$LEARNING_PATH" \
        KRALI_DEV_TASK_FILE="$DEV_TASK_FILE" \
            "$NODE_BIN" "$ROOT/Scripts/developer-candidate-surface-guard.mjs" \
                "${SURFACE_GUARD_ARGS[@]}" >"$BUILD_LOG" 2>&1
        GUARD_EXIT=$?

        if [ "$GUARD_EXIT" -ne 0 ]; then
            SURFACE_GUARD_FAILED=1
            /bin/cat "$BUILD_LOG" >>"$LOG" 2>/dev/null || true
            echo "⛔ Candidate surface guard reddetti; destructive/API-surface regression repair gerekli." | tee -a "$LOG"
            rm -rf "$WORKTREE/.build-check"
            return "$GUARD_EXIT"
        fi
    fi

    /bin/zsh "$WORKTREE/Scripts/build-check.command" "$WORKTREE" >>"$BUILD_LOG" 2>&1
    BUILD_EXIT=$?

    /bin/cat "$BUILD_LOG" >>"$LOG" 2>/dev/null || true
    rm -rf "$WORKTREE/.build-check"
    return "$BUILD_EXIT"
}

run_task_verification() {
    if [ -z "$DEV_TASK_FILE" ] || [ ! -f "$DEV_TASK_FILE" ]; then
        return 0
    fi

    if [ -z "$NODE_BIN" ] || [ ! -x "$NODE_BIN" ]; then
        echo "Task verification Node runtime bulunamadı." >>"$LOG"
        return 28
    fi

    KRALI_DEV_TASK_FILE="$DEV_TASK_FILE" \
    KRALI_WORKTREE="$WORKTREE" \
        "$NODE_BIN" "$ROOT/Scripts/developer-task-verifier.mjs" >>"$LOG" 2>&1
}

persist_verification_changes() {
    git -C "$WORKTREE" add -A >>"$LOG" 2>&1 || return 1

    if git -C "$WORKTREE" diff --cached --quiet; then
        return 0
    fi

    git -C "$WORKTREE" commit -m "Developer Agent task verification result $RUN_ID" >>"$LOG" 2>&1 || return 1
    git -C "$WORKTREE" push origin "$BRANCH" >>"$LOG" 2>&1 || return 1
}

candidate_diff_context() {
    git -C "$WORKTREE" show --format= --no-ext-diff HEAD -- 2>/dev/null |
        /usr/bin/tail -n 220
}

build_error_context() {
    /bin/cat "$BUILD_LOG" 2>/dev/null |
        /usr/bin/grep -Eai 'candidate_surface_regression|primitive_patch_|api_surface|error:|fatal error:|SwiftCompile.*failed|BUILD FAILED|failed' |
        /usr/bin/tail -n 80
}

run_candidate_repair() {
    ATTEMPT="$1"

    if [ -z "$NODE_BIN" ] ||
       [ ! -x "$NODE_BIN" ] ||
       [ -z "$REPAIR_MODEL" ]; then
        echo "Candidate repair runtime/model hazır değil; otomatik repair atlandı." | tee -a "$LOG"
        return 125
    fi

    DIFF_CONTEXT="$(candidate_diff_context)"
    ERROR_CONTEXT="$(build_error_context)"

    cat >"$REPAIR_PROMPT" <<EOF
Sen KRALİ Candidate Repair Agent'sın.

Amaç:
Build geçmeyen mevcut Developer Agent candidate'ını aynı izole worktree içinde onar.
Orijinal capability gap'i sıfırdan çözmeye çalışma; önce mevcut candidate'ın build hatasını düzelt.
Bu repair turu: $ATTEMPT / $MAX_REPAIR_ATTEMPTS

Güvenlik sözleşmesi:
- Main branch'e dokunma, push/merge yapma.
- VERSION, signing, updater, Mentor JSON veya kullanıcı credential dosyalarını değiştirme.
- Tek uygulama/marka adına hard-code ekleme.
- Compiler/build hatasını susturmak için capability davranışını kaldırma veya doğrulamayı gevşetme.
- Mevcut candidate yanlış bir yaklaşım ise onu düzelt veya geri al; build geçirmek tek başına yeterli amaç değildir.
- Hata özetinde candidate_surface_regression / primitive_patch_* varsa önce kaldırılan mevcut type/API yüzeyini geri yükle; büyük rewrite'ı cilalamaya çalışma.
- Primitive patch görevinde mevcut store/type/function sözleşmesini koru ve yalnız gerekli alan/davranışı cerrahi olarak genişlet.
- Minimum generic değişiklik yap.
- Değişiklikten sonra git_diff ve build_check kullan.
- Gerçek build PASS olmadan tamamlandı deme.

Mevcut candidate commit diff'i:
--- BEGIN CANDIDATE DIFF ---
$DIFF_CONTEXT
--- END CANDIDATE DIFF ---

Son bağımsız build hata özeti:
--- BEGIN BUILD ERRORS ---
$ERROR_CONTEXT
--- END BUILD ERRORS ---

Önce hatalı candidate'ın bulunduğu kaynak bölgesini doğrula. Ardından minimum repair uygula.
EOF

    write_status "candidate_repair_running|Build geçmeyen candidate compiler kanıtıyla onarılıyor • tur=$ATTEMPT/$MAX_REPAIR_ATTEMPTS|$BRANCH|$WORKTREE"
    echo "🔧 Candidate repair turu $ATTEMPT/$MAX_REPAIR_ATTEMPTS başlatılıyor." | tee -a "$LOG"

    KRALI_WORKTREE="$WORKTREE" \
    KRALI_PROMPT_FILE="$REPAIR_PROMPT" \
    KRALI_DEV_MODEL="$REPAIR_MODEL" \
    KRALI_OLLAMA_BASE_URL="${KRALI_OLLAMA_BASE_URL:-http://127.0.0.1:11434}" \
    KRALI_STATUS_FILE="$STATUS" \
    KRALI_BRANCH="$BRANCH" \
    KRALI_GAP_LABEL="Candidate build repair" \
    KRALI_APP_VERSION="$(/bin/cat "$ROOT/VERSION" 2>/dev/null | /usr/bin/tr -d '[:space:]')" \
    KRALI_RUN_ID="$RUN_ID-repair-$ATTEMPT" \
    KRALI_CHECKPOINT_FILE="" \
    KRALI_DEV_TASK_FILE="$DEV_TASK_FILE" \
    KRALI_LEARNING_PATH="$LEARNING_PATH" \
    KRALI_SURFACE_GUARD_BASE="$RECOVERY_BASE_COMMIT" \
    KRALI_REQUIRE_CHANGE="1" \
    KRALI_LOCAL_AGENT_MAX_COMPLETION_REJECTIONS="2" \
    KRALI_LOCAL_AGENT_MAX_STRUCTURED_ACTIONS="5" \
    KRALI_LOCAL_AGENT_MAX_INSPECTIONS="2" \
    KRALI_LOCAL_AGENT_MAX_ITERATIONS="8" \
    KRALI_LOCAL_AGENT_TIMEOUT_MS="180000" \
    KRALI_LOCAL_AGENT_REQUEST_TIMEOUT_MS="60000" \
    KRALI_LOCAL_AGENT_STRUCTURED_TIMEOUT_MS="45000" \
    "$NODE_BIN" "$ROOT/Scripts/ollama-developer-agent.mjs" \
        > >(tee -a "$LOG") \
        2> >(tee -a "$LOG" >&2)

    return $?
}

if run_candidate_build; then
    if ! run_task_verification; then
        rm -f "$BUILD_LOG" "$REPAIR_PROMPT"
        write_status "recovered_candidate_verification_failed|Kurtarılan candidate build geçti ancak görev kartı doğrulama sözleşmesi geçmedi; branch korundu|$BRANCH|$WORKTREE"
        echo "Recovered candidate task verification failed: $BRANCH" >>"$LOG"
        exit 27
    fi

    persist_verification_changes || {
        rm -f "$BUILD_LOG" "$REPAIR_PROMPT"
        write_status "candidate_recovery_failed|Task verification sonucu branch'e kaydedilemedi|$BRANCH|$WORKTREE"
        exit 37
    }

    rm -f "$BUILD_LOG" "$REPAIR_PROMPT"
    write_status "recovered_candidate_ready|Kurtarılan öğrenme adayı build ve task verification contract geçti; incelemeye hazır|$BRANCH|$WORKTREE"
    echo "Recovered candidate build and task verification passed: $BRANCH" >>"$LOG"
    exit 0
fi

echo "⚠️ İlk candidate build başarısız; bounded repair değerlendiriliyor." | tee -a "$LOG"

ATTEMPT=1
while [ "$ATTEMPT" -le "$MAX_REPAIR_ATTEMPTS" ]; do
    if ! run_candidate_repair "$ATTEMPT"; then
        echo "⚠️ Candidate repair agent turu tamamlanamadı: $ATTEMPT" | tee -a "$LOG"
    fi

    rm -rf "$WORKTREE/.build-check"

    if run_candidate_build; then
        git -C "$WORKTREE" add -A >>"$LOG" 2>&1 || true

        if ! git -C "$WORKTREE" diff --cached --quiet; then
            git -C "$WORKTREE" commit -m "Developer Agent candidate repair $ATTEMPT" >>"$LOG" 2>&1 || {
                write_status "candidate_repair_failed|Repair build geçti ancak commit edilemedi|$BRANCH|$WORKTREE"
                rm -f "$BUILD_LOG" "$REPAIR_PROMPT"
                exit 35
            }

            git -C "$WORKTREE" push origin "$BRANCH" >>"$LOG" 2>&1 || {
                write_status "candidate_repair_failed|Repair build geçti ancak branch güncellenemedi|$BRANCH|$WORKTREE"
                rm -f "$BUILD_LOG" "$REPAIR_PROMPT"
                exit 36
            }
        fi

        if ! run_task_verification; then
            rm -f "$BUILD_LOG" "$REPAIR_PROMPT"
            write_status "recovered_candidate_verification_failed|Candidate repair sonrası build geçti ancak görev kartı doğrulama sözleşmesi geçmedi • tur=$ATTEMPT|$BRANCH|$WORKTREE"
            echo "⚠️ Candidate repair build geçti ancak task verification başarısız." | tee -a "$LOG"
            exit 27
        fi

        persist_verification_changes || {
            rm -f "$BUILD_LOG" "$REPAIR_PROMPT"
            write_status "candidate_repair_failed|Task verification sonucu branch'e kaydedilemedi|$BRANCH|$WORKTREE"
            exit 37
        }

        rm -f "$BUILD_LOG" "$REPAIR_PROMPT"
        write_status "recovered_candidate_ready|Candidate repair sonrası build ve task verification contract geçti; insan/evaluator incelemesine hazır • tur=$ATTEMPT|$BRANCH|$WORKTREE"
        echo "✅ Candidate repair build + task verification geçti; main değiştirilmedi: $BRANCH" | tee -a "$LOG"
        exit 0
    fi

    DIRTY_REPAIR="$(git -C "$WORKTREE" status --porcelain --untracked-files=all 2>/dev/null || true)"
    if [ -n "$DIRTY_REPAIR" ]; then
        git -C "$WORKTREE" add -A >>"$LOG" 2>&1 || true

        if ! git -C "$WORKTREE" diff --cached --quiet; then
            git -C "$WORKTREE" commit -m "Developer Agent repair attempt $ATTEMPT (build failed)" >>"$LOG" 2>&1 || true
            git -C "$WORKTREE" push origin "$BRANCH" >>"$LOG" 2>&1 || true
        fi
    fi

    ATTEMPT=$(( ATTEMPT + 1 ))
done

rm -f "$BUILD_LOG" "$REPAIR_PROMPT"
if [ "$SURFACE_GUARD_FAILED" -eq 1 ]; then
    write_status "recovered_candidate_surface_regression|Candidate destructive/API-surface guard geçmedi; branch korundu ve main değiştirilmedi|$BRANCH|$WORKTREE"
    echo "Recovered candidate surface regression remains; branch preserved: $BRANCH" >>"$LOG"
    exit 30
fi
write_status "recovered_candidate_build_failed|Candidate repair sınırı doldu; branch korundu ve main değiştirilmedi|$BRANCH|$WORKTREE"
echo "Recovered candidate repair limit reached; branch preserved: $BRANCH" >>"$LOG"
exit 21
