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


## Sohbetten görevlendirme

v0.10.28 ile kontrollü task kartları doğrudan KRALİ sohbetinden başlatılabilir:

```text
geliştirici görevi: Training Result Analyzer
```

veya task dosya kimliğiyle:

```text
geliştirici görevi: training-result-analyzer-v1
```

KRALİ task kartını `DeveloperAgent/Tasks` içinden generic olarak çözer. Sistem etkisi gerekiyorsa Developer Tool approval kartı aynı sohbet içinde gösterilir ve onay sonrası aynı task/scope ile devam edilir.

## Task verification contract

Bir görev kartı yalnız build-check ile yetinmemesi gereken bağımsız testlere sahipse `taskMetadata.verification` kullanabilir:

```json
{
  "taskMetadata": {
    "verification": {
      "command": ["node", "DeveloperAgent/Tests/example/static-check.js"],
      "requireExitCode": 0,
      "requiredStdout": ["Overall: PASS", "Failed: 0"],
      "requiredArtifacts": [
        "DeveloperAgent/Tests/example/static-check-results.json"
      ],
      "timeoutSeconds": 120
    }
  }
}
```

Kurallar:

- `command` shell string değil argüman dizisidir; shell interpolation kullanılmaz.
- Verification komutu sınırlı environment ile izole worktree içinde çalışır.
- Exit code, gerekli stdout işaretleri ve zorunlu artifact'lar bağımsız runner tarafından doğrulanır.
- Verification sonrası oluşan değişiklikler yeniden task allowed/forbidden scope kontrolünden geçer.
- Build PASS tek başına yeterli değildir. Verification contract tanımlıysa contract geçmeden candidate `ready_for_review` veya `recovered_candidate_ready` olamaz.
- Verification başarısız candidate branch korunabilir fakat merge-ready sayılmaz.

