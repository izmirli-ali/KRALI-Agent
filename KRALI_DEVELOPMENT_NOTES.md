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


## v0.10.11 progress

- v0.10.10 updater build failure fixed: `startNextLearningJobIfNeeded()` and `runDeveloperAgent()` referenced init-local `launchAppVersion`, which was out of scope during Swift compilation.
- Added class-level `currentAppVersionString` computed property and routed both active-run guards through it.
- Duplicate `AgentDeveloperBridge.estimatedRemainingRange` switch literals cleaned up to remove compiler warnings from repeated local-agent states.
- No rollback of v0.10.10 immutable Learning evidence binding or per-run Developer Agent isolation.
- VERSION 0.10.11 / build 184.


## v0.10.12 progress

- Application resolver failure trace artık her top candidate için alias provenance kaydediyor: path basename, Finder display name, URL localized name, localized InfoDictionary ve localization-specific InfoPlist.strings kaynakları.
- Resolver trace modeli geriye uyumlu tutuldu; eski trace dosyalarında provenance alanı yoksa decode bozulmuyor.
- Developer Agent runtime evidence, provenance kayıtlarını kompakt biçimde immutable Learning brief içinden taşıyor.
- Root-cause scoring ve deterministic verifier artık alias producer ile merge/dedupe aggregator'ı ayırıyor.
- Runtime provenance istenen localized alias'ın hiçbir upstream kaynaktan üretilmediğini gösteriyorsa `mergedAliases` / `mergeCandidates` root cause olarak reddediliyor.
- `localizedBundleAliases` gibi gerçek localization producer hedefleri alias/localization failure class'ında daha yüksek öncelik alıyor.
- Deterministic guard tam resolver trace'i parse ediyor; modellere yalnız küçük provenance özeti veriliyor, mutation context tekrar şişmiyor.
- Native Ollama / SDK çıktısının ana Developer loguna ikinci kez eklenmesine neden olan çift log append kaldırıldı.
- VERSION 0.10.12 / build 185.


## v0.10.13 progress

- Alias/localization provenance gap aktifken Developer Agent dependency traversal artık ilk birkaç wrapper fonksiyonunda kesilmiyor; üç hop / daha geniş scan budget ile producer kaynaklarını arıyor.
- Discovery önce daha geniş dependency graph'ı tarıyor, sonra alias/localization producer sembollerini neighborhood'un başına taşıyor; global candidate limiti producer'lar görülmeden dolmuyor.
- Root-cause verifier artık provenance upstream alias'ın hiç üretilmediğini kanıtladığında `bestApplicationCandidate`, decision/ranking/scoring, merge ve LaunchServices gibi downstream consumer katmanlarını causal mutation target olarak deterministic biçimde reddediyor.
- Producer adayları provenance gap'te ek deterministic score alıyor; downstream consumer adayları aşağı itiliyor.
- Root-cause ranking modeli timeout/abort ile sonuç üretmezse ve deterministic shortlist'te yeterince güçlü producer kanıtı varsa producer doğrudan verifier'a taşınıyor. Verifier PASS olmadan mutation yetkisi yine verilmiyor.
- Ranking modeli downstream adaylar döndürse bile güçlü producer diagnosis verifier sırasının başına alınıyor.
- Uygulama adına özel alias veya çeviri hard-code eklenmedi.
- VERSION 0.10.13 / build 186.


## v0.10.14 progress

- Application resolver deterministic metadata/LaunchServices/fuzzy katmanları başarısız olduğunda yalnız son fallback olarak generic cross-language semantic application alias resolution devreye giriyor.
- Semantic resolver Apple Foundation Models / SystemLanguageModel üzerinden yalnız kurulu candidate listesi içinde seçim yapabiliyor; listede olmayan uygulama üretemiyor.
- Seçim iki aşamalı: semantic candidate selection + bağımsız semantic equivalence verifier. İki aşama da en az 0.86 güven vermeden candidate kabul edilmiyor.
- Semantic eşdeğerlik yalnız çeviri/lokalizasyon/yerleşik alternatif ad için kabul ediliyor; kategori/işlev/üretici benzerliği yeterli sayılmıyor.
- Uygulama adına özel sözlük veya hard-code eklenmedi.
- Semantic fallback sonucu application-resolution Mentor trace'ine selection/verification confidence, selected candidate, provider availability ve accepted/rejected reason ile kaydediliyor.
- Immutable Learning / Developer Agent resolver evidence sıkıştırması semanticResolution alanını da koruyor.
- Semantic candidate kabul edilse bile mevcut gerçek foreground/ScreenCaptureKit doğrulaması değişmeden zorunlu kalıyor.
- VERSION 0.10.14 / build 187.


## v0.10.15 progress

- Semantic application resolver artık tüm kurulu uygulamaları tek dev prompt'a vermiyor; candidate havuzunu küçük batch'lere bölerek tarıyor.
- Batch seçim prompt'larından kopyalanabilir örnek JSON değerleri kaldırıldı; model alan değerlerini girdiden üretmek zorunda.
- Placeholder/template echo çıktıları deterministic olarak geçersiz sayılıyor.
- Batch finalist eşiği yalnız aday toplamak için kullanılıyor; finalistler her durumda ayrı final semantic selection çağrısından geçiyor.
- Final selection ve bağımsız verifier için yüksek güven eşiği korunuyor; iki aşama da geçmeden uygulama candidate kabul edilmiyor.
- Semantic trace artık stage, evaluatedBatchCount ve finalistCount alanlarını kaydediyor.
- Stage örnekleri: selection_template_echo, scan_no_match, finalist_inconclusive, verifier_invalid_output, verifier_rejected, accepted.
- Developer Agent immutable resolver evidence bu stage ve sayaçları da koruyor.
- Uygulama adına özel sözlük/hard-code eklenmedi; foreground/ScreenCaptureKit gerçek doğrulaması değişmeden zorunlu.
- VERSION 0.10.15 / build 188.


## v0.10.16 progress

- Semantic application çözümleme rolü ayrıldı: Apple Foundation Model artık kurulu uygulamalar arasından candidate seçmiyor; yalnız kullanıcıdaki uygulama adının aynı kavramı ifade eden güvenli dilsel/lokalize arama varyantlarını üretiyor.
- Variant producer en fazla 8 isim üretir, özgün kullanıcı ifadesini korur ve anlam açık olduğunda İngilizce kanonik karşılığı da üretebilir; benzer kategori/işlev/üretici isimleri yasaktır.
- Üretilen varyantlar LaunchServices + mevcut deterministic alias scoring/decision zincirinden geçirilir. Gerçek kurulu uygulama seçimi tamamen deterministic kalır.
- Birden fazla deterministic eşleşme varsa candidate URL bazında tekilleştirilir; score ve variant sırasına göre deterministik seçim yapılır.
- Seçilen gerçek candidate bağımsız semantic equivalence verifier'dan geçmeden kabul edilmez; verifier confidence >= 0.86 zorunludur.
- Foreground/ScreenCaptureKit doğrulaması değişmeden zorunlu kalır.
- Mentor semanticResolution trace artık generatedVariants, deterministicMatchCount ve selectedVariant alanlarını da taşır.
- Developer Agent immutable resolver evidence aynı yeni alanları korur.
- scan_no_match / cross-language semantic miss durumunda yalnız case/diacritic normalization yapan normalized() fonksiyonu deterministic olarak root-cause mutation target olmaktan çıkarıldı.
- Developer Agent applicationNameVariants / semantic variant producer sembollerini alias producer sınıfında önceliklendirebilir.
- Uygulama adına özel sözlük/hard-code eklenmedi.
- VERSION 0.10.16 / build 189.


## v0.10.17 progress

- Claude incelemesiyle ortaya çıkan deterministic alias scoring bug'ı doğrulandı: candidate alias token'larına Türkçe suffix stripping uygulanması arbitrary-language metadata üzerinde yapay formlar üretebiliyordu (ör. canonical son `e` harfinin ek sanılması).
- `bestAliasScore` artık asimetrik çalışıyor: kullanıcı target token'ları Türkçe çekim çözümü için `wordVariants` kullanmaya devam ederken candidate alias tarafı yalnız gerçek normalize edilmiş alias ve gerçek token'ları kullanıyor.
- Runtime'a uygulama adına özel mapping/hard-code eklenmedi.
- Training Lab'e `candidate-alias-suffix-isolation` regression senaryosu eklendi. Test, candidate alias'ın yapay exact forma dönüştürülmediğini ve Türkçe çekimli kullanıcı girdisinin hâlâ exact çözüm ürettiğini birlikte doğruluyor.
- Mentor regression freshness raporu VERSION=0.10.17 için Training/Arena/Live Eval suite'lerinin hâlâ 0.8.27 olduğunu açıkça stale olarak işaretliyor.
- VERSION 0.10.17 / build 190.


## v0.10.18 progress

- Strict Approval Mode kullanıcı talebi doğrultusunda aktif hale getirildi.
- `desktop.app`, `system.open.url`, `files.reveal`, `desktop.control`, `browser.control`, `premiere.control`, `photoshop.control`, `mail.work`, `files.write.text`, `files.move.reversible` kullanıcı onayı olmadan çalıştırılamaz.
- Salt-okunur reasoning/context/screen observation ve statik `research.web` kullanıcı cihazında görünür/kalıcı işlem yapmadığı için otomatik kalır.
- Chat içindeki task approval card çözülen hedefi gösterir. Desktop uygulama onayı path + bundle kimliğiyle sabitlenir; onay sonrası aynı hedef dışında uygulama açılamaz.
- Outcome Solver'ın otomatik `openURLAndObserve` fallback'i approval-aware resume eklenene kadar fail-closed durumuna alındı; kullanıcı onayı olmadan URL açamaz.
- v0.10.16 semantic app promptlarında kaçan Swift interpolation bug'ı düzeltildi. Foundation Models artık literal `(trimmedQuery)` değil gerçek sorgu/candidate değerlerini görür.
- Üretilen semantic app varyantları önce bağımsız equivalence gate'ten geçer; identity dışındaki varyantlarda confidence >= 0.94 zorunludur.
- Semantic varyantlar installed candidate listesine yalnız exact normalized alias eşleşmesiyle bağlanır; fuzzy/prefix candidate selection kaldırıldı.
- Final semantic candidate verifier eşiği >= 0.94'e yükseltildi; aynı kategori/işlev benzerliği açıkça eşdeğerlik sayılmaz.
- KRALİ'nin kendi bundle'ına alakasız semantic sorgudan yönelme `self_target_blocked` guard ile reddedilir.
- Training Lab'e `semantic-app-exact-alias-safety` ve `strict-external-action-approval` regression senaryoları eklendi.
- VERSION 0.10.18 / build 191.


## v0.10.19 progress

- Strict Approval preflight artık hedef kimliği çözülmeden onay kartı üretmez. `desktop.app` için en az name + path gerekir; hedef çözülemezse görev dış işlem yapmadan güvenli şekilde durur.
- AgentLocalIntelligence içine kurulu uygulama listesine bakmayan ayrı bir `localizedApplicationCanonicalNames` katmanı eklendi. Bu katman yalnız lokalize UI/display-name ifadesinin İngilizce kanonik dilsel karşılığını üretir; uygulama seçmez.
- Generic variant resolver ile localization translator birbirinden bağımsız çalışır. Her ikisinin güvenli çıktıları birleştirilir; biri başarısız olsa diğeri resolution zincirini sürdürebilir.
- Localization/variant çıktıları yine bağımsız semantic equivalence verifier (>=0.94), exact normalized installed alias eşleşmesi ve final candidate verifier (>=0.94) kapılarından geçer.
- Candidate listesi localization modeline verilmez; modelin kurulu uygulamalar arasından tahmin/selection yapmasına izin verilmez.
- Pending/approved/rejected task approval hedefi Mentor trace içinde `approvalAudit` olarak kaydedilir: capability, target summary, app name, bundle ID, path ve karar.
- Training Lab'e `resolved-target-required-before-approval` regression senaryosu eklendi.
- VERSION 0.10.19 / build 192.


## v0.10.20 progress

- Semantic application resolution artık provenance-aware.
- İsim adayları güvenlik sırasıyla birleştirilir: source query → localization → generic variant. Aynı canonical isim birden fazla kaynaktan gelirse localization provenance generic variant'a tercih edilir.
- Localization kaynağından gelen bir isim kurulu uygulama kataloğunda tam olarak tek exact alias eşleşmesine sahipse redundant ara `verifyApplicationNameVariant` çağrısı yapılmaz; aday doğrudan mevcut final candidate verifier'a gider.
- Bu optimizasyon güvenlik eşiğini düşürmez: localization adayı exact installed alias ile tekil eşleşmek zorunda ve final `verifyApplicationAliasEquivalence` yine confidence >= 0.94 gerektirir.
- Generic variant kaynağındaki non-identity isimler mevcut ara equivalence verifier >= 0.94 kontrolünü korur.
- `ApplicationSemanticResolutionTrace` artık her isim adayı için provenance, intermediate verification stage/confidence, exact match count ve exact bundle ID listesini `variantDiagnostics` altında kaydeder.
- Training Lab'e `semantic-localization-provenance-priority` regression senaryosu eklendi.
- VERSION 0.10.20 / build 193.


## v0.10.21 progress

- Runtime capability gap çözümlemesi artık approval state-aware.
- `resolveRuntimeFailures` yeni `approvedStepIndexes` bağlamını alır.
- Henüz kullanıcı onayı verilmemiş `requiresApproval` step runtime failure sayılmaz ve Learning/Developer hattına yanlış eskalasyon üretmez.
- Kullanıcı tarafından onaylanmış fakat tamamlanmamış/postcondition doğrulanmamış step artık gerçek runtime failure olarak değerlendirilir ve root capability gap'e eskale edilebilir.
- AgentEngine normal semantic execution ve approval sonrası resume akışlarında `approvedRuntimeStepIndexes` bilgisini GapResolver'a taşır.
- Runtime gap reason, approval gereken bir step gerçekten onaylandıysa bunu provenance olarak `kullanıcı onayı verildi` şeklinde kaydeder.
- `runtime-provider-failure-escalation` regression testi hem unapproved/no-gap hem approved/failure-gap durumunu birlikte sınar.
- `task-graph-external-commit-approval` testi mevcut Strict Approval politikasına güncellendi: mail.read, mail.draft ve mail.send onay ister; iç reasoning istemez.
- Desktop app localization/resolver zincirine dokunulmadı.
- VERSION 0.10.21 / build 194.


## v0.10.22 progress

- Developer Tools için fiziksel/sistem etkili eylemler ayrı approval boundary arkasına alındı.
- Training Lab ve KRALİ Arena simulation-only olarak çalışır; gerçek desktop/provider execution yapmaz. UI durum metinleri bunu açıkça gösterir.
- Desktop Control Probe artık Notlar uygulamasını doğrudan açmaz. Chat içinde `PendingDeveloperToolApproval` kartı oluşturur; onay verilmeden fiziksel probe başlamaz.
- Developer Agent varsayılan olarak restricted system mode ile başlar. Kod okuma/değiştirme, worktree, build ve regression gibi developer-sandbox işlemleri çalışabilir.
- Homebrew Node kurulumu, Ollama kurulum/güncelleme, Ollama servis başlatma, model indirme, Cline global onarım/kurulum ve Cline/OpenAI auth Terminal akışı onaysız çalışmaz.
- Sistem etkileri blanket izin kullanmaz. Her fiziksel adım ayrı scoped token ile onaylanır; bir adımın onayı sonraki sistem adımına taşınmaz.
- Scoped approval token süreç içinde tek kullanımlıdır; aynı token ikinci fiziksel/system-effect çağrısını otomatik yetkilendirmez. Cline SDK yerel paket indirmesi de bu gate kapsamındadır.
- Sistem etkisi gerektiğinde Developer Agent job'u failed sayılmaz; güvenli biçimde approval bekler. Reddedilirse fiziksel işlem uygulanmaz, learning job capability failure sayılmadan queued kalır ve otomatik yeniden başlatılmaz.
- `developer-tools-physical-approval-policy` Training regression'ı eklendi.
- Mevcut semantic task Strict Approval ve desktop.app localization/resolver zincirine dokunulmadı.
- VERSION 0.10.22 / build 195.


## v0.10.23 progress

- Assistant UI polish sürümü; agent karar mantığı, resolver, provider ve Strict Approval semantiğine dokunulmadı.
- Aktif sohbetin altında kullanıcı dostu durum şeridi eklendi: hazır, çalışıyor, onay bekliyor, doğrulandı, kısmi ve dikkat durumları.
- Task ve Developer approval kartları fiziksel/sistem etkisini daha açık anlatacak şekilde sadeleştirildi; işlem uygulanmadan önceki güvenli durum görünür hale getirildi.
- Inspector `Özet / Developer` olarak iki görünüme ayrıldı. Normal kullanımda teknik gürültü azaltıldı; debug, bağlam, learning queue ve geliştirici araçları Developer görünümünde tutuldu.
- Inspector özetine Training/Core/North Star sayılarını ve bilinen açık sayısını gösteren Sistem Sağlığı kartı eklendi.
- VERSION 0.10.23 / build 196.


## v0.10.24 progress

- Desktop app activation sonucu ile gerçek foreground postcondition doğrulaması ayrıldı; API aktivasyon sonucu artık tek başına PASS/FAIL belirlemiyor.
- Normal chat `desktop.app` yolu ile Desktop Control Probe arasındaki verification standardı yakınlaştırıldı.
- Foreground kanıtı generic olarak NSWorkspace, Accessibility (AX), ScreenCaptureKit ve structured Screen Perception kaynaklarından birleştiriliyor.
- `focusCandidate` tarafından bulunan NSWorkspace foreground kanıtı artık çöpe atılmıyor.
- Screen Perception fallback yalnız semantic özet üretmekle kalmıyor; structured `frontmostApplication` hedef uygulamayla eşleşiyorsa postcondition kanıtına katılıyor.
- Mentor/runtime status satırı activation, workspace, AX, ScreenCaptureKit, ScreenPerception ve final foreground sonuçlarını ayrı ayrı raporluyor.
- `desktop-foreground-evidence-fusion` fiziksel eylem yapmayan Training regression senaryosu eklendi.
- Resolver, Strict Approval, UI ve provider selection mantığı değiştirilmedi.
- VERSION 0.10.24 / build 197.


## v0.10.25 progress

- AX (Accessibility) artık bağımsız foreground doğrulama kaynağı değildir; yalnız uygulamayı öne getirmeye yönelik recovery/actuator adımıdır.
- `DesktopForegroundVerificationEvidence.frontmostVerified` yalnız bağımsız observation kaynaklarından PASS üretir: NSWorkspace, ScreenCaptureKit veya structured Screen Perception.
- `activate=true` veya AX recovery tek başına başarı sayılmaz.
- Runtime/Mentor status `axRecovery=` olarak raporlar; AX artık `source=` listesine girmez.
- `desktop-foreground-evidence-fusion` regression'ı yeni güven modeline güncellendi.
- Yeni `desktop-ax-recovery-is-not-proof` regression'ı: activation=true + AX recovery=true olsa bile bağımsız observation yoksa foreground=false olmalı.
- Resolver, Strict Approval, UI ve provider selection değiştirilmedi.
- VERSION 0.10.25 / build 198.


## v0.10.26 progress

- Cursor CLI, yerel Developer Agent'ın yerine geçmeyen read-only `Cursor Architect` escalation provider olarak eklendi.
- Tetikleme yalnız diagnosis başarısızlıklarında: iteration limit, root-cause inconclusive, strategy escalation inconclusive ve tool-protocol failure.
- Cursor çağrısı `--mode=ask --print --sandbox enabled` ile yapılır.
- Geçici worktree policy: `workspace_readonly`; Write/Shell/WebFetch/MCP açıkça deny edilir.
- Bridge explicit Cursor API key/auth-token environment yollarını kaldırır; yalnız kullanıcının mevcut `agent login` oturumunu kullanır.
- Cursor hiçbir mutation/candidate/commit/push üretmez; yalnız structured diagnosis yazar.
- Aynı VERSION + gap diagnosis tekrar kullanılır; aynı probleme tekrar Cursor kotası harcanmaz.
- Cursor diagnosis sonraki Developer Agent prompt'una advisory/hypothesis olarak eklenir ve source/runtime evidence ile bağımsız doğrulama zorunludur.
- Mentor Sync artık `Mentor/cursor-architect-latest.json` dosyasını da taşır.
- CI, `cursor-architect-bridge.mjs --self-test` ile read-only güvenlik sözleşmesini doğrular.
- Cursor bulunamaz, login hazır olmaz veya ücretsiz quota biterse yerel Qwen/Devstral yolu değişmeden devam eder.
- VERSION 0.10.26 / build 199.


## v0.10.27 progress

- Cursor Architect escalation artık `local_agent_completion_gate_failed` durumunu da kapsıyor; yerel Developer Agent aktif gap için gerçek candidate üretemeden açıklamayla bitmeye çalışırsa read-only ikinci görüş alınabiliyor.
- v0.10.26 Cursor diagnosis cache fingerprint çağrısındaki eksik argüman düzeltildi; aynı VERSION + gap + failure evidence için hazır teşhis gerçekten yeniden kullanılabiliyor.
- KRALİ'nin geliştirme ekibinde kontrollü junior developer olarak görev alması için `developerTask` envelope ve `Scripts/run-developer-task.command` eklendi.
- İlk KRALİ developer görevi: `Training Result Analyzer`. Core/North Star PASS/FAIL, stale version ve önceki koşuya göre regression/fix delta raporu üretecek; core runtime/approval/planner dosyalarına dokunması yasak.
- Supabase geçişi için `Cloud/Supabase/control-plane-schema.sql` eklendi. Learning jobs, developer runs, training/scenario history, capability failures, skill library ve agent events için RLS-temelli standart Postgres şeması hazırlandı.
- Cloud geçişi fail-open değil: credential/bağlantı eklenene kadar hiçbir runtime state buluta taşınmıyor; local Mac authoritative executor olarak kalıyor.
- Hedef dağılım: Mac=approval/execution, Supabase=control plane/state, GitHub=source/CI, Cursor=read-only architect; ileride kendi sunucusu aynı backend sözleşmesini devralabilecek.
- VERSION 0.10.27 / build 200.


## v0.10.28 progress

- Kontrollü KRALİ developer task'ları artık Terminal zorunluluğu olmadan sohbetten başlatılabilir.
- Explicit generic komut: `geliştirici görevi: <task adı veya task id>`.
- Task resolver `DeveloperAgent/Tasks/*.json` içinden filename, capabilityID veya capabilityName ile eşleşir; Training Result Analyzer'a özel hard-code yoktur.
- Sohbetten başlatılan task `AgentEngine → AgentDeveloperBridge → run-developer-agent.command` zincirini kullanır.
- `KRALI_DEV_TASK_FILE` Engine/Bridge üzerinden taşınır; task mutation scope runner içinde yeniden okunup native mutation tool katmanına export edilir.
- Developer Agent sistem etkisi isterse task descriptor approval beklerken korunur; kullanıcı onayından sonra aynı task ve aynı scope ile devam edilir.
- Böylece Ollama service start/model install gibi sistem etkileri KRALİ sohbetinde Developer Tool approval kartı üretir.
- Terminal `run-developer-task.command` yolu fallback/manual kullanım için korunmuştur.
- VERSION 0.10.28 / build 201.


## v0.10.29 progress

- Developer Agent compute remote-first tasarıma geçti.
- Cloudflare Workers AI için local Ollama-compatible proxy eklendi; mevcut safe tool/worktree/mutation controller mimarisi yeniden kullanılmaya devam ediyor.
- Remote config mevcutsa Ollama servisi ve ağır local model hazırlığı tamamen atlanıyor.
- Varsayılan remote main model: GLM-4.7-Flash; structured JSON controller: Llama 3.3 70B FP8 Fast.
- Cloudflare token yalnız macOS Keychain'de saklanır; config dosyasında yalnız account ID ve model adları vardır.
- Remote hazır değilse local fallback artık 24B/14B cache'i tercih etmiyor; Qwen 7B/8B sınıfı öncelikli.
- local_agent_watchdog_timeout artık Cursor Architect ikinci görüşüne uygun failure state.
- Supabase RLS şeması authenticated owner modeli + explicit Data API grant/revoke ile sıkılaştırıldı.
- Supabase client config modern publishable-key modeline hazırlandı; live project henüz seçilmedi/bağlanmadı.
- VERSION 0.10.29 / build 202.
