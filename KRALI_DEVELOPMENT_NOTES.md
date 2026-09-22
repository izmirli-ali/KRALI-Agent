# KRALİ Development Notes

## Product direction

KRALİ büyüdükçe tek dosya / tek store / her veriyi sürekli bellekte tutan bir yapıdan uzaklaşacak. Yeni varsayılanlar:

- Modüler sınırlar: UI, conversation, memory, capability, diagnostics ve developer-agent ayrı sorumluluklar taşımalı.
- Bounded memory: Diskte kalıcı olabilen veri RAM'de sınırsız tutulmamalı.
- Lazy loading: Geçmiş, diagnostics ve indeksler yalnız ihtiyaç olduğunda yüklenmeli.
- Observable evidence: Eylem başarıları gerçek gözlem ile doğrulanmalı.
- Generic providers: Uygulama/marka adına hard-code yerine capability/provider stratejileri kullanılmalı.
- Safe autonomy: KRALİ candidate branch/worktree'de geliştirebilir; ana branch'e doğrudan self-modification yapmamalı.

## Current findings

1. `ContentView.swift` chat, status, context, sources, diagnostics ve developer tools'u tek görünümde topluyor. UI modüllere ayrılmalı.
2. `AgentEngine.swift` çok fazla servis ve UI state taşıyor. Uzun vadede coordinator + feature stores/view-models yapısına bölünmeli.
3. Chat mesajları artık ConversationStore ile kalıcı ve bounded tutuluyor; aktif sohbet restart sonrası geri yükleniyor.
4. Context memory tek JSON store kullanıyor fakat zaten bounded: en fazla 30 user rule + 40 task/research entry. Bu yüzden ilk performans darboğazı değil.
5. Diagnostics ve ağır geliştirici state'leri normal sohbet akışından ayrılmalı ve ihtiyaç anında yüklenmeli.
6. Seçili çalışma klasörü indeksleri başlangıçta ağırlaşırsa lazy/background indexing'e taşınmalı.
7. Developer Agent tarafında adaptive timeout, resumable context ve hızlı capability training kuyruğu ayrıca geliştirilecek.

## Conversation retention policy

- Kullanıcı ve assistant konuşmaları geçmiş olarak korunur.
- Aktif sohbet RAM'de sınırlı tutulur.
- Eski mesajlar silinmek yerine arşiv segmentlerine taşınır.
- Debug/diagnostic logları normal sohbet geçmişine dahil edilmez.
- Düşük değerli tekrarlar ve geçici sistem kayıtları gerektiğinde temizlenebilir.
- Kullanıcıya ait gerçek konuşma geçmişi otomatik olarak agresif biçimde silinmez.
- İleride manuel konuşma silme / arşiv yönetimi eklenecek.

## Planned phases

### Phase 1 — Conversation Foundation ✅
- Chat history'i `AgentEngine` içinden ayır.
- Kalıcı conversation store ekle.
- Aktif RAM penceresini bounded tut.
- Eski mesajları arşiv segmentlerine taşı.
- Restart sonrası konuşma devam etsin.

### Phase 2 — Modern Assistant UI — in progress
- Sol conversation/history sidebar.
- Merkezde sade chat transcript.
- Alt composer sabit ve modern.
- Sağ taraftaki teknik paneller varsayılan olarak gizli/secondary inspector olsun.
- Mentor / developer / diagnostics normal chat yüzeyini kalabalıklaştırmasın.

### Phase 3 — Engine Modularization — in progress
- `AgentEngine` yalnız orchestration/coordinator rolüne indirgensin.
- Conversation, memory, capability, execution, diagnostics ve developer-agent state'leri ayrı modüllere taşınsın.
- Feature modülleri bağımsız test edilebilir hale gelsin.

### Phase 4 — Storage & Performance — in progress
- Büyük veri setleri için lazy load / paged access.
- Gerekirse JSON store'lardan indeksli yerel store'a geçiş.
- File indexing açılış yolundan çıkarılsın.
- Diagnostics ve Mentor trace'leri isteğe bağlı yüklensin.

### Phase 5 — Cleanup
- Kullanılmayan/dead code statik olarak tespit edilmeden silinmesin.
- Tekrarlanan yardımcılar birleştirilsin.
- Legacy fallback'ler regression testi sonrası kaldırılmalı.
- Geçici dosya, cache ve debug log retention politikası uygulanmalı.

### Phase 6 — Autonomous Training
- Capability curriculum / backlog.
- KRALİ belirli capability'leri candidate branch'te kendi geliştirir.
- Build + regression + runtime probe + Mentor kanıtı üretir.
- İnsan yalnız diff/test/Mentor sonucunu inceler.


## v0.8.58 progress

- Workspace indexing moved into `AgentWorkspaceIndexer`.
- Restored workspace path no longer triggers a 5000-item scan at app launch.
- Workspace index is cached and reused until a real file mutation invalidates it.
- Diagnostic report loading moved into `AgentDiagnosticsLoader`.
- Training / Arena / Screen / Desktop diagnostic JSON files are loaded only when Inspector is opened, except when a prior `no_change` decision requires immediate validation.
- Legacy in-engine screenshot filename detection was removed after the indexer became the sole owner.


## v0.8.59 progress

- Diagnostic / Developer Agent / learning queue presentation state moved out of `AgentEngine` into `AgentInspectorState`.
- Inspector state changes are forwarded to the existing UI observation path without changing task execution behavior.
- Primary Learning card now shows only active queue jobs, the current task's learning plans, and current/reviewable Developer Agent status.
- Stale Developer Agent sessions and old capability backlog entries no longer dominate the normal Inspector surface.
- Historical learning data is preserved in storage; this change only reduces default UI noise.


## v0.8.60 progress

- Replaced substring-based filename query cleanup with token-based `AgentFileQueryParser`.
- File search now separates location/scope words from actual filename terms.
- Desktop / Downloads / Documents / whole-computer intent is parsed independently from filename query.
- Scope mismatches no longer silently search the wrong selected workspace.
- Inflected Turkish file/type words are removed at token level without corrupting action words such as `bul`.
- Added Training Lab regression coverage for Desktop scope, Downloads+PDF scope, and the historical `bu` / `bul` substring bug.


## v0.8.61 — File Intelligence foundation

- File tasks now share one structured intent model across Brain, Engine and Verifier.
- Added `AgentFileTypeRegistry` for explicit extensions, common archive/audio/spreadsheet/font families and Turkish inflected extension tokens.
- Added `AgentFileSearchCoordinator` with root-aware 45-second read-only index caching.
- Desktop, Downloads and Documents can be searched directly as explicit read-only scopes without changing the selected write workspace.
- File search returns typed `AgentFileSearchOutcome` instead of relying only on response strings.
- Verifier consumes typed file-search outcomes and no longer depends only on brittle exact-word checks such as `dosya` vs `dosyalarını`.
- Filename terms, scope, extensions, dates and legacy category filters are applied as separate dimensions.
- Whole-Mac search remains an explicit safe boundary until a scalable index exists.
- Write/move behavior remains limited to the selected workspace and existing confirmation rules.


## v0.8.62 — Problem Solver Core

- Added `AgentProblemSolver` as a solution-oriented layer between task understanding and Learning.
- KRALİ now frames the objective, observations, constraints and blocked capabilities before escalating.
- Multiple strategy candidates can be generated from existing capabilities instead of assuming one provider = one task.
- Safe generic alternatives include evidence reuse, screen observation, generic app workflow, public web research and reasoning transforms.
- Blocked capabilities with an executable generic strategy no longer create an immediate initial Learning gap.
- Runtime failures can trigger reflection and an untried safe strategy before capability learning.
- Deterministic tasks also receive a Problem Solver frame; this is not limited to semantic missions.
- Contradictions such as "workspace observed folders but primary folder search returned zero" can recover from already-verified evidence instead of declaring a new capability gap.
- Learning plans are filtered after Problem Solver checks whether the current capability set can already solve the problem.
- Mentor traces now store problem resolution, candidate strategies, chosen strategy and reflection summary.
- Developer briefs explicitly require problem definition, multiple candidate solutions and generic capability-level fixes before source-code mutation.
- Training Lab now covers solution-before-learning and reflection-to-next-strategy behavior.

Target flow:
`Goal → Problem Frame → Observe → Strategy Candidates → Choose → Execute → Verify → Reflect → Retry Safe Strategy → Learning Gateway (only if genuinely needed)`


## v0.8.64 — Outcome-Oriented Problem Solving

- Added `AgentOutcomePlanner`.
- KRALİ now separates user outcome/success criteria from instrumental provider steps.
- Public read-only information tasks can be satisfied by `research.web` even when `browser.control` is unavailable.
- Browser/app capabilities used only as tools can be suppressed from Learning when another verified strategy already satisfies the user outcome.
- Real mutation/edit tasks are not allowed to hide behind read-only substitutions; missing edit capability still escalates to Learning.
- Semantic capability gaps and runtime gaps are filtered by outcome coverage.
- Outcome strategies execute before semantic provider steps when they fully cover a non-mutating goal.
- Verifier can PASS on real outcome evidence instead of requiring every originally planned provider step to run.
- Instrumental semantic steps substituted by a better outcome strategy are marked `skipped`, not failed.
- Mentor traces now include `outcomeResolution`: requirements, success criteria, chosen strategies, coverage and suppressed Learning capabilities.
- Training Lab adds regressions for:
  - public information via research.web before browser Learning
  - mutation tasks still requiring a real mutation capability
- Developer Agent request timeout is now adaptive by development phase.
- A single Ollama request timeout no longer kills the run immediately; KRALİ preserves the current message/tool context and retries in-place.
- Default local-agent watchdog increased from 5 to 7 minutes while inspection budget and forced implementation gates remain bounded.

Target flow:
`Goal → Outcome Contract → Success Criteria → Candidate Strategies → Capability Composition → Execute → Verify Outcome → Reflect → Learning only if uncovered`


## v0.8.65 — Outcome Planner Build Hotfix

- Fixed Swift parser ambiguity in `AgentOutcomePlanner.resolve`.
- Replaced the multiline optional binding ending in `.first {` with an explicit intermediate optional and `if let selected`.
- No behavioral rollback: v0.8.64 outcome-oriented planning, Learning gate and Developer Agent timeout-resume changes remain intact.
- Build 115.


## v0.8.66 — Outcome Strategy Chain

- Outcome execution is now a real ordered runtime chain instead of a one-shot preferred strategy.
- Each outcome strategy attempt is recorded as succeeded/failed/skipped with evidence summary and executed capability IDs.
- Public web-information flow now prefers:
  1. `research.web` with direct-source evidence
  2. `system.open.url + perception.screen`
  3. Learning Gateway only after safe strategies are exhausted.
- Added generic `system.open.url` capability using macOS default URL handling; no Safari/Chrome-specific hard-code.
- Explicit domains/URLs are resolved into direct research candidates before generic search-engine discovery.
- Domain/site phrases are rejected as application names while explicit application targets such as Safari remain valid.
- Static web research does not enqueue browser Learning while Outcome Strategy Chain still has an untried safe strategy.
- If all safe outcome strategies fail at runtime, an exhausted-outcome capability gap is created with attempt evidence; only then can `browser.control` Learning begin.
- Verifier now uses actual runtime outcome attempts, not merely the originally chosen strategy.
- Mentor traces now include `outcomeAttempts`, making strategy order and failure/success reasons visible.
- Added Training Lab regressions for direct domain resolution, strategy-chain ordering, web/app target isolation and exhausted-outcome Learning escalation.
- VERSION 0.8.66 / build 116.

Target runtime:
`Outcome → Strategy 1 → evidence? → Strategy 2 → evidence? → ... → Verify → Learning only after exhaustion`

- Outcome Chain execution ownership is gated to supported runtime strategy classes; unrelated reasoning/file tasks remain on their existing execution paths.


## v0.10.9 progress

- Developer Agent runtime evidence artık `candidate_alias_or_localization_gap_possible` failure class'ında dependency neighborhood'u iki hop'a kadar genişletiyor; alias/localization/scoring producer'ları downstream lookup wrapper'larından önce değerlendirebiliyor.
- Root-cause verifier önüne deterministic contradiction guard eklendi. Runtime trace candidate havuzunda pozitif adaylar varken LaunchServices miss tek başına behavioral root cause kabul edilmiyor; generic “application missing/not returned” açıklaması alias/localization kanıtı olmadan PASS alamıyor.
- Exact mutation payload'ındaki yinelenen verified source kaldırıldı ve problem evidence sınırları küçültüldü.
- İlk ağır mutation-model timeout'unda aynı ağır model ultra-compact modda tekrar denenmiyor; doğrudan hızlı structured controller fallback'ine geçiliyor.
- Verified root cause sonrasında mutation controller timeout olursa checkpoint korunuyor ve aynı diagnosis yeniden başlatılmıyor. Sonraki resume doğrulanmış target'tan devam ediyor.
- Mutation timeout sayısı checkpoint v7 ile kalıcı tutuluyor; resume koşusunda daha önce timeout veren ağır mutation modeli atlanabiliyor.


## v0.10.10 progress

- Learning Queue işleri artık runtime evidence'i iş oluşturulduğu anda immutable snapshot olarak saklıyor. Sonraki kullanıcı komutları aynı capability üzerinde çalışsa bile ilk job'ın goal/runtime/resolver kanıtını ezemiyor.
- Immutable snapshot; source goal, ilgili Mentor runtime hata satırları ve eşleşen application resolver trace JSON'unu birlikte taşıyor.
- Developer Agent bir Learning Queue brief'i aldığında mutable `Mentor/latest.json` ve `application-resolution-latest.json` yerine öncelikle job içine bağlı ilk immutable evidence snapshot'ını kullanıyor.
- Runtime source hint üretimi de aynı primary snapshot'tan yapılıyor; böylece bir job'ın source bootstrap/root-cause zinciri başka bir görevin son Mentor state'iyle karışmıyor.
- Developer Agent logları artık run başına `~/Library/Logs/KRALI-Developer-Agent-Runs/<run-id>.log` altında tutuluyor.
- Mentor sync, `developer-status.txt` içindeki run id ile yalnız aktif run'ın log tail'ini yayımlıyor; iki process'in satırları tek global logda karışmıyor.
- `checking` ve root-cause pipeline'ın ara stage'leri aktif Developer Agent durumu olarak tanınıyor.
- Güncel app sürümünde fresh/active bir Developer Agent run'ı varsa yeni Learning Queue worker veya manuel Developer Agent run'ı başlatılmıyor; yeni job sırada kalıyor.
- VERSION 0.10.10 / build 183.
