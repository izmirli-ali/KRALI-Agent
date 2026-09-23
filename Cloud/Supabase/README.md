# KRALİ Cloud Control Plane Foundation

Amaç: KRALİ'nin güvenlik-kritik macOS executor katmanını yerelde tutarken queue, run state, training history ve skill metadata yükünü zamanla buluta taşımak.

## Hedef dağılım

### Local Mac — authoritative executor
- Approval authority
- Desktop/screen interaction
- File/shell/system mutation authority
- Secrets / Keychain
- macOS runtime verification
- Offline fallback

### Supabase KRALI-Control
- learning_jobs
- developer_runs
- training_runs
- scenario_results
- capability_failures
- skills / skill_versions
- lightweight agent_events

### Supabase KRALI-Lab
- deneysel skill sonuçları
- benchmark/test koşuları
- schema/queue denemeleri
- henüz promote edilmemiş araştırma çıktıları

### GitHub
- source of truth for source code
- candidate branches
- CI/build

## Geçiş ilkesi

İlk bağlantıda Supabase yalnız MIRROR olur. Local state authoritative kalır. Cloud write/read doğrulandıktan ve offline fallback test edildikten sonra Learning Queue gibi seçili state'ler cloud-authoritative hale getirilebilir.

KRALİ uygulamasına service-role/secret key gömülmez. Desktop client publishable key + authenticated user + RLS kullanır. Admin işlemleri ileride güvenilir server/Edge Function katmanına taşınır.

## Sunucuya geçiş hazırlığı

İleride tek bir kendi sunucusu edinildiğinde aynı `ControlPlaneBackend` sözleşmesi Supabase yerine self-hosted Postgres/API ile uygulanabilir. Supabase schema'sı mümkün olduğunca standart Postgres tiplerinde tutulur; vendor lock-in düşük tutulur.

## Aşamalar

1. v0.10.27 — schema + task model + local fallback korunur.
2. v0.10.28 — learning/developer run state mirror.
3. v0.10.29 — training history + skill library mirror/delta.
4. Sonra — queue authority + optional external inference routing.

Bu klasörde secret, project URL veya credential commit edilmez.
