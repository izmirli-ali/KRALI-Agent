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

## Baseline Task Decomposer

Controlled developer tasks no longer depend on OpenAI Teacher to obtain a task graph.

1. KRALİ first runs `Scripts/developer-task-decomposer.mjs` against the existing structured controller model (remote `cloudflare-json` or the configured local controller).
2. The decomposer returns a bounded DAG of 1–6 implementation subtasks. Every subtask has dependencies, a mutation scope, expected result and verification intent.
3. Subtask scope cannot widen the parent task `allowedScope`, cannot enter `forbiddenScope`, and cycles/unknown dependencies are rejected.
4. If OpenAI Teacher is configured, Teacher receives KRALİ's baseline graph and acts as a senior reviewer/refiner. Teacher is not the source of task authority.
5. If the Teacher-reviewed graph is invalid, native Developer Agent falls back to the valid KRALİ baseline graph.
6. If no valid graph can be produced, the existing single-task safety path remains available instead of inventing an unsafe plan.

## Candidate Surface Guard

`Scripts/developer-candidate-surface-guard.mjs` protects existing code/API surface before build.

- For `primitivePatch` tasks, large destructive rewrites, removal of named Swift types, or material API/function surface drops are rejected before `build_check`.
- The guard compares the candidate against the stable pre-candidate base commit, including recovery/repair runs.
- New files are not treated as destructive rewrites; the guard focuses on modified existing code files.
- An explicit registered task may opt into destructive change only with `taskMetadata.allowDestructiveChange=true`; this is not inferred by the model.
- A failed guard produces `candidate_surface_regression`. Recovery may repair the candidate, but main is never changed automatically.

## Provider Resilience

Developer Agent remote-first çalışırken Cloudflare Workers AI quota/429 veya tekrarlayan transport timeout ile kullanılamaz hale gelirse aynı run içinde provider circuit breaker açılır.

- Baseline decomposer Cloudflare structured controller'dan HTTP 429 alırsa veya request timeout olursa önce side-effect-free local fallback probe çalışır.
- Native coding agent kendi retry bütçesini tüketip Cloudflare quota/429 ya da provider transport timeout ile durursa aynı worktree, task graph ve checkpoint korunarak bir kez local modelle devam edilir.
- Local fallback yalnız zaten kurulu Ollama binary, zaten çalışan local Ollama endpoint ve zaten indirilmiş modeller arasından seçim yapar.
- Failover probe hiçbir zaman Homebrew install/upgrade, Ollama service start, model pull/download veya başka sistem değişikliği yapmaz.
- Local fallback için hem native tool-call probe geçen bir coding model hem de structured-controller probe geçen bir model gerekir.
- Local fallback hazır değilse `provider_failover_unavailable` terminal state üretilir. Candidate yoksa worktree temizlenir; candidate varsa deterministic build/verification korunur fakat AI repair tekrar tekrar başarısız remote provider'a gönderilmez.
- Remote circuit breaker aynı run içinde tekrar remote provider'a dönmez. Sonraki yeni run remote-first provider'ı yeniden deneyebilir.
- Local fallback endpoint varsayılan olarak `http://127.0.0.1:11434` kullanır ve `KRALI_LOCAL_OLLAMA_BASE_URL` ile ayrıca değiştirilebilir.

## Local Execution Profile

When Cloudflare failover activates an already-installed local Ollama model, KRALİ now uses a dedicated slow-model execution profile instead of remote inference budgets.

- Local baseline decomposition uses compact task context, an 800-token planning budget and up to 210 seconds for a structured plan.
- The decomposer timeout clamp allows up to 300 seconds for explicitly configured local profiles.
- Local fallback controller selection tries known lightweight controllers first, then up to four already-installed models ordered by model size, and only then falls back to the coding model.
- No model is installed or downloaded during this selection.
- Local coding requests receive a 180-second base timeout; implementation requests may use up to 240 seconds and structured continuation up to 240 seconds.
- Single-task local fallback watchdog is 15 minutes; Developer Task Graph local fallback watchdog is 25 minutes.
- Local fallback reduces redundant inspection budget and allows only one request-timeout retry before escalation/continuation.
- The local coding model is kept warm for 15 minutes and receives an 8K context cap to avoid repeated model reload/context expansion overhead.
- The local system prompt explicitly prefers checkpoint evidence and immediate minimal mutation once required source evidence is satisfied.

