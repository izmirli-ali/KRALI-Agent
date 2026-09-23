#!/bin/zsh
set -eu

CONFIG_DIR="$HOME/Library/Application Support/KRALI Agent/Cloud"
CONFIG_FILE="$CONFIG_DIR/cloudflare-workers-ai.json"
KEYCHAIN_SERVICE="KRALI Cloudflare Workers AI"
KEYCHAIN_ACCOUNT="api-token"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " KRALİ • CLOUDFLARE WORKERS AI"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Bu kurulum yalnız Developer Agent reasoning yükünü buluta taşır."
echo "Mac approval/execution yetkileri değişmez."
echo ""

printf "Cloudflare Account ID: "
read ACCOUNT_ID
ACCOUNT_ID="$(printf '%s' "$ACCOUNT_ID" | tr -d '[:space:]')"

if [ -z "$ACCOUNT_ID" ]; then
  echo "❌ Account ID boş olamaz."
  exit 2
fi

printf "Workers AI API Token (ekranda görünmez): "
read -s API_TOKEN
echo ""

if [ -z "$API_TOKEN" ]; then
  echo "❌ API token boş olamaz."
  exit 3
fi

mkdir -p "$CONFIG_DIR"
umask 077

cat > "$CONFIG_FILE" <<EOF
{
  "enabled": true,
  "accountId": "$ACCOUNT_ID",
  "mainModel": "@cf/zai-org/glm-4.7-flash",
  "jsonModel": "@cf/meta/llama-3.3-70b-instruct-fp8-fast"
}
EOF

/usr/bin/security add-generic-password   -U   -s "$KEYCHAIN_SERVICE"   -a "$KEYCHAIN_ACCOUNT"   -w "$API_TOKEN" >/dev/null

unset API_TOKEN

echo "✅ Cloudflare remote-first yapılandırması kaydedildi."
echo "Config: $CONFIG_FILE"
echo "Token: macOS Keychain ($KEYCHAIN_SERVICE)"
echo ""
echo "Sonraki Developer Agent görevi remote-first çalışacak."
