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
