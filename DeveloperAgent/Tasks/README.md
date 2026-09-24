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

## OpenAI Teacher katmanı

Controlled developer task çalışırken isteğe bağlı bir OpenAI Teacher katmanı kullanılabilir.

- Teacher yalnız advisory review üretir; dosya yazma, shell, browser, MCP, merge veya approval yetkisi yoktur.
- Plan checkpoint'inde görev kartını küçük, dependency-ordered ve bağımsız doğrulanabilir alt görevlere böler.
- Final checkpoint'inde yalnız task scope içindeki candidate diff'i ve deterministic verification durumunu inceler.
- Ham kullanıcı mesajı/sourceGoal Teacher paketine eklenmez. Hassas görünümlü diff satırları bridge tarafından redakte edilir.
- Deterministic build/test sonucu Teacher görüşünden üstündür. Teacher REVISE/ESCALATE derse candidate insan review'una gidebilir fakat o turdan otomatik skill distillation yapılmaz.
- Teacher API anahtarı repoda tutulmaz. Runner yalnız macOS Keychain'de service=`KRALI OpenAI Teacher`, account=`api-key` altında mevcutsa kullanır.
- Varsayılan model `gpt-5.6-sol`; `KRALI_OPENAI_TEACHER_MODEL` ile değiştirilebilir.
- Teacher unavailable olduğunda mevcut Developer Agent akışı bozulmadan devam eder.

Bu ilk aşama task decomposition'ı advisory plan olarak prompt'a taşır. Alt görevlerin ayrı checkpoint/branch lifecycle ile otomatik sırayla yürütülmesi ayrı orchestration fazıdır.

## Developer Task Graph

OpenAI Teacher plan review geçerli bir `subtasks` DAG üretirse native Developer Agent bunu deterministik bir execution graph olarak kullanır.

- Her subtask benzersiz ID, dependency listesi, dar mutation scope, expected result ve verification intent taşır.
- Subtask scope parent developer task `allowedScope` sınırını genişletemez; wildcard ancak parent scope ile birebir aynıysa kabul edilir.
- Aktif subtask dışındaki mutation deterministik olarak reddedilir.
- Aynı worktree/candidate üzerinde yalnız dependency'leri doğrulanmış node çalışır.
- Gerçek mutation + diff inspection + `build_check PASS` olmadan node `verified` olamaz.
- Node doğrulanınca state machine sıradaki ready dependency node'una geçer ve inspection/mutation gate'leri o node için sıfırlanır.
- Tüm node'lar verified olmadan Developer Agent completion ve structured candidate handoff reddedilir.
- Graph state Developer checkpoint schema v8 içinde saklanır; aynı graph fingerprint ile timeout sonrası devam edebilir.
- Parent task'ın gerçek verification contract'ı graph tamamlandıktan sonra runner seviyesinde yine zorunludur.
- Teacher planı yoksa veya DAG/scope doğrulaması geçmezse mevcut tek-task Developer Agent davranışı korunur.

