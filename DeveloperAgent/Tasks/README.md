# KRALİ Developer Tasks

Bu klasör ChatGPT Lead/Architect tarafından KRALİ Developer Agent'a verilen kontrollü geliştirme görevlerini içerir.

## Çalışma modeli

- KRALİ yalnız ayrı branch/worktree içinde çalışır.
- Main branch'e doğrudan yazmaz veya merge etmez.
- Fiziksel/sistem etkili işlem gerekiyorsa mevcut approval gate geçerlidir.
- Görev kartı düşük riskli, sınırları belirli ve doğrulanabilir olmalıdır.
- KRALİ değiştirilen dosyaları, gerekçeyi, test sonuçlarını, riskleri ve önerilen commit'i raporlar.
- ChatGPT review yapar; main'e alma kararı kullanıcı kontrolünde kalır.

## Görev çalıştırma

Hazır bir görevi elle başlatmak için:

```bash
cd ~/Developer/KRALI-Agent
/bin/zsh Scripts/run-developer-task.command DeveloperAgent/Tasks/training-result-analyzer-v1.json
```

Bu komut mevcut Developer Agent güvenlik kurallarını ve worktree izolasyonunu kullanır. Yeni Homebrew/Ollama/model kurulumu gibi sistem etkileri gerekiyorsa onay kapısı atlanmaz.
