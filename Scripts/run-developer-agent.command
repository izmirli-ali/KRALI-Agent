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
SKILL_DIR="$HOME/Library/Application Support/KRALI Agent/Skills"
SKILL_CANDIDATE_DIR="$SKILL_DIR/Candidates"
SKILL_LIBRARY_FILE="$SKILL_DIR/skill-library.json"
LEARNING_JOB_FILE="${KRALI_LEARNING_JOB_FILE:-}"

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.npm-global/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

mkdir -p "$LOG_DIR" "$STATUS_DIR" "$SKILL_CANDIDATE_DIR"

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
        "$STAMP" > "$STATUS"
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

case "$NODE_MAJOR" in
    20|22|24)
        ;;
    *)
        if [ -n "$BREW_BIN" ]; then
            write_status "repairing_runtime|Developer Agent için desteklenen Node.js 22 runtime hazırlanıyor"
            echo "⚠️ Global Node.js v$NODE_MAJOR Cline bağımlılıklarıyla uyumlu değil; izole Node 22 runtime hazırlanıyor." | tee -a "$LOG"

            if ! "$BREW_BIN" list node@22 >/dev/null 2>&1; then
                if ! "$BREW_BIN" install node@22 >>"$LOG" 2>&1; then
                    write_status "setup_node_supported|Node.js 22 otomatik kurulamadı; Developer Agent runtime onarımı gerekli"
                    exit 11
                fi
            fi

            NODE22_PREFIX="$("$BREW_BIN" --prefix node@22 2>/dev/null || true)"
            if [ -z "$NODE22_PREFIX" ]; then
                write_status "setup_node_supported|Node.js 22 yolu çözülemedi"
                exit 11
            fi

            export PATH="$NODE22_PREFIX/bin:$PATH"
            rehash 2>/dev/null || true
            NODE_BIN="$(command -v node || true)"
            NPM_BIN="$(command -v npm || true)"
            NODE_MAJOR="$("$NODE_BIN" -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
            echo "✅ Developer Agent runtime: $("$NODE_BIN" -v 2>/dev/null || true)" | tee -a "$LOG"
        else
            write_status "setup_node_supported|Developer Agent için Node.js 20/22/24 gerekiyor"
            exit 11
        fi
        ;;
esac

NODE_RUNTIME_BIN_DIR="$(dirname "$NODE_BIN")"

CLINE_BIN="$(command -v cline || true)"
PROVIDER="${KRALI_DEV_PROVIDER:-ollama}"
MODEL="${KRALI_DEV_MODEL:-}"
LOCAL_AGENT_ENGINE="${KRALI_LOCAL_AGENT_ENGINE:-native-ollama}"
OLLAMA_BASE_URL="${KRALI_OLLAMA_BASE_URL:-http://127.0.0.1:11434}"
CLINE_SETTINGS="${CLINE_PROVIDER_SETTINGS_PATH:-$HOME/.cline/data/settings/providers.json}"
USE_SDK_FALLBACK=0
SDK_HOST="$STATUS_DIR/cline-sdk-host"
NATIVE_CLINE_BINARY=""
TOOL_MODEL_CACHE="$STATUS_DIR/tool-model-cache-v2.txt"
TOOL_MODEL_CACHE_TTL="${KRALI_TOOL_MODEL_CACHE_TTL:-7200}"
CONTROLLER_MODEL_CACHE="$STATUS_DIR/controller-model-cache.txt"
CONTROLLER_MODEL_CACHE_TTL="${KRALI_CONTROLLER_MODEL_CACHE_TTL:-7200}"
CONTROLLER_PROBE_TIMEOUT_MS="${KRALI_CONTROLLER_PROBE_TIMEOUT_MS:-30000}"
MODEL_PROBE_CACHED=0

cline_probe() {
    CLINE_PROBE_OUTPUT=""
    CLINE_PROBE_EXIT=127

    if [ "$PROVIDER" = "ollama" ]; then
        CLINE_PROBE_OUTPUT="local-ollama"
        CLINE_PROBE_EXIT=0
        return 0
    fi

    if [ -n "$CLINE_BIN" ] && [ -x "$CLINE_BIN" ]; then
        CLINE_PROBE_OUTPUT="$("$CLINE_BIN" -V 2>&1)"
        CLINE_PROBE_EXIT=$?
    fi

    if [ "$CLINE_PROBE_EXIT" -eq 0 ] &&
       [ -n "$CLINE_PROBE_OUTPUT" ]; then
        return 0
    fi

    return 1
}

find_native_cline_binary() {
    NPM_ROOT="$("$NPM_BIN" root -g 2>/dev/null || true)"
    CANDIDATES=(
        "$NPM_ROOT/@cline/cli-darwin-arm64/bin/cline"
        "$NPM_ROOT/cline/bin/.cline"
    )

    for candidate in "${CANDIDATES[@]}"; do
        if [ -n "$candidate" ] && [ -f "$candidate" ]; then
            NATIVE_CLINE_BINARY="$candidate"
            return 0
        fi
    done

    return 1
}

diagnose_native_cline_platform() {
    if [ "$CLINE_PROBE_EXIT" -ne 137 ]; then
        return 1
    fi

    if [ "$(/usr/bin/uname -s 2>/dev/null || true)" != "Darwin" ]; then
        return 1
    fi

    if ! find_native_cline_binary; then
        echo "⚠️ Cline SIGKILL/137 alıyor ancak native binary yolu bulunamadı." | tee -a "$LOG"
        return 1
    fi

    echo "Native Cline binary: $NATIVE_CLINE_BINARY" | tee -a "$LOG"
    /usr/bin/file "$NATIVE_CLINE_BINARY" >>"$LOG" 2>&1 || true
    /usr/bin/codesign -dv --verbose=4 "$NATIVE_CLINE_BINARY" >>"$LOG" 2>&1 || true

    SPCTL_OUTPUT="$(/usr/sbin/spctl --assess --type execute "$NATIVE_CLINE_BINARY" 2>&1)"
    SPCTL_EXIT=$?
    echo "spctl exit=$SPCTL_EXIT • $SPCTL_OUTPUT" | tee -a "$LOG"

    # macOS SIGKILL/137 at process start is a platform-level native binary
    # failure. A rejected/invalid spctl result makes that diagnosis explicit.
    if [ "$SPCTL_EXIT" -ne 0 ] ||
       echo "$SPCTL_OUTPUT" | grep -Eqi 'invalid signature|rejected|not notarized|source=no usable signature'; then
        return 0
    fi

    # Even if spctl output changes across macOS versions, immediate 137 on
    # the native binary is not a task/prompt failure. Prefer the Node SDK
    # surface instead of reinstalling the same native artifact forever.
    return 0
}

prepare_sdk_fallback() {
    write_status "sdk_fallback_preparing|ClineCore SDK runtime hazırlanıyor"

    mkdir -p "$SDK_HOST"
    if [ ! -f "$SDK_HOST/package.json" ]; then
        printf '%s\n' '{"private":true,"type":"module"}' > "$SDK_HOST/package.json"
    fi

    if [ ! -d "$SDK_HOST/node_modules/@cline/sdk" ]; then
        echo "Cline SDK kuruluyor: @cline/sdk" | tee -a "$LOG"
        if ! "$NPM_BIN" --prefix "$SDK_HOST" install @cline/sdk@latest >>"$LOG" 2>&1; then
            return 1
        fi
    fi

    return 0
}

model_required_free_gb() {
    case "$1" in
        qwen3-coder:30b) echo 24 ;;
        devstral-small-2:24b) echo 18 ;;
        devstral:24b) echo 18 ;;
        qwen2.5-coder:14b-instruct) echo 12 ;;
        qwen3:8b) echo 8 ;;
        qwen2.5-coder:7b-instruct) echo 7 ;;
        *) echo 10 ;;
    esac
}

available_disk_gb() {
    /bin/df -Pk "$HOME" 2>/dev/null |
    /usr/bin/awk 'NR==2 {printf "%d", $4 / 1024 / 1024}'
}

ensure_ollama_model() {
    local requested_model="$1"

    if "$OLLAMA_BIN" show "$requested_model" >/dev/null 2>&1; then
        return 0
    fi

    local required_gb="$(model_required_free_gb "$requested_model")"
    local free_gb="$(available_disk_gb)"

    if [ -n "$free_gb" ] &&
       [ "$free_gb" -lt "$required_gb" ]; then
        write_status "local_storage_low|Yerel model için disk alanı yetersiz: $requested_model • boş≈${free_gb}GB • gereken≈${required_gb}GB"
        echo "❌ Model indirilmedi; disk alanı korunuyor: $requested_model • boş≈${free_gb}GB" | tee -a "$LOG"
        return 1
    fi

    write_status "local_model_downloading|Yerel model indiriliyor: $requested_model"
    echo "Yerel model indiriliyor: $requested_model" | tee -a "$LOG"

    "$OLLAMA_BIN" pull "$requested_model" >>"$LOG" 2>&1
}

probe_ollama_model() {
    local requested_model="$1"

    write_status "local_tool_probe|Yerel model tool calling doğrulanıyor: $requested_model"
    echo "Yerel tool-call probe: $requested_model" | tee -a "$LOG"

    KRALI_OLLAMA_BASE_URL="$OLLAMA_BASE_URL" \
    KRALI_DEV_MODEL="$requested_model" \
    "$NODE_BIN" "$ROOT/Scripts/ollama-tool-probe.mjs" >>"$LOG" 2>&1
}

probe_controller_model() {
    local requested_model="$1"

    echo "🧪 Structured controller JSON probe: $requested_model" | tee -a "$LOG"

    KRALI_OLLAMA_BASE_URL="$OLLAMA_BASE_URL" \
    KRALI_CONTROLLER_PROBE_MODEL="$requested_model" \
    KRALI_CONTROLLER_PROBE_TIMEOUT_MS="$CONTROLLER_PROBE_TIMEOUT_MS" \
    "$NODE_BIN" "$ROOT/Scripts/ollama-controller-probe.mjs" >>"$LOG" 2>&1
}

remember_controller_model() {
    local proven_model="$1"
    printf "%s|%s\n" "$proven_model" "$(/bin/date +%s)" > "$CONTROLLER_MODEL_CACHE"
}

use_cached_controller_model() {
    [ -f "$CONTROLLER_MODEL_CACHE" ] || return 1

    local raw cached_model cached_at now age
    raw="$(/bin/cat "$CONTROLLER_MODEL_CACHE" 2>/dev/null || true)"
    cached_model="${raw%%|*}"
    cached_at="${raw#*|}"

    case "$cached_at" in
        ''|*[!0-9]*) return 1 ;;
    esac

    now="$(/bin/date +%s)"
    age="$(( now - cached_at ))"

    if [ "$age" -lt 0 ] ||
       [ "$age" -gt "$CONTROLLER_MODEL_CACHE_TTL" ]; then
        return 1
    fi

    if [ -n "$cached_model" ] &&
       "$OLLAMA_BIN" show "$cached_model" >/dev/null 2>&1; then
        echo "⚡ Structured controller cache adayı yeniden ısıtılıyor: $cached_model • yaş=${age}s" | tee -a "$LOG"

        if probe_controller_model "$cached_model"; then
            CONTROLLER_MODEL="$cached_model"
            remember_controller_model "$cached_model"
            echo "✅ Structured controller cache doğrulandı ve sıcak: $CONTROLLER_MODEL" | tee -a "$LOG"
            return 0
        fi

        echo "⚠️ Cached controller probe geçmedi; controller seçimi yeniden yapılacak: $cached_model" | tee -a "$LOG"
        /bin/rm -f "$CONTROLLER_MODEL_CACHE"
    fi

    return 1
}

select_structured_controller_model() {
    CONTROLLER_MODEL=""

    if use_cached_controller_model; then
        return 0
    fi

    local candidates=(
        "qwen2.5-coder:14b-instruct"
        "qwen3:8b"
        "qwen2.5-coder:7b-instruct"
        "$MODEL"
    )

    local seen="|"

    for candidate in "${candidates[@]}"; do
        [ -n "$candidate" ] || continue

        if [[ "$seen" == *"|$candidate|"* ]]; then
            continue
        fi
        seen="${seen}$candidate|"

        if ! "$OLLAMA_BIN" show "$candidate" >/dev/null 2>&1; then
            continue
        fi

        if probe_controller_model "$candidate"; then
            CONTROLLER_MODEL="$candidate"
            remember_controller_model "$candidate"
            echo "✅ Structured controller probe geçti: $CONTROLLER_MODEL" | tee -a "$LOG"
            return 0
        fi

        echo "⚠️ Structured controller probe geçmedi: $candidate" | tee -a "$LOG"
    done

    CONTROLLER_MODEL="$MODEL"
    echo "⚠️ Hızlı JSON controller doğrulanamadı; ana model fallback: $CONTROLLER_MODEL" | tee -a "$LOG"
    return 1
}

remember_tool_model() {
    local proven_model="$1"
    printf "%s|%s\n" "$proven_model" "$(/bin/date +%s)" > "$TOOL_MODEL_CACHE"
}

use_cached_tool_model() {
    [ -f "$TOOL_MODEL_CACHE" ] || return 1

    local raw cached_model cached_at now age
    raw="$(/bin/cat "$TOOL_MODEL_CACHE" 2>/dev/null || true)"
    cached_model="${raw%%|*}"
    cached_at="${raw#*|}"

    case "$cached_at" in
        ''|*[!0-9]*) return 1 ;;
    esac

    now="$(/bin/date +%s)"
    age="$(( now - cached_at ))"

    if [ "$age" -lt 0 ] || [ "$age" -gt "$TOOL_MODEL_CACHE_TTL" ]; then
        return 1
    fi

    if [ -n "$cached_model" ] &&
       "$OLLAMA_BIN" show "$cached_model" >/dev/null 2>&1; then
        MODEL="$cached_model"
        MODEL_PROBE_CACHED=1
        echo "⚡ Tool-capable model cache kullanılıyor: $MODEL • yaş=${age}s" | tee -a "$LOG"
        return 0
    fi

    return 1
}

select_existing_local_model() {
    local candidates=()

    if [ "$MEMORY_GB" -ge 32 ]; then
        candidates=(
            "devstral-small-2:24b"
            "qwen3-coder:30b"
            "devstral:24b"
            "qwen2.5-coder:14b-instruct"
            "qwen3:8b"
            "qwen2.5-coder:7b-instruct"
        )
    elif [ "$MEMORY_GB" -ge 20 ]; then
        candidates=(
            "devstral-small-2:24b"
            "devstral:24b"
            "qwen2.5-coder:14b-instruct"
            "qwen3:8b"
            "qwen2.5-coder:7b-instruct"
        )
    else
        candidates=(
            "qwen2.5-coder:7b-instruct"
            "qwen3:8b"
        )
    fi

    for candidate in "${candidates[@]}"; do
        if "$OLLAMA_BIN" show "$candidate" >/dev/null 2>&1; then
            MODEL="$candidate"
            return 0
        fi
    done

    return 1
}

select_installed_tool_fallback() {
    local current_model="$1"
    local candidates=(
        "devstral-small-2:24b"
        "qwen2.5-coder:14b-instruct"
        "qwen2.5-coder:7b-instruct"
        "qwen3:8b"
        "devstral:24b"
        "qwen3-coder:30b"
    )

    FALLBACK_MODEL=""

    for candidate in "${candidates[@]}"; do
        if [ "$candidate" = "$current_model" ]; then
            continue
        fi

        if "$OLLAMA_BIN" show "$candidate" >/dev/null 2>&1 &&
           probe_ollama_model "$candidate"; then
            FALLBACK_MODEL="$candidate"
            return 0
        fi
    done

    return 1
}

ollama_version_at_least() {
    local minimum="$1"
    local current="$2"

    "$NODE_BIN" - "$minimum" "$current" <<'NODE' >/dev/null 2>&1
const min = String(process.argv[2] || "").split(".").map(Number);
const cur = String(process.argv[3] || "").split(".").map(Number);
for (let i = 0; i < Math.max(min.length, cur.length); i++) {
  const a = Number(cur[i] || 0);
  const b = Number(min[i] || 0);
  if (a > b) process.exit(0);
  if (a < b) process.exit(1);
}
process.exit(0);
NODE
}

ensure_devstral2_runtime_compatibility() {
    if [ "$MODEL" != "devstral-small-2:24b" ] &&
       [ "$MODEL" != "devstral-small-2" ]; then
        return 0
    fi

    local server_version=""
    server_version="$(
        /usr/bin/curl -fsS "$OLLAMA_BASE_URL/api/version" 2>/dev/null |
        "$NODE_BIN" -e '
let s="";
process.stdin.on("data",d=>s+=d);
process.stdin.on("end",()=>{try{process.stdout.write(String(JSON.parse(s).version||""))}catch{}})
' 2>/dev/null || true
    )"

    if [ -n "$server_version" ] &&
       ollama_version_at_least "0.13.3" "$server_version"; then
        return 0
    fi

    write_status "local_ai_upgrade_required|Devstral Small 2 için Ollama 0.13.3+ gerekiyor; mevcut=${server_version:-unknown}"

    if [ -n "$BREW_BIN" ] &&
       "$BREW_BIN" list ollama >/dev/null 2>&1; then
        echo "♻️ Ollama Devstral Small 2 uyumluluğu için güncelleniyor..." | tee -a "$LOG"

        if "$BREW_BIN" upgrade ollama >>"$LOG" 2>&1; then
            /usr/bin/pkill -x ollama >/dev/null 2>&1 || true
            /bin/sleep 1
            rehash 2>/dev/null || true
            OLLAMA_BIN="$(command -v ollama || true)"
            /usr/bin/nohup "$OLLAMA_BIN" serve >>"$LOG_DIR/KRALI-Ollama.log" 2>&1 &

            for _ in {1..30}; do
                if /usr/bin/curl -fsS "$OLLAMA_BASE_URL/api/tags" >/dev/null 2>&1; then
                    break
                fi
                /bin/sleep 1
            done

            server_version="$(
                /usr/bin/curl -fsS "$OLLAMA_BASE_URL/api/version" 2>/dev/null |
                "$NODE_BIN" -e '
let s="";
process.stdin.on("data",d=>s+=d);
process.stdin.on("end",()=>{try{process.stdout.write(String(JSON.parse(s).version||""))}catch{}})
' 2>/dev/null || true
            )"

            if [ -n "$server_version" ] &&
               ollama_version_at_least "0.13.3" "$server_version"; then
                echo "✅ Ollama uyumlu sürüme güncellendi: $server_version" | tee -a "$LOG"
                return 0
            fi
        fi
    fi

    echo "❌ Devstral Small 2 için Ollama 0.13.3+ gerekli; mevcut: ${server_version:-unknown}" | tee -a "$LOG"
    return 1
}

prepare_ollama_runtime() {
    write_status "local_ai_checking|Yerel Developer AI hazırlanıyor"

    OLLAMA_BIN="$(command -v ollama || true)"

    if [ -z "$OLLAMA_BIN" ]; then
        if [ -z "$BREW_BIN" ]; then
            write_status "setup_local_ai|Ollama bulunamadı ve Homebrew ile otomatik kurulum yapılamıyor"
            echo "❌ Yerel AI runtime kurulamadı: Ollama ve Homebrew bulunamadı." | tee -a "$LOG"
            return 1
        fi

        write_status "local_ai_installing|Ücretsiz yerel AI runtime Ollama kuruluyor"
        echo "Ollama kuruluyor..." | tee -a "$LOG"

        if ! "$BREW_BIN" install ollama >>"$LOG" 2>&1; then
            write_status "setup_local_ai|Ollama otomatik kurulamadı"
            return 1
        fi

        rehash 2>/dev/null || true
        OLLAMA_BIN="$(command -v ollama || true)"
    fi

    if [ -z "$OLLAMA_BIN" ]; then
        write_status "setup_local_ai|Ollama binary yolu çözülemedi"
        return 1
    fi

    if ! /usr/bin/curl -fsS "$OLLAMA_BASE_URL/api/tags" >/dev/null 2>&1; then
        write_status "local_ai_starting|Yerel AI servisi başlatılıyor"
        echo "Ollama servisi başlatılıyor..." | tee -a "$LOG"

        /usr/bin/nohup "$OLLAMA_BIN" serve >>"$LOG_DIR/KRALI-Ollama.log" 2>&1 &

        OLLAMA_READY=0
        for _ in {1..30}; do
            if /usr/bin/curl -fsS "$OLLAMA_BASE_URL/api/tags" >/dev/null 2>&1; then
                OLLAMA_READY=1
                break
            fi
            /bin/sleep 1
        done

        if [ "$OLLAMA_READY" -ne 1 ]; then
            write_status "local_ai_failed|Ollama servisi health probe geçmedi"
            return 1
        fi
    fi

    MEMORY_BYTES="$(/usr/sbin/sysctl -n hw.memsize 2>/dev/null || echo 0)"
    MEMORY_GB="$(( MEMORY_BYTES / 1024 / 1024 / 1024 ))"

    if [ -z "$MODEL" ]; then
        if ! use_cached_tool_model; then
            if [ "$MEMORY_GB" -ge 20 ]; then
                # v0.10 architect migration: do not silently keep the legacy
                # Devstral merely because it is already installed. Pull the
                # newer architect model once, then cache only after probe PASS.
                MODEL="devstral-small-2:24b"
            elif ! select_existing_local_model; then
                MODEL="qwen2.5-coder:7b-instruct"
            fi
        fi

        echo "Yerel architect model seçimi: $MODEL • RAM≈${MEMORY_GB}GB" | tee -a "$LOG"
    fi

    if ! ensure_devstral2_runtime_compatibility; then
        write_status "local_ai_failed|Architect model runtime uyumluluğu sağlanamadı: $MODEL"
        return 1
    fi

    if ! ensure_ollama_model "$MODEL"; then
        write_status "local_model_failed|Yerel model hazırlanamadı: $MODEL"
        return 1
    fi

    if [ "$MODEL_PROBE_CACHED" -eq 1 ]; then
        write_status "local_ai_ready|Önceden doğrulanmış yerel Developer AI cache'den hazır: $MODEL"
    elif ! probe_ollama_model "$MODEL"; then
        echo "⚠️ $MODEL native tool-call probe geçmedi; yalnız kurulu alternatifler deneniyor." | tee -a "$LOG"

        if ! select_installed_tool_fallback "$MODEL"; then
            write_status "local_tool_probe_failed|Kurulu yerel modeller native tool-call probe geçemedi"
            return 1
        fi

        MODEL="$FALLBACK_MODEL"
        write_status "local_model_fallback|Kurulu tool-capable yerel modele geçildi: $MODEL"
        remember_tool_model "$MODEL"
    else
        remember_tool_model "$MODEL"
    fi

    write_status "local_ai_ready|Ücretsiz yerel Developer AI hazır ve tool-call doğrulandı: $MODEL"
    echo "✅ Yerel Developer AI hazır + tool-call doğrulandı: $MODEL" | tee -a "$LOG"
    return 0
}

repair_cline() {
    write_status "repairing_cline|Cline CLI sağlığı kontrol ediliyor ve otomatik onarım deneniyor"

    echo "Cline path: ${CLINE_BIN:-bulunamadı}" | tee -a "$LOG"
    echo "Machine arch: $(/usr/bin/uname -m 2>/dev/null || true)" | tee -a "$LOG"

    if [ -n "$CLINE_BIN" ]; then
        /usr/bin/file "$CLINE_BIN" >>"$LOG" 2>&1 || true
        echo "Cline doctor fix deneniyor..." | tee -a "$LOG"
        "$CLINE_BIN" doctor fix >>"$LOG" 2>&1 || true
    fi

    CLINE_BIN="$(command -v cline || true)"
    if cline_probe; then
        echo "✅ Cline doctor fix sonrası sağlıklı: $CLINE_PROBE_OUTPUT" | tee -a "$LOG"
        return 0
    fi

    echo "Cline CLI yeniden kuruluyor: npm install -g --allow-scripts=cline,protobufjs cline@latest" | tee -a "$LOG"
    write_status "repairing_cline|Cline CLI resmi paketle ve gerekli install script izinleriyle yeniden kuruluyor"

    if ! "$NPM_BIN" install -g --allow-scripts=cline,protobufjs cline@latest >>"$LOG" 2>&1; then
        return 1
    fi

    rehash 2>/dev/null || true
    CLINE_BIN="$(command -v cline || true)"

    if cline_probe; then
        echo "✅ Cline yeniden kuruldu: $CLINE_PROBE_OUTPUT" | tee -a "$LOG"
        return 0
    fi

    return 1
}

if ! cline_probe; then
    echo "⚠️ Cline health probe başarısız. exit=$CLINE_PROBE_EXIT output=$CLINE_PROBE_OUTPUT" | tee -a "$LOG"

    if ! repair_cline; then
        if diagnose_native_cline_platform; then
            USE_SDK_FALLBACK=1
            write_status "provider_platform_bug|Cline native CLI macOS tarafından SIGKILL ile engellendi; SDK fallback kullanılacak"
            echo "🧩 Native Cline platform hatası sınıflandırıldı; Node SDK fallback'e geçiliyor." | tee -a "$LOG"
        else
            write_status "setup_cline_repair|Cline CLI otomatik onarılamadı; kurulum logu incelenmeli"
            echo "❌ Cline CLI otomatik onarılamadı." | tee -a "$LOG"
            exit 11
        fi
    fi
fi

if [ "$PROVIDER" = "ollama" ]; then
    if ! prepare_ollama_runtime; then
        exit 11
    fi

    if [ "$LOCAL_AGENT_ENGINE" != "native-ollama" ]; then
        USE_SDK_FALLBACK=1
    fi
elif [ "$USE_SDK_FALLBACK" -eq 0 ]; then
    echo "Cline version: $CLINE_PROBE_OUTPUT" | tee -a "$LOG"
    echo "Cline doctor:" | tee -a "$LOG"
    "$CLINE_BIN" doctor >>"$LOG" 2>&1 || true
fi

if [ "$PROVIDER" = "openai-codex" ]; then
    CLINE_AUTH_STATE="$("$NODE_BIN" - "$CLINE_SETTINGS" "$PROVIDER" <<'NODE'
const fs = require("fs");

const file = process.argv[2];
const providerId = process.argv[3];

function containsReadyProvider(value) {
  if (!value || typeof value !== "object") return false;

  if (
    value.provider === providerId &&
    value.auth &&
    typeof value.auth === "object" &&
    typeof value.auth.accessToken === "string" &&
    value.auth.accessToken.trim().length > 0
  ) {
    return true;
  }

  if (Array.isArray(value)) {
    return value.some(containsReadyProvider);
  }

  return Object.values(value).some(containsReadyProvider);
}

try {
  const parsed = JSON.parse(fs.readFileSync(file, "utf8"));
  process.stdout.write(containsReadyProvider(parsed) ? "ready" : "missing");
} catch {
  process.stdout.write("missing");
}
NODE
)"

    if [ "$CLINE_AUTH_STATE" != "ready" ]; then
        AUTH_SCRIPT="$STATUS_DIR/cline-auth.command"

        cat > "$AUTH_SCRIPT" <<EOF
#!/bin/zsh
export PATH="$NODE_RUNTIME_BIN_DIR:/opt/homebrew/bin:/usr/local/bin:$HOME/.npm-global/bin:/usr/bin:/bin:/usr/sbin:/sbin:\$PATH"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " KRALİ • CLINE GİRİŞİ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "ChatGPT Subscription bağlantısı açılıyor..."
echo "Tarayıcıda hesabınla giriş yap; tamamlanınca KRALİ geliştirmeye otomatik devam edecek."
echo ""

if "$CLINE_BIN" auth openai-codex; then
    printf '%s\n' "auth_ready|Cline OAuth tamamlandı; Developer Agent yeniden başlatılıyor" > "$STATUS"
    echo ""
    echo "✅ Giriş tamamlandı. KRALİ Developer Agent yeniden başlatılıyor..."
    /usr/bin/nohup /bin/zsh "$ROOT/Scripts/run-developer-agent.command" >>"$LOG" 2>&1 &
else
    printf '%s\n' "setup_cline_auth|Cline OAuth tamamlanamadı; tekrar giriş gerekiyor" > "$STATUS"
    echo ""
    echo "❌ Cline girişi tamamlanamadı."
fi
EOF

        /bin/chmod +x "$AUTH_SCRIPT" 2>/dev/null || true
        write_status "waiting_cline_auth|ChatGPT giriş ekranı otomatik açılıyor; girişten sonra Developer Agent devam edecek"

        if /usr/bin/open -a Terminal "$AUTH_SCRIPT" >>"$LOG" 2>&1; then
            echo "🔐 Cline OAuth Terminal penceresi otomatik açıldı." | tee -a "$LOG"
        else
            write_status "setup_cline_auth|Cline OAuth penceresi otomatik açılamadı|cline auth openai-codex"
            echo "❌ Cline OAuth Terminal penceresi açılamadı." | tee -a "$LOG"
        fi

        exit 11
    fi
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

if [ -n "$LEARNING_JOB_FILE" ] &&
   [ -f "$LEARNING_JOB_FILE" ]; then
    DIAGNOSTIC_DECISION="run"
    echo "Learning Queue job brief bulundu; mutable Mentor latest yerine immutable job kullanılacak." | tee -a "$LOG"
fi

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

GAP_SOURCE="$LOCAL_MENTOR_DIR/latest.json"
if [ -n "$LEARNING_JOB_FILE" ] &&
   [ -f "$LEARNING_JOB_FILE" ]; then
    GAP_SOURCE="$LEARNING_JOB_FILE"
fi

GAP_MODE="$("$NODE_BIN" - "$GAP_SOURCE" "$PROMPT_FILE" "$LOCAL_MENTOR_DIR/latest.json" <<'NODE'
const fs = require("fs");

const source = process.argv[2];
const target = process.argv[3];
const mentorPath = process.argv[4];

let payload = null;
try { payload = JSON.parse(fs.readFileSync(source, "utf8")); } catch {}

let currentMentor = null;
try {
  currentMentor = JSON.parse(
    fs.readFileSync(mentorPath, "utf8")
  );
} catch {}

const gap =
  payload && payload.gap
    ? payload.gap
    : (
        payload &&
        Array.isArray(payload.capabilityGaps)
          ? payload.capabilityGaps[0]
          : null
      );

if (!gap) {
  process.stdout.write("full");
  process.exit(0);
}

const candidates =
  Array.isArray(gap.candidateCapabilityIDs) &&
  gap.candidateCapabilityIDs.length > 0
    ? gap.candidateCapabilityIDs.join(", ")
    : "Yok";

const sourceGoals =
  payload && Array.isArray(payload.sourceGoals)
    ? payload.sourceGoals
    : [];

const evidenceCount =
  Number(payload && payload.evidenceCount || sourceGoals.length || 1);

const runtimeEvidence =
  currentMentor &&
  Array.isArray(currentMentor.activityTail) &&
  Array.isArray(currentMentor.capabilityGaps) &&
  currentMentor.capabilityGaps.some(
    (item) =>
      String(item && item.capabilityID || "") ===
      String(gap.capabilityID || "")
  )
    ? currentMentor.activityTail
        .map((item) => String(item && item.text || ""))
        .filter((line) =>
          /başarısız|bulunamadı|runtime capability gap|postcondition|failed|error/i.test(
            line
          )
        )
        .slice(0, 8)
    : [];

const learningPath =
  String(gap.learningPath || "integration");

const learningPathRule =
  learningPath === "primitivePatch"
    ? "- Bu iş DAR PRIMITIVE PATCH'tir: yalnız eksik atomik davranışı ekle; yeni tam uygulama entegrasyonu veya geniş refactor yapma."
    : (
        learningPath === "strategyRecipe"
          ? "- Bu iş STRATEGY RECIPE'tir: önce mevcut capability'leri yeniden kullan; kaynak kod değişikliği gerçekten gerekmiyorsa yeni provider yazma."
          : "- Bu iş TAM ENTEGRASYON olabilir: yine de önce daha küçük generic primitive ile çözülüp çözülemeyeceğini kontrol et."
      );

const prompt = [
  "Sen KRALİ projesinin Developer Agent\'ısın.",
  "",
  "Bu çalışma LIGHTWEIGHT CAPABILITY GAP modudur.",
  "Training/Live/Arena JSON dosyalarını topluca okuma. Önce yalnız bu brief\'i ve ilgili kaynak kodunu incele.",
  "",
  "Capability:",
  String(gap.capabilityID || "unknown") + " — " + String(gap.capabilityName || "unknown"),
  "",
  "Gap türü:", String(gap.kind || "unknown"),
  "",
  "Learning yolu:", learningPath,
  "",
  "Neden:", String(gap.reason || ""),
  "",
  "Araştırma hedefi:", String(gap.researchGoal || ""),
  "",
  "Mevcut strategy adayları:", candidates,
  "",
  "Birleştirilen kanıt sayısı:", String(evidenceCount),
  "",
  "Bu öğrenme işine kanıt sağlayan kullanıcı hedefleri:",
  sourceGoals.length > 0
    ? sourceGoals.map((goal, index) => String(index + 1) + ". " + goal).join("\n")
    : "Tekil diagnostic / Mentor kanıtı",
  "",
  "Developer Brief:", String(gap.developerBrief || ""),
  "",
  "Güncel runtime kanıtı:",
  runtimeEvidence.length > 0
    ? runtimeEvidence.join("\n")
    : "Ek runtime hata satırı yok.",
  "",
  "Kurallar:",
  learningPathRule,
  "- KRALI_ARCHITECTURE.md içindeki Senaryo bağımsızlığı ilkesini değişmez sözleşme kabul et.",
  "- Tek kullanıcı örneğini geçirmek için uygulama/site adına özel branch veya hard-code ekleme; önce semantic parametreleme + mevcut generic primitive bileşimini dene.",
  "- Training/Gym diagnostic içindeki [intent], [scope], [entity], [rank], [output], [safety], [capability] etiketlerini failure class olarak kullan; düzeltmeyi ilgili semantic katmanda yap.",
  "- Metamorphic/Gym ailesinden bir varyasyon fail ise yalnız o promptu geçirmek yeterli değildir; aynı semantic contract ailesini geçirecek generic düzeltme üret.",
  "- Runtime hata metni varsa önce o hata metninin tanımlandığı source'u rg/grep ile bul; orchestrator çağrı noktası yerine provider/resolver/error tanımını önceliklendir.",
  "- Capability kimliğini arıyorsan registry, resolver, executor ve verifier bağlantılarını hedefli aramayla bul; klasörleri tekrar tekrar listeleme.",
  "- Tek uygulama/marka adına özel hard-code yazma; generic provider/strategy tasarla.",
  "- Ücretli API veya yeni abonelik bağımlılığı ekleme.",
  "- Dış dünyaya commit eden aksiyonlarda kullanıcı onayı korunmalı.",
  "- Gerçek observation/evidence olmadan PASS üretme.",
  "- VERSION, updater, signing, bundle/team ve Mentor JSON dosyalarını değiştirme.",
  "- Main\'e push/merge yapma; yalnız bu worktree\'de candidate üret.",
  "- Gereksiz geniş refactor yapma; minimum güvenli değişiklik yap.",
  "- İş sonunda /bin/zsh Scripts/build-check.command çalıştır.",
  "- Aktif gap varken yalnız kodu açıklayıp final cevap verme; açıklama ilerleme sayılmaz.",
  "- Kaynak değişikliği gerekiyorsa replace_text/write_file/apply_patch ile gerçek candidate üret.",
  "- Candidate değişiklikten sonra git_diff incelemesi ve build_check PASS zorunludur.",
  "",
  "Yalnız ihtiyaç duyduğun kaynak dosyalarını oku. Büyük diagnostic JSON\'larını açma."
].join("\n");

fs.writeFileSync(target, prompt, "utf8");
process.stdout.write("gap");
NODE
)"

if [ "$GAP_MODE" = "full" ]; then
cat > "$PROMPT_FILE" <<'EOF'
Sen KRALİ projesinin Developer Agent'ısın.

Önce KRALI_ARCHITECTURE.md, VERSION ve güncel Mentor diagnostic'lerini incele.
Ama yalnız başarısız/attention alanlarla ilgili minimum dosyaları aç; büyük JSON'ları gereksiz yere tekrar tekrar okuma.

Kurallar:
1. Ücretli API, ücretli servis veya yeni abonelik bağımlılığı ekleme.
2. Main branch'e push/merge yapma. Yalnızca bu izole worktree içinde çalış.
3. VERSION, updater, signing kimliği ve bundle/team ayarlarını değiştirme.
4. Mentor JSON dosyalarını değiştirme.
5. Kanıtı olmayan büyük refactor yapma.
6. Tek marka/uygulama/prompt örneğine hard-code yazma; önce semantic parametreleme ve mevcut generic primitive bileşimini kullan.
7. Senaryo için yeni kod yazmadan önce KRALI_ARCHITECTURE.md içindeki Senaryo bağımsızlığı ilkesini uygula.
8. Training/Gym diagnostic içindeki [intent], [scope], [entity], [rank], [output], [safety], [capability] etiketini failure class olarak ele al; prompta özel değil semantic katmana düzeltme yap.
9. Metamorphic/Gym ailesindeki tek varyasyonu geçirip diğerlerini bozma; aynı semantic contract ailesinin tamamını koru.
10. Gerçek capability yoksa yapılmış gibi gösterme.
11. İş sonunda /bin/zsh Scripts/build-check.command çalıştır.

Öncelik:
capability gap → Arena failure → Live Eval failure → güncel Mentor failure → Training regression.
EOF
fi

echo "Developer prompt mode: $GAP_MODE • $(wc -c < "$PROMPT_FILE" | tr -d ' ') bytes" | tee -a "$LOG"

GAP_LABEL="$("$NODE_BIN" - "$GAP_SOURCE" <<'NODE'
const fs = require("fs");
const file = process.argv[2];
try {
  const payload = JSON.parse(fs.readFileSync(file, "utf8"));
  const gap =
    payload && payload.gap
      ? payload.gap
      : (
          Array.isArray(payload.capabilityGaps)
            ? payload.capabilityGaps[0]
            : null
        );
  if (gap) {
    process.stdout.write(
      String(gap.capabilityName || gap.capabilityID || "Capability") +
      " (" + String(gap.capabilityID || "unknown") + ")"
    );
  }
} catch {}
NODE
)"

LEARNING_PATH="$("$NODE_BIN" - "$GAP_SOURCE" <<'NODE'
const fs = require("fs");
try {
  const payload = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
  const gap =
    payload && payload.gap
      ? payload.gap
      : (
          Array.isArray(payload && payload.capabilityGaps)
            ? payload.capabilityGaps[0]
            : null
        );
  process.stdout.write(String(gap && gap.learningPath || "integration"));
} catch {
  process.stdout.write("integration");
}
NODE
)"

RUNTIME_SOURCE_HINTS="$("$NODE_BIN" - "$LOCAL_MENTOR_DIR/latest.json" "$GAP_SOURCE" <<'NODE'
const fs = require("fs");

function readJSON(file) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return null;
  }
}

const mentor = readJSON(process.argv[2]);
const source = readJSON(process.argv[3]);

const gap =
  source && source.gap
    ? source.gap
    : (
        source &&
        Array.isArray(source.capabilityGaps)
          ? source.capabilityGaps[0]
          : null
      );

const capabilityID = String(
  gap && gap.capabilityID || ""
);

const lines =
  mentor &&
  Array.isArray(mentor.activityTail)
    ? mentor.activityTail.map(
        (item) => String(item && item.text || "")
      )
    : [];

const hints = [];

function add(value) {
  const clean = String(value || "")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/[.•|]+$/g, "")
    .trim();

  if (
    clean.length < 6 ||
    clean.length > 140 ||
    clean === capabilityID ||
    hints.includes(clean)
  ) {
    return;
  }

  hints.push(clean);
}

for (const line of lines) {
  let segment = "";

  const failureMatch =
    line.match(
      /(?:başarısız|failed|error)\s*:\s*(.+)$/i
    );

  if (failureMatch) {
    segment = failureMatch[1].trim();
  } else {
    const notFoundMatch =
      line.match(/(.{3,80}?bulunamadı)\s*:/i);

    if (notFoundMatch) {
      segment = notFoundMatch[1].trim();
    }
  }

  if (!segment) continue;

  const parts = segment
    .split(":")
    .map((part) => part.trim())
    .filter(Boolean);

  if (parts.length > 1) {
    const tail = parts[parts.length - 1];

    if (
      tail.length <= 80 &&
      tail.split(/\s+/).length <= 8
    ) {
      add(parts.slice(0, -1).join(": "));
    }
  }

  add(segment);
}

process.stdout.write(
  JSON.stringify(hints.slice(0, 6))
);
NODE
)"

GAP_KEY="$("$NODE_BIN" - "$GAP_SOURCE" <<'NODE'
const fs = require("fs");
const crypto = require("crypto");

try {
  const payload = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
  const gap =
    payload && payload.gap
      ? payload.gap
      : (
          Array.isArray(payload && payload.capabilityGaps)
            ? payload.capabilityGaps[0]
            : null
        );

  if (!gap) {
    process.stdout.write("full");
    process.exit(0);
  }

  const capabilityID = String(gap.capabilityID || "unknown");
  const signature = [
    capabilityID,
    String(gap.kind || ""),
    String(gap.learningPath || ""),
    String(gap.reason || ""),
    String(gap.researchGoal || "")
  ].join("\n");

  const digest = crypto
    .createHash("sha256")
    .update(signature)
    .digest("hex")
    .slice(0, 12);

  const safeID = capabilityID
    .replace(/[^a-zA-Z0-9._-]+/g, "_")
    .slice(0, 80);

  process.stdout.write(safeID + "-" + digest);
} catch {
  process.stdout.write("unknown");
}
NODE
)"

CHECKPOINT_DIR="$STATUS_DIR/checkpoints"
mkdir -p "$CHECKPOINT_DIR"
CHECKPOINT_FILE="$CHECKPOINT_DIR/$GAP_KEY.json"
SKILL_CANDIDATE_FILE="$SKILL_CANDIDATE_DIR/$GAP_KEY-$STAMP.json"

CAPABILITY_ID="$("$NODE_BIN" - "$GAP_SOURCE" <<'NODE'
const fs = require("fs");
try {
  const payload = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
  const gap = payload?.gap || (Array.isArray(payload?.capabilityGaps) ? payload.capabilityGaps[0] : null);
  process.stdout.write(String(gap?.capabilityID || ""));
} catch {}
NODE
)"

if [ -f "$SKILL_LIBRARY_FILE" ] && [ -n "$CAPABILITY_ID" ]; then
    PROMOTED_SKILLS="$("$NODE_BIN" - "$SKILL_LIBRARY_FILE" "$CAPABILITY_ID" <<'NODE'
const fs = require("fs");
try {
  const library = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
  const capabilityID = process.argv[3];
  const skills = Array.isArray(library?.skills)
    ? library.skills.filter(s => s?.state === "promoted" && s?.capability_id === capabilityID).slice(0, 5)
    : [];
  if (skills.length) {
    process.stdout.write(skills.map(s =>
      "- " + String(s.name || s.id) + ": " + String(s.generalized_strategy || "") +
      "\n  Trigger: " + String(s.trigger_pattern || "") +
      "\n  Verify: " + (Array.isArray(s.verification_contract) ? s.verification_contract.join(" | ") : "")
    ).join("\n"));
  }
} catch {}
NODE
)"
    if [ -n "$PROMOTED_SKILLS" ]; then
        {
            echo ""
            echo "KRALİ promoted skill library — bu capability için doğrulanmış yeniden kullanılabilir stratejiler:"
            echo "$PROMOTED_SKILLS"
            echo "Bu skill'leri körlemesine kopyalama; mevcut kanıtla uyumluysa yeniden kullan veya geliştir."
        } >> "$PROMPT_FILE"
        echo "🧠 Promoted skill context eklendi: $CAPABILITY_ID" | tee -a "$LOG"
    fi
fi

# Ana Developer Agent yalnız native tool-call probe geçmiş modelde kalır.
# Structured JSON continuation modeli aşağıda bağımsız latency probe ile seçilir.

CONTROLLER_MODEL="$MODEL"
if [ "$PROVIDER" = "ollama" ] &&
   [ "$LOCAL_AGENT_ENGINE" = "native-ollama" ] &&
   [ "$LEARNING_PATH" = "primitivePatch" ]; then
    select_structured_controller_model || true
    echo "🧭 Structured controller modeli: $CONTROLLER_MODEL • ölçülmüş JSON karar modu" | tee -a "$LOG"
fi

if [ -f "$CHECKPOINT_FILE" ]; then
    echo "♻️ Developer checkpoint bulundu; aynı gap teşhisi kaldığı yerden devam edecek: $GAP_KEY" | tee -a "$LOG"
fi

if [ "$GAP_MODE" = "gap" ] && [ -n "$GAP_LABEL" ]; then
    write_status "learning|$GAP_LABEL için provider/strategy öğreniliyor|$BRANCH|$WORKTREE"
else
    write_status "running|Developer Agent diagnostic'leri inceliyor|$BRANCH|$WORKTREE"
fi

export CLINE_COMMAND_PERMISSIONS='{"allow":["git status*","git diff*","git log*","git show*","xcodebuild *","xcrun *","swift *","grep *","rg *","find *","cat *","head *","tail *","sed *","ls *"],"deny":["sudo *","rm -rf *","git push*","git reset --hard*","git clean*","open *","osascript *"]}'

TIMEOUT_SECONDS="900"
if [ "$GAP_MODE" = "gap" ]; then
    TIMEOUT_SECONDS="600"
fi

# Headless çağrıyı minimum argüman yüzeyinde tutuyoruz.
# Güncel Cline ayrıca --cwd, --model, --thinking ve --retries destekler;
# burada worktree çalışma dizini process cwd ile verilir.
CLINE_ARGS=(
    --json
    --auto-approve true
    --provider "$PROVIDER"
    --timeout "$TIMEOUT_SECONDS"
)

CLINE_RUN_LOG="$LOG_DIR/KRALI-Developer-Agent-Cline-$STAMP.log"

CLINE_STARTED_AT="$(date +%s)"

if [ "$PROVIDER" = "ollama" ] &&
   [ "$LOCAL_AGENT_ENGINE" = "native-ollama" ]; then
    CLINE_RUN_LOG="$LOG_DIR/KRALI-Developer-Agent-Local-$STAMP.log"
    write_status "local_agent_starting|$GAP_LABEL native Ollama Developer Agent ile öğreniliyor|$BRANCH|$WORKTREE"
    echo "🧠 Model rolleri: root-cause=$CONTROLLER_MODEL • mutation=$MODEL • controller=$CONTROLLER_MODEL" | tee -a "$LOG"

    KRALI_WORKTREE="$WORKTREE" \
    KRALI_PROMPT_FILE="$PROMPT_FILE" \
    KRALI_DEV_MODEL="$MODEL" \
    KRALI_ARCHITECT_MODEL="$MODEL" \
    KRALI_ROOT_CAUSE_MODEL="$CONTROLLER_MODEL" \
    KRALI_ARCHITECT_MUTATION_MODEL="$MODEL" \
    KRALI_CONTROLLER_MODEL="$CONTROLLER_MODEL" \
    KRALI_OLLAMA_BASE_URL="$OLLAMA_BASE_URL" \
    KRALI_STATUS_FILE="$STATUS" \
    KRALI_BRANCH="$BRANCH" \
    KRALI_GAP_LABEL="$GAP_LABEL" \
    KRALI_APP_VERSION="$(/bin/cat "$ROOT/VERSION" 2>/dev/null | /usr/bin/tr -d '[:space:]')" \
    KRALI_RUN_ID="$STAMP" \
    KRALI_CHECKPOINT_FILE="$CHECKPOINT_FILE" \
    KRALI_RUNTIME_SOURCE_HINTS="$RUNTIME_SOURCE_HINTS" \
    KRALI_REQUIRE_ROOT_CAUSE_GATE="$([ "$GAP_MODE" = "gap" ] && echo 1 || echo 0)" \
    KRALI_REQUIRE_CHANGE="$([ "$GAP_MODE" = "gap" ] && echo 1 || echo 0)" \
    KRALI_LOCAL_AGENT_MAX_COMPLETION_REJECTIONS="$([ "$LEARNING_PATH" = "primitivePatch" ] && echo 2 || echo 3)" \
    KRALI_LOCAL_AGENT_MAX_STRUCTURED_ACTIONS="$([ "$LEARNING_PATH" = "primitivePatch" ] && echo 6 || echo 8)" \
    KRALI_LOCAL_AGENT_MAX_INSPECTIONS="$([ "$LEARNING_PATH" = "primitivePatch" ] && echo 4 || echo 6)" \
    KRALI_LOCAL_AGENT_MAX_ITERATIONS="$([ "$LEARNING_PATH" = "primitivePatch" ] && echo 10 || echo 16)" \
    KRALI_LOCAL_AGENT_TIMEOUT_MS="$([ "$LEARNING_PATH" = "primitivePatch" ] && echo 300000 || echo 300000)" \
    KRALI_LOCAL_AGENT_REQUEST_TIMEOUT_MS="$([ "$LEARNING_PATH" = "primitivePatch" ] && echo 45000 || echo 60000)" \
    KRALI_LOCAL_AGENT_STRUCTURED_TIMEOUT_MS="$([ "$LEARNING_PATH" = "primitivePatch" ] && echo 120000 || echo 60000)" \
    "$NODE_BIN" "$ROOT/Scripts/ollama-developer-agent.mjs" \
        > >(tee "$CLINE_RUN_LOG" >>"$LOG") \
        2> >(tee -a "$CLINE_RUN_LOG" >>"$LOG" >&2)
    CLINE_EXIT=$?
elif [ "$USE_SDK_FALLBACK" -eq 1 ]; then
    if prepare_sdk_fallback; then
        write_status "sdk_fallback_running|$GAP_LABEL ClineCore SDK üzerinden öğreniliyor|$BRANCH|$WORKTREE"
        KRALI_CLINE_SDK_HOST="$SDK_HOST" \
        KRALI_WORKTREE="$WORKTREE" \
        KRALI_PROMPT_FILE="$PROMPT_FILE" \
        KRALI_CLINE_SETTINGS="$CLINE_SETTINGS" \
        KRALI_DEV_PROVIDER="$PROVIDER" \
        KRALI_DEV_MODEL="$MODEL" \
        KRALI_OLLAMA_BASE_URL="$OLLAMA_BASE_URL" \
        KRALI_STATUS_FILE="$STATUS" \
        KRALI_BRANCH="$BRANCH" \
        KRALI_GAP_LABEL="$GAP_LABEL" \
        KRALI_APP_VERSION="$(/bin/cat "$ROOT/VERSION" 2>/dev/null | /usr/bin/tr -d '[:space:]')" \
        KRALI_RUN_ID="$STAMP" \
        KRALI_SDK_TIMEOUT_MS="480000" \
        KRALI_REQUIRE_TOOL_USE="$([ "$GAP_MODE" = "gap" ] && echo 1 || echo 0)" \
        "$NODE_BIN" "$ROOT/Scripts/cline-sdk-fallback.mjs" \
            > >(tee "$CLINE_RUN_LOG" >>"$LOG") \
            2> >(tee -a "$CLINE_RUN_LOG" >>"$LOG" >&2)
        CLINE_EXIT=$?
    else
        printf '%s\n' "KRALI SDK fallback kurulamadı." >"$CLINE_RUN_LOG"
        CLINE_EXIT=20
    fi
else
    (
        cd "$WORKTREE" &&
        "$CLINE_BIN" "${CLINE_ARGS[@]}" "$(cat "$PROMPT_FILE")"
    ) >"$CLINE_RUN_LOG" 2>&1
    CLINE_EXIT=$?
fi

CLINE_DURATION="$(( $(date +%s) - CLINE_STARTED_AT ))"

cat "$CLINE_RUN_LOG" >>"$LOG"

if [ "$CLINE_EXIT" -eq 25 ] &&
   [ "$PROVIDER" = "ollama" ] &&
   [ "$LOCAL_AGENT_ENGINE" != "native-ollama" ]; then
    FALLBACK_MODEL=""
    select_installed_tool_fallback "$MODEL" || true

    if [ -n "$FALLBACK_MODEL" ]; then
        echo "⚠️ Cline local tool protocol doğrulanmadı; $FALLBACK_MODEL ile tek kontrollü retry." | tee -a "$LOG"
        write_status "local_model_fallback|Cline tool protocol için fallback model hazırlanıyor: $FALLBACK_MODEL|$BRANCH|$WORKTREE"
    fi

    if [ -n "$FALLBACK_MODEL" ] &&
       ensure_ollama_model "$FALLBACK_MODEL" &&
       probe_ollama_model "$FALLBACK_MODEL"; then
        MODEL="$FALLBACK_MODEL"
        TOOL_RETRY_LOG="$LOG_DIR/KRALI-Developer-Agent-Cline-$STAMP-tool-retry.log"

        KRALI_CLINE_SDK_HOST="$SDK_HOST" \
        KRALI_WORKTREE="$WORKTREE" \
        KRALI_PROMPT_FILE="$PROMPT_FILE" \
        KRALI_CLINE_SETTINGS="$CLINE_SETTINGS" \
        KRALI_DEV_PROVIDER="$PROVIDER" \
        KRALI_DEV_MODEL="$MODEL" \
        KRALI_OLLAMA_BASE_URL="$OLLAMA_BASE_URL" \
        KRALI_STATUS_FILE="$STATUS" \
        KRALI_BRANCH="$BRANCH" \
        KRALI_GAP_LABEL="$GAP_LABEL" \
        KRALI_APP_VERSION="$(/bin/cat "$ROOT/VERSION" 2>/dev/null | /usr/bin/tr -d '[:space:]')" \
        KRALI_RUN_ID="$STAMP" \
        KRALI_SDK_TIMEOUT_MS="480000" \
        KRALI_REQUIRE_TOOL_USE="1" \
        "$NODE_BIN" "$ROOT/Scripts/cline-sdk-fallback.mjs" \
            > >(tee "$TOOL_RETRY_LOG" >>"$LOG") \
            2> >(tee -a "$TOOL_RETRY_LOG" >>"$LOG" >&2)
        CLINE_EXIT=$?
        cat "$TOOL_RETRY_LOG" >>"$LOG"
    fi
fi

if [ "$CLINE_EXIT" -eq 137 ] &&
   [ "$GAP_MODE" = "gap" ] &&
   [ "$USE_SDK_FALLBACK" -eq 0 ]; then
    echo "⚠️ Cline SIGKILL/137 aldı; ultra-light retry deneniyor." | tee -a "$LOG"
    write_status "retrying|Cline kaynak baskısı nedeniyle daha hafif modda yeniden deneniyor|$BRANCH|$WORKTREE"

    RETRY_LOG="$LOG_DIR/KRALI-Developer-Agent-Cline-$STAMP-retry.log"
    RETRY_ARGS=(
        --json
        --auto-approve true
        --provider "$PROVIDER"
        --timeout 420
    )

    RETRY_STARTED_AT="$(date +%s)"
    (
        cd "$WORKTREE" &&
        "$CLINE_BIN" "${RETRY_ARGS[@]}" "$(cat "$PROMPT_FILE")"
    ) >"$RETRY_LOG" 2>&1
    CLINE_EXIT=$?
    CLINE_DURATION="$(( CLINE_DURATION + $(date +%s) - RETRY_STARTED_AT ))"
    cat "$RETRY_LOG" >>"$LOG"
fi

if [ "$CLINE_EXIT" -eq 28 ] &&
   [ "$PROVIDER" = "ollama" ] &&
   [ "$LOCAL_AGENT_ENGINE" = "native-ollama" ]; then
    echo "✅ Structured candidate preflight build geçti; normal verification + skill extraction hattına devam ediliyor." | tee -a "$LOG"
    CLINE_EXIT=0
fi

if [ "$CLINE_EXIT" -ne 0 ]; then
    FAILURE_BASE="$(
        /bin/cat "$STATUS" 2>/dev/null |
        /usr/bin/sed 's/|@meta.*//'
    )"
    FAILURE_STATE="$(
        printf '%s' "$FAILURE_BASE" |
        /usr/bin/awk -F'|' '{print $1}'
    )"
    FAILURE_MESSAGE="$(
        printf '%s' "$FAILURE_BASE" |
        /usr/bin/awk -F'|' '{print $2}'
    )"

    ERROR_SOURCE="$CLINE_RUN_LOG"
    if [ -f "$LOG_DIR/KRALI-Developer-Agent-Cline-$STAMP-tool-retry.log" ]; then
        ERROR_SOURCE="$LOG_DIR/KRALI-Developer-Agent-Cline-$STAMP-tool-retry.log"
    elif [ -f "$LOG_DIR/KRALI-Developer-Agent-Cline-$STAMP-retry.log" ]; then
        ERROR_SOURCE="$LOG_DIR/KRALI-Developer-Agent-Cline-$STAMP-retry.log"
    fi

    CLINE_ERROR="$(
        tail -n 80 "$ERROR_SOURCE" 2>/dev/null |
        grep -Eai 'auth|oauth|error|failed|provider|model|login|sign in|killed|memory|resource|unknown option|invalid option|sdk fallback|exception|signature|gatekeeper|spctl' |
        tail -n 1 |
        tr '\n|' '  ' |
        sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' |
        cut -c1-280
    )"

    if [ -z "$CLINE_ERROR" ]; then
        if [ "$CLINE_EXIT" -eq 137 ]; then
            CLINE_ERROR="process SIGKILL aldı; kaynak baskısı veya işletim sistemi sonlandırması"
        else
            CLINE_ERROR="ayrıntılı hata satırı üretilemedi"
        fi
    fi

    # Session prompt/build cache are orchestration artifacts, not source candidates.
    rm -f "$PROMPT_FILE"
    rm -rf "$WORKTREE/.build-check"

    DIRTY_CANDIDATE="$(git -C "$WORKTREE" status --porcelain --untracked-files=all 2>/dev/null || true)"

    if [ -n "$DIRTY_CANDIDATE" ]; then
        echo "🧩 Developer Agent hata verdi ancak candidate değişiklik üretti; recovery başlatılıyor." | tee -a "$LOG"
        write_status "recovering_candidate|Developer Agent oturumu tamamlanmadı ancak üretilen candidate değişiklikler korunuyor|$BRANCH|$WORKTREE"

        KRALI_NODE_BIN="$NODE_BIN" \
        KRALI_RECOVERY_MODEL="$MODEL" \
        KRALI_OLLAMA_BASE_URL="$OLLAMA_BASE_URL" \
        KRALI_CANDIDATE_REPAIR_ATTEMPTS="2" \
        /bin/zsh "$ROOT/Scripts/recover-developer-candidate.command" >>"$LOG" 2>&1 || true

        RECOVERY_STATE="$(
            /bin/cat "$STATUS" 2>/dev/null |
            /usr/bin/awk -F'|' '{print $1}'
        )"

        case "$RECOVERY_STATE" in
            recovered_candidate_ready)
                echo "✅ Hatalı SDK oturumundaki candidate kurtarıldı ve build geçti." | tee -a "$LOG"
                exit 0
                ;;
            recovered_candidate_build_failed)
                echo "⚠️ Candidate GitHub'a korundu ancak build geçmedi." | tee -a "$LOG"
                exit 21
                ;;
            candidate_recovery_failed)
                echo "❌ Candidate recovery başarısız oldu." | tee -a "$LOG"
                exit 24
                ;;
            candidate_repair_failed)
                echo "❌ Candidate compiler-guided repair tamamlanamadı; branch korundu." | tee -a "$LOG"
                exit 25
                ;;
        esac
    else
        git -C "$ROOT" worktree remove "$WORKTREE" --force >>"$LOG" 2>&1 || true
        git -C "$ROOT" branch -D "$BRANCH" >>"$LOG" 2>&1 || true
    fi

    if [ "$PROVIDER" = "ollama" ] &&
       [ "$LOCAL_AGENT_ENGINE" = "native-ollama" ] &&
       echo "$FAILURE_STATE" |
       /usr/bin/grep -Eq '^local_(agent_|storage_|tool_|ai_|model_)'; then
        write_status "$FAILURE_STATE|${FAILURE_MESSAGE:-Native yerel agent başarısız}|$BRANCH|$WORKTREE"
        echo "❌ Native yerel Developer Agent durdu: ${FAILURE_MESSAGE:-$CLINE_ERROR}" | tee -a "$LOG"
        exit 20
    fi

    write_status "failed|Developer Agent exit $CLINE_EXIT (${CLINE_DURATION}s): $CLINE_ERROR|$BRANCH|$WORKTREE"
    echo "❌ Developer Agent görevi başarısız oldu (exit $CLINE_EXIT, ${CLINE_DURATION}s): $CLINE_ERROR" | tee -a "$LOG"
    exit 20
fi

rm -f "$PROMPT_FILE"

cd "$WORKTREE"

if [ -z "$(git status --porcelain)" ]; then
    if [ "$GAP_MODE" = "gap" ]; then
        write_status "no_change_unverified|Aktif capability gap için doğrulanmış candidate üretilmedi|$BRANCH|$WORKTREE"
        echo "❌ Capability gap devam ederken kanıtsız no_change kabul edilmedi." | tee -a "$LOG"

        cd "$ROOT"
        git worktree remove "$WORKTREE" --force >>"$LOG" 2>&1 || true
        git branch -D "$BRANCH" >>"$LOG" 2>&1 || true
        exit 26
    fi

    write_status "no_change|Diagnostic yeşil; değişiklik gerekmedi|$BRANCH|$WORKTREE"
    echo "✅ Developer Agent değişiklik gerektirmedi." | tee -a "$LOG"
    exit 0
fi

write_status "verifying|$GAP_LABEL için aday değişiklik doğrulanıyor ve build ediliyor|$BRANCH|$WORKTREE"

if ! /bin/zsh "$WORKTREE/Scripts/build-check.command" "$WORKTREE" >>"$LOG" 2>&1; then
    rm -rf "$WORKTREE/.build-check"
    git add -A
    git commit -m "Developer Agent candidate (build failed)" >>"$LOG" 2>&1 || true
    git push -u origin "$BRANCH" >>"$LOG" 2>&1 || true
    write_status "build_failed|Aday değişiklik build geçmedi; branch incelemeye gönderildi|$BRANCH|$WORKTREE"
    echo "❌ Build başarısız; aday branch korundu." | tee -a "$LOG"
    exit 21
fi

rm -rf "$WORKTREE/.build-check"

if [ "$PROVIDER" = "ollama" ] && [ -n "$MODEL" ]; then
    write_status "skill_extracting|Build/regression geçen adaydan genellenebilir experimental skill çıkarılıyor|$BRANCH|$WORKTREE"
    if KRALI_WORKTREE="$WORKTREE" \
       KRALI_GAP_SOURCE="$GAP_SOURCE" \
       KRALI_DEV_MODEL="$MODEL" \
       KRALI_ARCHITECT_MODEL="$MODEL" \
       KRALI_OLLAMA_BASE_URL="$OLLAMA_BASE_URL" \
       KRALI_SKILL_CANDIDATE_FILE="$SKILL_CANDIDATE_FILE" \
       KRALI_APP_VERSION="$(/bin/cat "$ROOT/VERSION" 2>/dev/null | /usr/bin/tr -d '[:space:]')" \
       KRALI_BRANCH="$BRANCH" \
       KRALI_RUN_ID="$STAMP" \
       "$NODE_BIN" "$ROOT/Scripts/ollama-skill-extractor.mjs" >>"$LOG" 2>&1; then
        write_status "skill_candidate_ready|Experimental skill candidate hazır; runtime postcondition doğrulaması sonrası promote edilebilir|$BRANCH|$WORKTREE"
        echo "🧠 Experimental skill candidate: $SKILL_CANDIDATE_FILE" | tee -a "$LOG"
    else
        echo "⚠️ Kod adayı build geçti ancak skill distillation tamamlanamadı; bu aday öğrenilmiş sayılmayacak." | tee -a "$LOG"
    fi
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

rm -f "$CHECKPOINT_FILE"
write_status "ready_for_review|$GAP_LABEL öğrenme adayı hazır; build geçti ve incelemeye hazır|$BRANCH|$WORKTREE"
echo "✅ Developer Agent adayı hazır: $BRANCH" | tee -a "$LOG"
echo "ℹ️ Main branch değiştirilmedi." | tee -a "$LOG"
