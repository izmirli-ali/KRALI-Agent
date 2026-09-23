# KRALİ Remote-first Developer Compute

v0.10.29 hedefi: Developer Agent'in ağır inference yükünü Mac'ten uzaklaştırmak.

## Provider sırası

1. Cloudflare Workers AI — remote-first
2. Cursor Architect — read-only diagnosis/escalation
3. Local Ollama — explicit fallback / remote unavailable

Remote yapılandırma yoksa KRALİ local fallback kullanabilir; v0.10.29 local varsayılanı ağır 24B yerine daha hafif 7B sınıfına indirilmiştir.

## Cloudflare Workers AI

Kurulum:

```bash
/bin/zsh ~/Developer/KRALI-Agent/Scripts/configure-cloudflare-workers-ai.command
```

Cloudflare dashboard > Workers AI > Use REST API bölümünden:
- Account ID
- Workers AI API Token

alınır. Token repo/config dosyasına yazılmaz; macOS Keychain'de saklanır.

Varsayılan modeller:
- main/tool calling: `@cf/zai-org/glm-4.7-flash`
- JSON/structured controller: `@cf/meta/llama-3.3-70b-instruct-fp8-fast`

## Güvenlik

Remote model yalnız izole candidate worktree için kod kararları üretir. Gerçek Mac/Desktop/Shell dış etkileri mevcut KRALİ approval katmanını atlayamaz. Task card allowedScope/forbiddenScope mutation katmanında enforce edilmeye devam eder.

Cloudflare token loglara, Mentor'a veya modele gönderilmez.

## Supabase

`Cloud/Supabase/client-config.example.json` yalnız örnektir. Desktop istemcide modern publishable key kullanılacak. Secret/service-role key kullanılmayacak.

Supabase gerçek bağlantısı proje seçimi + Auth/RLS doğrulaması sonrası açılır.
