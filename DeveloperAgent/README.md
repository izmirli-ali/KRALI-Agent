# KRALİ Developer Agent

KRALİ Developer Agent, **KRALİ'nin kendisi değildir**. Geliştirme döneminde Training Lab, Live Research Eval ve Mentor trace'lerini okuyup izole bir Git worktree içinde aday kod düzeltmeleri hazırlayan yardımcı coding agent katmanıdır.

## Neden Cline?

Cline CLI headless/JSON çalışabiliyor, çalışma dizini seçebiliyor, araçları otomatik kullanabiliyor ve ChatGPT Subscription OAuth ile mevcut ChatGPT aboneliğini kullanabiliyor. KRALİ tarafında varsayılan seçim:

- Provider: `openai-codex` (ChatGPT Subscription)
- Model: `cline auth` sırasında kullanıcının seçtiği model

Developer Agent ayrı bir OpenAI API anahtarı istemez. Kullanım, ChatGPT aboneliğinin Codex/OAuth erişimi ve ilgili kullanım limitleri içinde kalır. Script ücretli API anahtarına veya Cline kredi sistemine kendiliğinden geçmez.

## Güvenlik modeli

Developer Agent:

1. `main` üzerinde çalışmaz.
2. Her turda yeni `krali-dev-agent/<timestamp>` branch/worktree açar.
3. Cline'a `git push`, `sudo`, destructive reset/clean ve uygulama açma komutları verilmez.
4. Cline bittikten sonra KRALİ'nin kendi `Scripts/build-check.command` scripti bağımsız build doğrulaması yapar.
5. Başarılı aday yalnızca ayrı branch'e push edilir.
6. Main'e merge otomatik değildir; ChatGPT Mentor veya kullanıcı incelemesi gerekir.

## Bir kerelik kurulum

Cline CLI:

```bash
npm install -g cline
cline auth
```

Auth ekranında **Sign in with ChatGPT** seçilir. Ardından ChatGPT Subscription için kullanılacak model seçilir. KRALİ Developer Agent varsayılan olarak bu provider/model seçimini yeniden kullanır.

## Çalıştırma

```bash
~/Developer/KRALI-Agent/Scripts/run-developer-agent.command
```

Başarılıysa aday branch GitHub'a gönderilir. ChatGPT Mentor'a **“Developer Agent branch'ine bak”** denerek kod incelemesi yaptırılabilir.

## Ne zaman çalıştırılmalı?

- Live Research Eval başarısız olduğunda
- Training Lab regression olduğunda
- Güncel Mentor trace gerçek bir görev hatası gösterdiğinde
- Açık capability gap için düşük riskli bir entegrasyon hazırlamak gerektiğinde

Tüm diagnostic'ler yeşilse Developer Agent'ın sırf değişiklik yapmak için kodu kurcalamaması temel kuraldır.


## Cursor Architect Bridge (v0.10.26)

Cursor CLI, yerel Developer Agent'ın yerine geçen mutation provider değildir. Yalnızca belirli teşhis başarısızlıklarında ikinci görüş veren **read-only architect** katmanıdır.

Tetiklenen durumlar:
- `local_agent_iteration_limit`
- `local_agent_root_cause_inconclusive`
- `local_agent_strategy_escalation_inconclusive`
- `local_agent_tool_protocol_failed`

Güvenlik sözleşmesi:
- Cursor `--mode=ask` ile çağrılır.
- Geçici workspace sandbox modu `workspace_readonly` olur.
- `Write(**)`, `Shell(*)`, `WebFetch(*)` ve `Mcp(*:*)` açıkça deny edilir.
- Explicit `CURSOR_API_KEY` / `CURSOR_AUTH_TOKEN` ortam değişkenleri bridge tarafından kaldırılır; yalnız kullanıcının `agent login` oturumu kullanılır.
- Cursor kod değiştirmez, candidate üretmez, branch/commit/push yapmaz.
- Aynı VERSION + gap için hazır diagnosis tekrar kullanılır; ücretsiz kota tekrar tüketilmez.
- Diagnosis `~/Library/Application Support/KRALI Agent/Mentor/cursor-architect-latest.json` altında saklanır ve Mentor Sync ile repo tarafındaki `Mentor/cursor-architect-latest.json` dosyasına taşınır.
- Sonraki Developer Agent turunda diagnosis yalnız advisory/hypothesis olarak prompt'a eklenir. Mutation öncesi exact source ve runtime evidence bağımsız olarak yeniden doğrulanmalıdır.

Cursor CLI yoksa, login hazır değilse veya ücretsiz kullanım limiti doluysa KRALİ'nin yerel Qwen/Devstral yolu değişmeden devam eder.
