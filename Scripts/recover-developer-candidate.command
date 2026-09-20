#!/bin/zsh
set -u

ROOT="${KRALI_REPO_ROOT:-$HOME/Developer/KRALI-Agent}"
STATUS="$HOME/Library/Application Support/KRALI Agent/Developer/latest.txt"
LOG="$HOME/Library/Logs/KRALI-Developer-Agent-Recovery.log"

mkdir -p "$(dirname "$STATUS")"
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

if /bin/zsh "$WORKTREE/Scripts/build-check.command" "$WORKTREE" >>"$LOG" 2>&1; then
    write_status "recovered_candidate_ready|Kurtarılan öğrenme adayı build geçti ve incelemeye hazır|$BRANCH|$WORKTREE"
    echo "Recovered candidate build passed: $BRANCH" >>"$LOG"
    exit 0
fi

write_status "recovered_candidate_build_failed|Kurtarılan öğrenme adayı GitHub'da korundu ancak build geçmedi|$BRANCH|$WORKTREE"
echo "Recovered candidate build failed but branch preserved: $BRANCH" >>"$LOG"
exit 21
