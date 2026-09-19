# KRALİ Developer Agent

KRALİ Developer Agent, **KRALİ'nin kendisi değildir**. Geliştirme döneminde Training Lab, Live Research Eval ve Mentor trace'lerini okuyup izole bir Git worktree içinde aday kod düzeltmeleri hazırlayan yardımcı coding agent katmanıdır.

## Neden Cline?

Cline CLI headless/JSON çalışabiliyor, çalışma dizini seçebiliyor, araçları otomatik kullanabiliyor ve model/provider seçimini komut satırından sabitleyebiliyor. KRALİ tarafında varsayılan seçim:

- Provider: `cline`
- Model: `nvidia/nemotron-3.5-lightning`

Bu model Cline tarafından şu anda ücretsiz model olarak sunuluyor. Ücretsiz durum değişirse workflow ücretli modele otomatik geçmez; hata verip durması tercih edilir.

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
cline auth cline
```

Cline sağlayıcısında ücretsiz `nvidia/nemotron-3.5-lightning` modelini seç.

Alternatif olarak Cline'ın desteklediği ChatGPT Subscription OAuth kullanılabilir; KRALİ scripti varsayılan olarak ücretsiz Nemotron modeline sabitlenmiştir ve ücretli modele kendiliğinden geçmez.

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
