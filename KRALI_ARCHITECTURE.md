# KRALİ — Core Architecture Roadmap

KRALİ'nin hedefi bir komut çalıştırıcı olmak değil; kullanıcının niyetini anlayan, bağlamı koruyan, plan üreten, uygun aracı seçen, sonucu doğrulayan ve zamanla çalışma tercihlerini öğrenen yerel bir kişisel ajan olmaktır.

## North Star — KRALİ neye dönüşecek?

KRALİ sabit modül kalıpları arasında seçim yapan bir panel olmayacak. Nihai hedef, izin verilen dijital ortamda kullanıcının yapabildiği işleri araçlar üzerinden yapabilen; ne yapacağını önceden tek tek programlamak yerine hedefi anlayıp yolu kendisi kurabilen genel amaçlı kişisel bir ajan oluşturmaktır.

KRALİ'nin son durumda sahip olması gereken temel nitelikler:

- **Genel amaçlı akıl yürütme:** yalnızca önceden tanımlı intent eşleşmeleriyle değil, yeni ve daha önce görülmemiş görevleri de hedef–kısıt–alternatif–sonuç ilişkisiyle çözebilmek.
- **Dinamik planlama:** görevleri sabit "modüller" kalıbına zorlamak yerine gerektiği kadar alt göreve bölmek, sıralamayı değiştirmek ve yeni bir plan üretmek.
- **Araç bağımsızlığı:** File Search, Browser, Premiere, Mail veya başka entegrasyonlar KRALİ'nin kimliği değil; yalnızca kullanabildiği araçlardır. Core hangi araca ne zaman ihtiyaç olduğunu kendisi belirler.
- **Araştırma yeteneği:** bilmediğini fark etmek, güvenilir kaynağı seçmek, araştırmak, çelişkileri ayırmak ve yeni bilgiyi mevcut bağlama katmak.
- **İnsan benzeri iş akışı:** gözlemle → düşün → planla → uygula → sonucu kontrol et → gerekiyorsa düzelt. Ama insan gibi davranıyormuş izlenimi vermek için uydurma durum, algı veya yetenek üretme.
- **Kalıcı kimlik ve süreklilik:** adı KRALİ'dir. Geçmiş tercihleri, çalışma bağlamını, projeleri ve uzun vadeli hedefleri uygun bellek katmanlarında korur.
- **Kendi sınırını bilme:** görmediği şeyi gördüğünü, kullanamadığı aracı kullandığını veya doğrulamadığı sonucu doğruladığını söylemez.
- **Yetkinlik genişlemesi:** yeni araç veya beceri eklendiğinde Core'un yeniden yazılması gerekmez; yeni yetenekler ortak capability arayüzüne eklenir ve Planner bunları otomatik kullanabilir.
- **Asistan + ajan birleşimi:** hem konuşabilen ve açıklayabilen gelişmiş bir yapay zeka, hem de izin verilen işleri gerçekten tamamlayan gelişmiş bir asistan olmalıdır.

Bu nedenle "modül" kelimesi KRALİ içinde sabit görev şablonu anlamına gelmez. Modüller yalnızca **capability provider**'dır. Karar verme, görev parçalama ve akıl yürütme Core'a aittir.

### Hedef davranış örneği

Kullanıcı "dünkü çekimleri bul, hangilerinin işe yarayacağını incele, en iyi adayları bir klasörde hazırla ve bana nedenlerini söyle" dediğinde KRALİ'nin bunu önceden yazılmış tek bir komut olarak tanıması beklenmez. Core:

1. "dünkü çekimler" kapsamını çözer,
2. gerekli dosya aramasını yapar,
3. dosya ve ileride görüntü/ses içeriğini değerlendirir,
4. seçim kriterlerini bağlama göre oluşturur,
5. birkaç alternatif üretir,
6. geri döndürülebilir dosya işlemi gerekiyorsa güvenli plan kurar,
7. uygular,
8. sonucu tekrar kontrol eder,
9. kullanıcıya karar gerekçesini ve sonucu açıklar.

Amaç, "hangi modülü çağırayım?" diyen bir sistem değil; **"bu hedefe en iyi nasıl ulaşırım?"** diye çalışan bir sistemdir.

## Tasarım ilkesi

Geliştirme sırası özellik sayısına göre değil, zeka iskeletine göre ilerler:

1. **Understanding** — doğal dili normalize et, niyet ve hedefi ayır.
2. **Context** — önceki konuşma, son arama ve aktif çalışma alanını koru.
3. **Principles** — güvenlik sınırları ve değişmez davranış kuralları.
4. **Planner** — tek komut yerine hedefe ulaşmak için alternatif planlar üret.
5. **Capability Router** — görevi sabit modüllere sıkıştırmadan, mevcut yetenekler arasından gereken araçları dinamik olarak seç.
6. **Executor** — izin verilen yerel işlemleri uygula.
7. **Verifier** — yapılan işin gerçekten tamamlandığını kontrol et.
8. **Memory / Learning** — açık kullanıcı tercihlerini ve tekrar eden çalışma kurallarını sakla.
9. **Multimodal / Tools** — görüntü, ses, tarayıcı, Premiere, mail, masaüstü etkileşimi ve gelecekteki yetenekler Core'a capability olarak eklenir.

## Neden bu sıra?

Modern genel amaçlı yapay zeka sistemlerinde temel yetenek ile kullanıcıya uyum ayrı katmanlar olarak gelişti. Dil modellerinde önce genel temsil ve dil yeteneği, sonra talimat izleme ve diyalog uyumu güçlendirildi. Başka sistemlerde açık davranış ilkeleri, çok modlu girişler, araç entegrasyonları, bellek ve planlama ayrı katmanlar olarak eklendi.

KRALİ de aynı nedenle önce araç sayısını artırmayacak. Önce Core doğru bağlamı ve hedefi taşıyacak; araçlar daha sonra bu çekirdeğe takılacak.

## KRALİ Core sözleşmesi

Her kullanıcı mesajı şu akıştan geçmelidir:

```
Input
  → Understanding
  → Context
  → Goal
  → Principles
  → Planner / Alternatives
  → Capability Router
  → Capability Gap Check
  → Research / Learn (gerekiyorsa)
  → Execute
  → Verify
  → Response
  → Learn
```

## Değişmez güvenlik ilkeleri

- Kullanıcı tarafından seçilmemiş alanda yazma işlemi yapma.
- Silme gibi geri döndürmesi zor işlemleri varsayılan olarak yapma.
- Dosya taşıma / değiştirme öncesinde planı göster ve gereken durumda onay al.
- Çakışan dosya adlarında üzerine yazma.
- Gerçek işlemden sonra sonucu doğrula.
- Bağlantısı olmayan bir aracı varmış gibi gösterme.
- Kullanıcının son bağlamını kaybetmeden yeni mesajı yorumla.
- Modül seçimini kullanıcıya yükleme; Core kendisi yönlendirsin.
- Yeni görevleri yalnızca anahtar kelime / sabit intent kalıplarına uydurmaya çalışma.
- Araç isimlerini planın merkezi yapma; önce hedefi ve gerekli yeteneği düşün.
- Kullanıcının yapabildiği bir dijital işi teknik olarak yapabilmek uzun vadeli hedeftir; erişim, izin ve güvenlik sınırları ayrıca korunur.

## Sürüm aşamaları

### 0.6.x — Foundation
Yerel dosya algısı, güvenli aksiyonlar, intent, tarih çözümleme, bağlam ve temel planning.

### 0.7.x — Planner + Verifier
Çok adımlı görev planları, alternatif yol, işlem sonrası doğrulama ve başarısızlıkta ikinci plan.

**v0.7.0 başlangıcı:** Her tur için görünür yürütme planı oluşturulur. Executor sonrası Verifier, File Search ve güvenli File Actions durumunu tekrar okur. Doğrulanamayan gerçek işlemlerde Core otomatik olarak Plan B taşır; bağlantısı olmayan araçlarda sahte başarı üretmez.

**v0.7.1 reflection/recovery:** Verifier yalnızca fonksiyonun çalışmasını başarı saymaz; hedef sonucunu da kontrol eder. Salt-okunur dosya aramasında 0 sonuç oluşursa ve ilk plan tarih veya önceki-sonuç filtresi içeriyorsa Core bu kısıtı bir kez güvenli biçimde gevşetir, yeniden yürütür ve ikinci sonucu tekrar doğrular. Yazma işlemlerinde otomatik retry yapılmaz.

**v0.7.2 task decomposition:** Core ilk bileşik dosya görevlerini tek intent yerine zincir olarak yürütür. Arama → kısa liste → metadata temelli değerlendirme sıralı çalışır. İçerik analizi henüz bağlı değilse KRALİ bunu açıkça söyler; metadata çıkarımını görüntü içeriği analiziymiş gibi sunmaz.

**v0.7.3 capability routing + dynamic plans:** File Search / Mail / Premiere gibi isimler Core'un sabit modülleri olmaktan çıkarılmaya başlanır. Ortak capability registry; reasoning, context, file search, metadata, reversible write, perception, research, browser, Premiere ve mail gibi yeteneklerin kullanılabilirliğini ilan eder. Planner ihtiyaç duyduğu capability'lere göre göreve özel, değişken uzunlukta plan oluşturur. Bağlı olmayan capability plan içinde açıkça görünür; Core bunları çalışmış gibi göstermez.

**v0.7.4 capability-aware verification:** Verifier hedefin tamamını değerlendirir. Arama ve kısa liste başarılı olsa bile görev görsel/video içerik değerlendirmesi istiyor ve perception capability bağlı değilse sonuç artık başarı sayılmaz; “kısmi” olarak işaretlenir. Böylece Core, tamamladığı alt görevlerle yerine getiremediği hedefi birbirinden ayırır.

**v0.7.5 goal contract + response synthesis:** Intent artık hedefin kendisi kabul edilmez. Ayrı Goal Interpreter; locate, shortlist, assess-content, explain, organize, research, edit, communicate gibi istenen sonuçları çıkarır ve capability seçimini bu hedef sözleşmesi yönlendirir. Son kullanıcı cevabı da Executor metninden doğrudan çıkmaz; Verifier sonucu üzerinden Response Composer tarafından sentezlenir. Kısmi hedefte başarı dili kullanılamaz.

**v0.7.6 capability-derived route:** Görünür ve iç operasyon rotası legacy intent etiketlerinden ayrılır. Route Builder; Goal Contract, seçilen capability’ler ve doğrulama ihtiyacından Core → Goal → Context → Plan → capability stages → Verify → Response zincirini dinamik kurar. Alt seviye executor fonksiyonları artık üst seviye reasoning rotasını ezemez.

**v0.7.7 plan fidelity / blocked capabilities:** Plan adımlarının durumu capability readiness ile bağlanır. Bağlı olmayan bir capability gerektiren action “completed” olamaz; `blocked` durumda kalır. Eksik capability bulunan görevler zorunlu olarak Verifier'dan geçer ve hedef bütünü tamamlanmadıysa `partial` sonucuna düşer. Böylece UI, Planner ve gerçek çalışma kabiliyeti aynı gerçeği taşır.

**v0.7.8 capability learning loop:** Core bir capability açığını yalnızca hata olarak bırakmaz. Eksik yetenek için ayrı bir acquisition planı üretir: araştırma hedefi → ön koşullar → güvenli prototip → test → kullanıcı onayı → etkinleştirme. Web araştırma capability'si bağlıysa resmi kaynak araştırması o görevin alt görevi olabilir. Web araştırmanın kendisi gibi bootstrap yetenekleri kendi kendine web üzerinden edinilmiş gibi gösterilmez; gereken entegrasyon açıkça belirtilir. KRALİ internetten rastgele kod indirip çalıştırmaz ve yeni kod/izinleri kullanıcı onayı olmadan etkinleştirmez.

**v0.7.9 persistent learning backlog:** Capability gap artık yalnızca tek tur bağlamında kalmaz. Öğrenme kuyruğu eksik yeteneğin ilk görülme zamanını, kaç görevde tekrar ihtiyaç duyulduğunu, araştırma hedefini, ön koşulu ve sonraki adımı yerel olarak saklar. Aynı capability daha sonra gerçekten kullanılabilir hale geldiğinde kayıt `enabled` durumuna taşınabilir. Böylece KRALİ hangi yetenekleri tekrar tekrar öğrenmesi gerektiğini oturumlar arasında takip eder.

**v0.7.10 web research bootstrap:** İlk gerçek araştırma provider katmanı eklenir. KRALİ API anahtarı/token gerektirmeyen bir HTML arama bootstrap sağlayıcısından güncel web sonucu bulabilir, URL/domain bilgisini ayrı kaynak olarak saklar ve Verifier gerçek sonuç kümesini kontrol eder. Bu sürüm arama/keşif katmanıdır; derin sayfa okuma, kaynak güvenilirliği puanlama ve çok-kaynak sentezi sonraki aşamadır. Öğrenme kuyruğunda `readyToResearch` olan eksik capability'ler için KRALİ tek seferlik otomatik kaynak araştırması yapabilir ve kaydı `proposalReady` durumuna taşır. Rastgele web kodu indirme/çalıştırma hâlâ yasaktır.

**v0.7.11 research routing + resilient providers:** Açık web araştırma isteği dosya hedef kelimeleri içerse bile yerel File Search intent'ine düşmez; Research hedefi önceliklidir. Web provider katmanı tek bir servise bağımlı değildir: güvenli HTTPS üzerinden Google HTML bootstrap → Bing fallback → DuckDuckGo fallback sırasıyla denenir. TLS, HTTP veya parse hatasında sertifika doğrulaması gevşetilmez; yalnızca sonraki sağlayıcıya geçilir.

**v0.7.12 research quality / source diversity:** Provider'dan dönen ilk link araştırma başarısı sayılmaz. Bing RSS birincil keşif yolu olarak eklenir; HTML provider'lar fallback kalır. Sonuçlar sorgu terimleriyle alaka puanına tabi tutulur, arama motoru iç sayfaları ve “geri bildirim / sign in / yardım” gibi gürültüler elenir, aynı URL'ler tekilleştirilir. Bir kaynak yalnızca kısmi araştırma sayılır; tam doğrulama için en az iki alakalı kaynak gerekir.

**v0.7.13 semantic research query planner:** Araştırma sorgusu yüzey kelimeleriyle bırakılmaz. Ayrı Query Planner, platform/medya/analiz/framework gibi kavram gruplarını çıkarır, gerektiğinde İngilizce teknik ve resmi dokümantasyon varyantları üretir ve tercih edilen resmi domainleri belirler. Research scorer bir sonucun yalnızca tek güçlü kelimeyi (ör. “macOS”) taşımasını yeterli saymaz; en az iki bağımsız kavram grubunu karşılamasını ister. Böylece genel macOS haber/indirme sayfaları gibi tematik olarak alakasız sonuçlar elenir.

**v0.7.14 deep source reader / evidence layer:** Research artık arama sonucunun başlığını doğruluk kanıtı saymaz. En alakalı kaynakların sayfa içeriği güvenli HTTPS üzerinden okunur; script/style/nav gürültüsü temizlenir, query concept gruplarıyla eşleşen kanıt cümleleri çıkarılır ve kaynak başına evidence kaydı üretilir. Verifier tam research başarısı için en az iki kaynakta gerçek sayfa-içi evidence ister; yalnızca arama sonucu bulunan ama okunamayan görevler `partial` kalır.

**v0.7.15 mentor bridge + research precision:** Geliştirme döneminde KRALİ her tamamlanan görev için yapılandırılmış bir mentor trace üretir: kullanıcı hedefi, Goal Contract, seçilen capability'ler, plan, execution state'leri, Verifier sonucu, research kaynak/kanıtları ve nihai yanıt. Trace varsayılan olarak yalnızca yerelde tutulur. Kullanıcı açıkça Mentor Sync başlattığında son trace private GitHub reposundaki `Mentor/latest.json` dosyasına gönderilir; ChatGPT bağlı GitHub erişimiyle bunu okuyup davranış hatasını teşhis ederek kodu güncelleyebilir. Bu köprü OpenAI API kullanmaz ve ayrı API ücreti gerektirmez.

Araştırma tarafında kritik kavramlar artık `mandatoryConceptGroups` olarak modellenir. Örneğin macOS + video analysis araştırmasında yalnızca “video analysis” geçen genel servisler yeterli değildir; platform ve analiz kavramlarının birlikte karşılanması gerekir. Böylece araştırma motoru kullanıcının gerçek hedefinden uzaklaşan fakat yüzeyde benzer içerikleri daha agresif eler.

Mentor geliştirme ilkesi: KRALİ'nin kendisi ile Mentor aynı şey değildir. KRALİ bağımsız ajan olarak gelişir; Mentor yalnızca geliştirme/öğretim katmanıdır. İleride opsiyonel ücretsiz yerel reviewer (örn. local model runtime) eklenebilir, fakat hiçbir ücretli API varsayılan bağımlılık olmayacaktır.

**v0.7.16 Training Lab / batch learning:** Kullanıcının onlarca görevi tek tek manuel vermesi yerine KRALİ kendi reasoning iskeletini yerel senaryo paketiyle test eder. Senaryolar araştırma güvenilirliği, marka araştırması, içerik stratejisi, genel analiz/çıkarım, bağımsız fikir üretme, yerel dosya görevleri, context carry-over, capability gap, güvenlik ve açık-dünya North Star davranışlarını kapsar.

Training Lab iki skoru ayrı raporlar:

- **Core readiness:** bugün güvenilir çalışması gereken temel ajan davranışları.
- **North Star readiness:** henüz gelişmekte olan genel amaçlı ajan yetkinlikleri.

Her senaryoda Goal outcomes, capability seçimi, yanlış capability seçimi, route, dinamik plan adımları, capability learning planı ve araştırma concept coverage kontrol edilir. Başarısızlıklar `training-latest.json` raporunda toplanır ve Mentor Sync ile private GitHub'a aktarılabilir. Böylece ChatGPT Mentor tek tek kullanıcı testleri yerine toplu failure setini inceleyip Core kodunu güncelleyebilir.

Genel analiz davranışına `analyze` ve `ideate` hedefleri eklendi. KRALİ yalnızca özet vermek yerine kanıttan çıkarım üretmeye ve kullanıcı tarafından açıkça söylenmemiş ama bağlamdan türetilebilen fikir/fırsatları ayrı reasoning adımı olarak oluşturmaya yönlendirilir.

**v0.7.17 regression learning loop:** İlk Training Lab turunda 11/16 sonucu görülür ve failure seti doğrudan Core geliştirmesine çevrilir. Doğal dilde “fikri üret / özgün içerik fikri”, medya hakkında “yorum yap”, “sitesine gir” gibi browser ifadeleri ve “hangi yeteneğin eksik / öğrenme planı” gibi capability-gap görevleri Goal Interpreter ve Capability Router'a eklenir. Yeni app version'ı ilk açıldığında Training Lab otomatik regression turu çalıştırır; böylece kullanıcı aynı testleri elle tekrar etmek zorunda kalmaz.

**v0.7.18 free local intelligence provider:** Training Lab'in 16/16 geçmesi routing/planning iskeletinin kendi sözleşmesini karşıladığını gösterir; bu tek başına gerçek dünya analiz kalitesi değildir. Bu nedenle Core'a ayrı bir generative synthesis provider eklenir. macOS 26+ ve uygun Apple Intelligence donanımında Apple `FoundationModels` / `SystemLanguageModel` kullanılarak araştırma kanıtları, analiz ve ideation hedefleri cihaz üzerinde sentezlenir. Provider runtime availability kontrolü yapar; model hazır değilse kural tabanlı Core'a fallback olur. Böylece ayrı OpenAI API, token veya ek AI aboneliği varsayılan bağımlılık değildir.

Yerel modelin rolü Executor veya Verifier olmak değildir. Model; doğrulanmış evidence + Goal Contract + capability durumu + verifier sonucundan kullanıcıya yararlı analiz/sentez üretir. Bağlı olmayan capability'yi varmış gibi göstermemesi, kanıt ile çıkarımı ayırması ve kullanıcı tarafından söylenmeyen özgün fakat gerekçeli fikirleri kanıttan türetmesi temel prompt sözleşmesidir.

**v0.7.19 brand research mission + live evaluation:** Gerçek Mentor trace'i, statik Training Lab 16/16 olsa bile marka araştırmasının sahada başarısız olabileceğini gösterir. Research katmanı bu nedenle tek uzun sorgu yaklaşımından görev-özel araştırma misyonuna geçer. Marka/şirket araştırmalarında varlık (entity) çıkarılır ve araştırma resmi kaynak, tarihçe, ürün/hizmet, pazar/rakip ve güncel gelişmeler gibi facet'lere bölünür. Sonuçlar araştırılan varlıkla gerçekten eşleşmek zorundadır; yalnızca genel anahtar kelime benzerliği yeterli değildir. Kaynak seçimi domain çeşitliliğini korur ve deep source evidence de entity-grounded olur.

Ayrıca statik Training Lab'den ayrı **Live Research Eval** eklenir. Her yeni sürümde gerçek internet üzerinden en az bir marka/entity araştırması ve bir teknik/resmi-dokümantasyon araştırması çalıştırılır. Kaynak sayısı, derin okuma kanıtı ve domain çeşitliliği ölçülür; sonuç `live-eval-latest.json` olarak Mentor Bridge'e eklenir. Böylece regression yalnızca “doğru rota seçildi mi?” değil, gerçek dünyada araştırma provider'ları ve evidence pipeline'ı gerçekten çalışıyor mu sorusunu da test eder.

**v0.7.20 Developer Agent / isolated auto-fix loop:** Geliştirme hattına Cline tabanlı yardımcı coding agent eklenir; bu katman KRALİ'nin runtime zekası değil, KRALİ'yi geliştiren ayrı bir developer worker'dır. Diagnostic önceliği Live Research Eval → güncel Mentor trace → Training Lab regression → capability gap sırasındadır. Developer Agent her turda `origin/main` üzerinden ayrı `krali-dev-agent/<timestamp>` branch ve worktree açar, main üzerinde doğrudan değişiklik yapmaz.

Varsayılan provider/model `cline + nvidia/nemotron-3.5-lightning` olarak sabitlenir; bu model Cline tarafından ücretsiz sunulduğu sürece ek AI ücreti gerektirmez. Workflow ücretli modele sessizce geçmez. Cline'ın komut yetkileri sınırlandırılır; `sudo`, destructive reset/clean, `git push` ve uygulama açma gibi komutlar agent'a verilmez. Aday değişiklik daha sonra KRALİ'nin kendi `Scripts/build-check.command` doğrulamasından geçirilir. Build başarılıysa yalnızca aday branch GitHub'a push edilir; main'e merge otomatik değildir ve Mentor incelemesi beklenir. Diagnostic'ler tamamen yeşilse agent'ın sırf değişiklik üretmek için kodu kurcalamaması temel kuraldır.

**v0.7.21 Developer setup diagnostics:** Developer Agent kurulumu artık tek bir “Cline yok” durumuna indirgenmez. Node.js/npm yokluğu, eski Node sürümü ve Cline CLI eksikliği ayrı durumlar olarak raporlanır. Cline CLI'nin resmi kurulum gereksinimine göre Node.js 20+ kontrol edilir; uygun kurulum adımı UI'da doğrudan gösterilir.

**v0.7.22 ChatGPT Subscription Developer Agent + auto updater check:** Kullanıcının ek API ücreti istememesi nedeniyle Developer Agent'ın varsayılan provider'ı Cline içindeki `openai-codex` / ChatGPT Subscription OAuth olarak değiştirilir. Model adı script içinde sabitlenmez; `cline auth` sırasında ChatGPT aboneliği için seçilen model provider ayarından yeniden kullanılır. Böylece ayrı OpenAI API anahtarı veya Cline kredi bakiyesi gerektiren yola sessizce geçilmez. Updater da uygulama açılışından kısa süre sonra otomatik `origin/main` + `VERSION` kontrolü yapar.

**v0.7.23 Developer Agent fast diagnostic gate + live progress:** Developer Agent artık her tıklamada doğrudan modele gitmez. Yerel `training-latest.json`, `live-eval-latest.json` ve `latest.json` raporları mevcut `VERSION` ile karşılaştırılır. Training Lab ve Live Research Eval güncel sürümde tamamen yeşilse ve güncel mentor trace ek müdahale gerektirmiyorsa Cline çağrısı atlanır; bu hem ChatGPT kullanım limitini hem bekleme süresini korur. Gerçek bir failure varsa Cline çalışır; UI yaklaşık 700 ms aralıkla status dosyasını okuyarak hazırlık, diagnostic kontrol, model çalışması ve build doğrulama aşamalarını canlı gösterir. Cline turu `medium` thinking ve 900 saniye timeout ile sınırlandırılır.

### 0.8.x — Memory
Kısa süreli konuşma belleği ile kalıcı kullanıcı tercihlerini ayırma; bağlam özetleme.

### 0.9.x — Perception
Ses, ekran/görsel ve dosya içeriğini ortak bir bağlam modelinde birleştirme.

### 1.0 — Tool-using KRALİ
Core olgunlaştıktan sonra Browser, Work/Mail, Premiere ve harici model bağlantılarının güvenli orkestrasyonu.


**v0.7.24 grounded synthesis + goal completion:** Gerçek mentor trace, araştırma kaynaklarının başarıyla bulunmasının kullanıcının istediği analiz ve özgün fikir hedeflerinin tamamlandığı anlamına gelmediğini gösterdi. Bu sürümde araç doğrulaması ile hedef tamamlama ayrıldı. Analiz/ideation adımları gerçek bir sentez sonucu gelmeden tamamlanmış sayılmıyor.

Öncelik cihazdaki Apple Foundation Models katmanında. Apple modeli hazır değilse ve kullanıcı Cline üzerinden ChatGPT Subscription ile giriş yaptıysa, doğrulanmış kaynak kanıtlarından son kullanıcı cevabı üretmek için ayrı bir subscription synthesis katmanı kullanılabiliyor. Sentez sağlayıcısı yoksa araştırma başarılı olsa bile analiz/ideation görevi kısmi sayılıyor. Mentor trace kullanılan zeka sağlayıcısını da kaydediyor.

Deep-source kanıtlarında HTML entity çözümü ve sayfa boilerplate temizliği de iyileştirildi.


**v0.7.25 subscription synthesis reliability:** İlk v0.7.24 gerçek görev trace'i hedef tamamlama doğrulamasının doğru biçimde `partial` verdiğini, ancak ChatGPT Subscription sentez subprocess'inin tamamlanamadığını gösterdi. Synthesis bridge bu nedenle pipe tabanlı stdout/stderr toplamak yerine scratch çalışma alanındaki geçici NDJSON dosyasına yazar; böylece uzun JSON akışında pipe-buffer kilitlenmesi engellenir. Cline güvenli scratch dizininde auto-approve ile çalışabilir fakat shell komut izinleri tamamen kapalı kalır. Non-zero exit ve parse hatalarının son bölümü artık activity/mentor diagnostic'e taşınır.

Ayrıca Türkçe dotless-i normalizasyonu nedeniyle `Bağımsız fikir üret` reasoning adımının yanlışlıkla completed kalabildiği hata düzeltilir; synthesis başarısızsa analiz ve ideation adımlarının ikisi de partial olur.


**v0.7.26 detailed research semantics:** Estafiz mentor trace'i, doğal dilde “detaylı araştırır mısın?” isteğinin yalnızca `research` olarak çözüldüğünü ve ham kanıt listesiyle `passed` sayılabildiğini gösterdi. Bu sürümde detaylı araştırma ifadeleri `research + explain` hedef sözleşmesine yükseltilir. Böyle bir görev güvenilir synthesis sonucu olmadan tam başarılı sayılmaz.

Research Query Planner ayrıca “X adında bir salon/işletme/merkez...” kalıbından araştırılan varlığı çıkarabilir ve yerel işletmeleri entity-grounded çoklu sorgu akışına alabilir. Verifier kaynak sayısı ve deep-read yanında farklı domain sayısını da kontrol eder; tek domaine yığılmış çoklu sonuç sağlam araştırma sayılmaz.

Training Lab'e Estafiz biçiminde doğal dilde detaylı yerel işletme araştırması regression senaryosu eklenir. Böylece bu davranış sonraki sürümlerde yeniden bozulursa otomatik test yakalar.


**v0.7.27 public social profile research:** Gerçek kullanımda “estafizsym instagram hesabının kaç takipçisi var, içerikleri neler bakabilir misin” gibi bir istek explicit “araştır/web” kelimesi içermediği için Core fallback'e düşebiliyordu. Goal Interpreter artık Instagram/TikTok/LinkedIn/YouTube gibi public social profile sorularında takipçi, içerik, paylaşım, gönderi, reels, bio veya inceleme niyetini görürse bunu `research + explain` olarak sınıflandırır ve `research.web` capability'sini seçer.

Research Query Planner handle + platform ikilisini çıkarır; resmi profil, takipçi/kitle ve içerik türleri için ayrı facet sorguları üretir. Sonuçlar handle ile entity-grounded kalır ve platform domainine öncelik verilir. Canlı takipçi/gönderi gibi hızlı değişen metrikler yalnızca doğrulanmış evidence içinde açıkça varsa sayı olarak verilir; aksi durumda KRALİ doğrulanamadığını söyler, tahmin üretmez.

Training Lab'e aynı Estafiz Instagram cümlesi regression senaryosu olarak eklenir.
