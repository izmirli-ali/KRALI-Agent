#!/bin/zsh
set -u

ROOT="${KRALI_REPO_ROOT:-$HOME/Developer/KRALI-Agent}"
TASK_REL="${1:-}"

if [ -z "$TASK_REL" ]; then
    echo "Kullanım: Scripts/run-developer-task.command DeveloperAgent/Tasks/<task>.json"
    exit 2
fi

case "$TASK_REL" in
    DeveloperAgent/Tasks/*.json)
        ;;
    *)
        echo "❌ Yalnız DeveloperAgent/Tasks altındaki JSON görev kartları çalıştırılabilir."
        exit 3
        ;;
esac

TASK_FILE="$ROOT/$TASK_REL"

if [ ! -f "$TASK_FILE" ]; then
    echo "❌ Görev kartı bulunamadı: $TASK_FILE"
    exit 4
fi

TASK_SCOPE_EXPORTS="$(/usr/bin/python3 - "$TASK_FILE" <<'PY'
import json, shlex, sys
p=sys.argv[1]
with open(p,"r",encoding="utf-8") as f:
    data=json.load(f)
task=data.get("developerTask")
meta=data.get("taskMetadata") or {}
assert isinstance(task,dict)
assert task.get("capabilityID")
assert task.get("developerBrief")
allowed=meta.get("allowedScope") or []
forbidden=meta.get("forbiddenScope") or []
assert isinstance(allowed,list) and allowed
assert isinstance(forbidden,list)
print("ALLOWED="+shlex.quote(json.dumps(allowed, ensure_ascii=False)))
print("FORBIDDEN="+shlex.quote(json.dumps(forbidden, ensure_ascii=False)))
PY
)" || {
    echo "❌ Geçersiz developerTask JSON."
    exit 5
}

eval "$TASK_SCOPE_EXPORTS"

echo "🧩 KRALİ kontrollü developer görevi: $TASK_REL"
echo "Mutation scope: $ALLOWED"
echo "Main'e doğrudan yazılmaz; mevcut worktree/build/approval kuralları geçerlidir."

KRALI_DEV_TASK_FILE="$TASK_FILE" \
KRALI_TASK_ALLOWED_SCOPE="$ALLOWED" \
KRALI_TASK_FORBIDDEN_SCOPE="$FORBIDDEN" \
    exec /bin/zsh "$ROOT/Scripts/run-developer-agent.command"
