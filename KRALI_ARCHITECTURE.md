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


**v0.7.28 direct resource resolution + capability escalation:** Sosyal/public profile araştırmasında “arama motorunda sonuç yok = hedef yok” varsayımı kaldırılır. Research plan, handle + platform gibi yeterince kesin bir tanımlayıcıdan doğrudan kanonik public resource adayı üretebilir. Bu aday bir URL çözümüdür; doğrulanmış evidence değildir.

Web Research direct adayları arama sonuçlarıyla birlikte değerlendirir. Source Reader, direct-resolved bir kaynağı ancak sayfanın gerçek içeriğinden varlık kanıtı çıkarabiliyorsa evidence kabul eder; yalnızca URL/title varlığı kanıt sayılmaz. Böylece KRALİ hedef adresini bilebilir ama canlı takipçi, gönderi, stok, fiyat gibi verileri okuyamadığında bunu uydurmaz.

Direct hedef çözüldüğü halde page evidence alınamazsa Core bunu “kaynak yok” yerine “etkileşimli/live erişim eksik” olarak sınıflandırır. `browser.control` runtime capability olarak seçilir, Learning backlog'a güvenli browser/session bridge araştırma görevi eklenir ve Verifier sonucu partial verir. Bu davranış yalnızca Instagram'a özgü değil; ileride deterministic URL/ID çözümü yapılabilen diğer public resources için aynı resolver → retriever → verifier zinciri kullanılabilir.

Training Lab sosyal profil senaryosunda artık en az bir direct resource candidate üretildiğini de regression olarak doğrular.


**v0.7.29 source authority verification:** Public profile testinde KRALİ Instagram profilinin gerçek sayfa kanıtından takipçi, bio ve içerik bilgileri çıkarabildiği halde genel verifier “yalnızca 1 kaynak” kuralı nedeniyle sonucu `partial` sayıyordu. Bu, kaynak çeşitliliği ile kaynak otoritesini aynı şey sanan bir hatadır.

Direct resolver tarafından çözülen kanonik kaynak, yalnızca URL olarak bulunduğunda hâlâ evidence sayılmaz. Ancak Source Reader o kanonik kaynağın gerçek içeriğini okuyup entity-grounded kanıt çıkarırsa bu `canonical-direct evidence` olarak işaretlenir. Böyle bir birincil kaynak kendi profil/hesap bilgileri için yeterli otorite kabul edilir; verifier ikinci bir domaini sırf sayı tamamlamak için zorunlu tutmaz. Geniş marka/pazar araştırmalarında bu istisna uygulanmaz; normal çok-kaynak/domain çeşitliliği kuralları devam eder.

Mentor trace artık her araştırma kaynağı/evidence için `sourceType` alanı yazar: `canonical-direct` veya `search-result`. Böylece sonraki mentor analizlerinde “tek kaynak ama birincil resmi kaynak” ile “tek arama sonucu” ayrımı görünür hale gelir.


**v0.8.0 structured context memory + sidebar reset:** 0.7.x Core doğrulandıktan sonra KRALİ kısa süreli görev bağlamını yapılandırılmış ve kalıcı bir yerel hafızaya taşımaya başlar. Yeni `AgentContextMemoryStore`, açık kullanıcı çalışma kurallarını, tamamlanan görevleri ve araştırma sonuçlarını ayrı türlerde saklar. Tam cevap metnini sınırsız biçimde yığmak yerine görev başlığı, hedef, özet ve kaynak URL'leri tutulur; görev kayıtları sınırlı sayıda korunur.

Her yeni kullanıcı mesajından önce KRALİ sorguyla ilişkili önceki kayıtları lexical relevance + devam referansları (`bu hesap`, `az önceki analiz`, `bunlardan`, `devam et`) üzerinden geri çağırır. Kullanıcı açık bir devam referansı kullandığında en yeni ilgili görev bağlamına recency bonus uygulanır. Geri çağrılan bağlam Core context snapshot'a girer ve reasoning/synthesis sağlayıcılarına taşınır. Böylece örneğin bir Instagram araştırmasından sonra “bu hesap için az önce söylediklerinden 3 Reels fikri çıkar” isteği gereksiz web araştırması yapmadan önceki doğrulanmış rapordan devam edebilir.

Legacy `UserDefaults` çalışma kuralları ilk açılışta yapılandırılmış memory store'a migrate edilir. Yeni kurallar hem eski uyumluluk katmanında hem structured memory içinde tutulur. Mentor trace artık o turda gerçekten geri çağrılan memory kayıtlarını da yazar; böylece yanlış bağlam kullanımı geliştirici tarafından görülebilir.

Training Lab'e `context-memory-followup` regression senaryosu eklenir. Sosyal profil kelimeleri içeren yaratıcı follow-up'lar (`bu hesap için ... Reels fikri çıkar`) artık sırf “hesap/reels” geçti diye otomatik web araştırmasına zorlanmaz; ilgili önceki bağlam varsa context continuation olarak ele alınır.

Aynı sürümde sağ sidebar 0.7.x geliştirme döneminden kalan debug kalabalığından temizlenir. Varsayılan görünüm yalnızca **Durum**, **Bağlam**, gerektiğinde **Kaynaklar**, **Öğrenme**, **Onay/sonuçlar** bölümlerini gösterir. Training Lab, Live Research Eval ve Developer Agent tek bir kapalı **Geliştirici araçları** disclosure alanına taşınır. Ayrı Active Route, raw activity feed, duplicate Mentor bridge, eski Local File Agent liste dökümleri, tam evidence dump ve release-note kartı varsayılan UI'dan kaldırılır. Mentor düğmesi üst çubukta tek yerde kalır.


**v0.8.1 memory relevance + intent cleanup:** İlk gerçek 0.8.0 Mentor turu, görev hafızasının doğru Estafiz araştırmasını geri çağırdığını ve follow-up isteğinde web araştırmasını gereksiz yere tekrarlamadığını doğruladı. Ancak iki kalite açığı görüldü: `fikir çıkar` ifadesi Goal Interpreter tarafından `ideate` olarak sınıflandırılmıyordu ve ilgisiz varsayılan userRule kayıtları her recall'a düşük puanla sızabiliyordu.

0.8.1'de Türkçe ideation kalıpları `fikir çıkar / fikri çıkar / fikirleri çıkar` biçimleriyle genişletilir. Structured memory relevance skorunda userRule artık salt türü nedeniyle taban puan almaz; yalnızca mevcut sorguyla gerçek token örtüşmesi varsa ek puan kazanır. Böylece görev bağlamı ile ilgisiz kalıcı kurallar synthesis prompt'una taşınmaz.

Live Research Eval teknik probe'u da genel Türkçe sorgu yerine Apple Developer / Vision / AVFoundation odaklı resmi dokümantasyon sorgusuna geçirilir. Amaç değerlendirmeyi kolaylaştırmak değil, sağlayıcıların resmi teknik kaynakları bulma olasılığını yükseltip gerçek research pipeline regresyonunu daha kararlı ölçmektir.


**v0.8.2 topic switching + memory quality gate:** Gerçek 0.8.1 ekran testi iki ayrı semantik hatayı ortaya çıkardı. “Sony A7 IV ile Fuji X-T5 arasında video açısından temel farklar neler?” cümlesi, yalnızca “video + neler” kelimeleri nedeniyle yanlışlıkla yerel dosya aramasına yönlenebiliyordu. File Search intent'i artık bilgi/ürün karşılaştırması sinyallerini (`arasındaki fark`, `farklar neler`, `karşılaştır`, `vs`) yerel dosya kapsamından ayırır. Böyle bir bilgi karşılaştırması açık bir yerel kapsam yoksa web araştırma + analiz + açıklama hedefi olarak ele alınır.

Aynı turda “Estafiz'e dön, az önceki Reels fikirlerinden birincisini 30 saniyelik çekim senaryosuna çevir” follow-up'ı doğru memory kaydını görmesine rağmen generative synthesis'e girmeden executor fallback metnini döndürüyordu. Contextual transformation ifadeleri (`senaryo`, `çekim planı`, `çevir`, `uyarla`, `dönüştür`) artık `ideate` sonucu üretir; böylece Intelligence katmanı recalled memory üzerinde gerçek dönüşüm/sentez yapar. Context devamında eski araştırma goal metni aynen devralınmaz; yeni turun hedefi kendi isteğinden türetilir.

Memory store ayrıca düşük kaliteli generic fallback cevaplarını kalıcı göreve dönüştürmez. Önceki sürümden kalmış “hedefi analiz ettim fakat ... eşleştiremedim / şu an en güvenli planım ...” türü task kayıtları load sırasında elenir ve tekrar kaydedilmez. Non-continuation topic recall için tek ortak kelime yeterli değildir; task/research kayıtlarında daha güçlü lexical eşleşme aranır. Böylece konu değişimlerinde yalnızca “video” gibi genel bir sözcük yüzünden Estafiz bağlamının Sony/Fuji karşılaştırmasına sızması azaltılır.

Training Lab'e iki regression eklenir: `context-memory-transform` ve `knowledge-comparison-not-file-search`.


**v0.8.3 topical recall + stale-memory freshness:** Gerçek 0.8.2 Mentor trace iki önemli davranışı doğruladı: Training Lab 21/21 ve Live Research Eval 2/2 geçti; Estafiz follow-up'ı artık Intelligence katmanına girip gerçek 30 saniyelik senaryo üretti. Buna rağmen trace, iki daha ince memory problemi gösterdi.

Birincisi, standalone bilgi karşılaştırması için geçmişte aynı soruya ait bir memory bulunması güncel research ihtiyacını yanlışlıkla bastırabiliyordu. Bu nedenle bilgi/ürün karşılaştırmalarında karar artık `relevantMemoryCount` yerine gerçek intent'e bağlıdır: görev genel bilgi karşılaştırmasıysa `research.web` yine çalışır; yalnızca açık yerel/file task'larda araştırma eklenmez. Böylece eski veya hatalı bir memory, yeni doğrulanabilir bilgi isteğinin önüne geçmez.

İkincisi, `Estafiz'e dön` gibi açık topic switch follow-up'larında continuation bonus'u tüm yakın geçmiş görevleri aday yapabildiği için alakasız Sony/Fuji memory'si de synthesis context'ine girebiliyordu. Memory retrieval artık önce mevcut sorguyla en güçlü topical token örtüşmesini hesaplar. Continuation içinde gerçekten eşleşen bir konu/varlık varsa sadece o konuyla eşleşen task/research kayıtları aday olur; hiç topical ipucu yoksa `devam et` gibi saf referanslarda recency fallback korunur.

Aynı kullanıcı isteği daha sonra daha kaliteli bir `research` kaydıyla yeniden çalıştırılırsa, eski `task` kaydı türü farklı olsa bile duplicate kabul edilip yenisiyle değiştirilir. Böylece eski yanlış cevapların kalıcı bağlamda yan yana birikmesi azaltılır.

Training Lab'e `knowledge-comparison-with-stale-memory` regression senaryosu eklenir; eski eşleşen memory mevcut olsa bile standalone Sony/Fuji karşılaştırmasının Research + Verify rotasına gitmesi zorunlu tutulur.


**v0.8.4 transformation fidelity:** 0.8.3 Mentor turu, topical recall ve stale-memory freshness düzeltmelerinin çalıştığını doğruladı: Training Lab 22/22, Live Research Eval 2/2 geçti; Sony/Fuji karşılaştırması yeniden Research → Verify rotasına gitti ve Estafiz'e dönüşte Sony memory'si artık synthesis context'ine taşınmadı. Ancak yeni bir semantik hata ortaya çıktı: “birinci Reels fikrini 30 saniyelik çekim senaryosuna çevir” isteği `ideate` olarak modellenmişti. Apple yerel model bu nedenle tek mevcut fikri dönüştürmek yerine üç yeni fikir üretti.

0.8.4'te `AgentGoalOutcome.transform` ayrı bir hedef türü olur. “senaryoya çevir / çekim planına dönüştür / uyarla” gibi bağlamsal dönüşümler artık `ideate` değildir. Planner, `İstenen formata dönüştür` reasoning adımı üretir ve açıkça kullanıcının referans verdiği öğeyi seçip yeni alternatifler yaratmadan istenen süre/sayı/yapıya dönüştürme sözleşmesi taşır. Local ve Subscription synthesis prompt'ları da “birincisini / ikincisini / sonuncusunu” gibi sıra referanslarını önceki bağlamdan çözmek ve dönüşüm görevlerinde alternatif fikir listesi üretmemek üzere sıkılaştırılır.

Engine, `transform` hedefini gerçek synthesis gerektiren hedef olarak değerlendirir; synthesis başarısızsa hedef tamamlandı sayılmaz. Training Lab'deki `context-memory-transform` senaryosu artık `transform` outcome'unu ve `İstenen formata dönüştür` plan adımını zorunlu kılar.


**v0.8.5 transform source resolution + synthesis fidelity gate:** 0.8.4 Mentor turu, `transform` hedefi ve planner adımının doğru seçildiğini doğruladı; Training Lab 22/22 ve Live Research Eval 2/2 geçti. Buna rağmen Apple Foundation Models çıktısı hâlâ kullanıcı talebine uymadı: “birinci Reels fikrini 30 saniyelik çekim senaryosuna çevir” yerine yeniden üç alternatif fikir üretildi. Trace ayrıca synthesis context'inin ilk sırasında önceki başarısız dönüşüm denemesinin bulunduğunu gösterdi.

0.8.5 iki katmanlı koruma ekler. Structured memory retrieval, dönüşüm isteği bir “fikir/Reels” kaynağına referans veriyorsa doğrudan fikir üreten önceki task kaydını önceliklendirir ve aynı dönüşüm komutunun eski denemelerini kaynak bağlamdan çıkarır. Böylece model önce yanlış dönüşüm çıktısını değil, kullanıcının gerçekten işaret ettiği fikir listesini görür.

İkinci olarak Core artık `transform` sentez çıktısını hedef-biçim sözleşmesine göre kontrol eder. Kullanıcı süreli bir çekim senaryosu istediyse çıktının senaryo/çekim/timeline izi ve istenen süreyi karşılayan bir yapı göstermesi gerekir. Apple yerel model bu sözleşmeyi karşılamazsa çıktı kullanıcıya verilmez; KRALİ otomatik olarak ChatGPT Subscription synthesis katmanına fallback eder. Subscription çıktısı da aynı fidelity kontrolünden geçer. Böylece “sentez üretildi” ile “kullanıcının istediği dönüşüm gerçekten üretildi” birbirinden ayrılır.

Training Lab'e `context-transform-source-resolution` regression kontrolü eklenir. Test, aynı konuda eski başarısız transform kaydı mevcutken bile kaynak fikir listesinin ilk bağlam olarak seçildiğini ve eski transform denemesinin geri çağrılmadığını doğrular.


**v0.8.6 readable responses + Turkish proofreading:** 0.8.5 Mentor turu dönüşüm hattının artık doğru çalıştığını doğruladı: Training Lab 23/23, Live Research Eval 2/2 geçti ve “birinci Reels fikrini 30 saniyelik çekim senaryosuna çevir” isteği tek, zaman çizelgeli bir senaryoya dönüştürüldü. Context de doğrudan fikir listesi + ilgili araştırmayla sınırlı kaldı.

Bu sürüm yanıt kalitesini ve okunabilirliği iyileştirir. Chat balonundaki assistant metni artık düz string olarak değil, hafif Markdown-aware bir renderer ile gösterilir: başlıklar semibold ve daha büyük, gövde normal ağırlıkta, listeler hizalı, blockquote'lar ayrık, yatay ayraçlar gerçek divider olarak çizilir ve **bold / inline code** işaretleri görsel biçime dönüşür. Kullanıcı balonları daha kompakt orta ağırlıkta kalır. Sağdaki Bağlam önizlemesinde ham `##`, `**` ve benzeri işaretler temizlenir.

Local Intelligence ve ChatGPT Subscription sentez sözleşmelerine Türkçe yazım/noktalama son kontrolü, doğal Türkiye Türkçesi, kısa başlık + normal gövde düzeni ve gereksiz kalın metinden kaçınma kuralları eklenir. Response Composer ayrıca sık görülen birkaç yazım hatasını (`şuan → şu an`, `birşey → bir şey`, `yada → ya da`, `yanlız → yalnız`, `herkez → herkes`, `kapanışda → kapanışta`) deterministic olarak temizler ve gereksiz üçlü boş satırları iki satıra indirir.


**v0.8.7 content creation + rewrite routing:** 0.8.6 ekran testi, yeni Markdown-aware tipografinin görsel olarak belirgin biçimde iyileştiğini doğruladı: başlıklar ve önemli etiketler daha güçlü, gövde metni daha hafif, listeler hizalı ve ham Markdown işaretleri görünmüyor. Ancak aynı test iki semantik açığı ortaya çıkardı.

“Estafiz için 30 saniyelik bir Reels çekim planı hazırla” isteği, `çekim` kelimesi ve kısa substring eşleşmeleri nedeniyle yanlışlıkla yerel video dosyası aramasına gidebiliyordu. Bu da 463 yerel dosya sonucu üretip daha sonra Sony/Fuji gibi alakasız geçmiş bağlamların içerik cevabına sızmasına yol açtı. File-search routing artık `çekim planı hazırla / senaryo hazırla / metin hazırla / yeniden yaz / düzgün Türkçeyle` gibi içerik üretimi ve dil dönüşümü kalıplarını yerel dosya aramasından ayırır.

Yeni `AgentGoalOutcome.compose` genel içerik üretimini ayrı bir hedef olarak modeller. Planner `İçeriği oluştur` adımı ekler; Engine bunu gerçek synthesis gerektiren hedef sayar. Böylece içerik planı, senaryo, caption veya metin oluşturma görevleri “araç eşleşmedi” fallback'i yerine doğrudan Intelligence katmanına gider.

Standalone rewrite/proofreading istekleri de `transform` olarak sınıflandırılır. Kaynak metin kullanıcı mesajında doğrudan tırnak içinde verildiyse structured memory retrieval eski görev bağlamını geri çağırmaz; inline metin tek kaynak kabul edilir. Local ve Subscription synthesis sözleşmeleri de bu davranışı açıkça zorunlu kılar.

Memory relevance, non-continuation görevlerde yalnızca summary kelime benzerliğine yaslanmaz; başlık + orijinal userInput kimliğiyle de eşleşme arar. Açıkça “Estafiz” denilen bir görevde Sony/Fuji gibi yalnızca genel kelimeler üzerinden eşleşen kayıtlar elenir.

Synthesis fidelity gate artık generic fallback metinlerini reddeder; üç bölümlü içerik isteklerinde beklenen Açılış / Ana Mesaj / Kapanış yapısını ve Türkçe rewrite testinde bilinen hatalı biçimlerin düzeltilmiş olmasını kontrol eder. Uymayan Apple Foundation Models çıktısı kullanıcıya verilmeden Subscription fallback'e geçer.

Training Lab'e `content-plan-not-file-search`, `inline-turkish-rewrite` ve gerçek memory retrieval için `named-topic-memory-isolation` regresyonları eklenir.


**v0.8.11 semantic mission planner foundation:** Core artık açık-dünya görevlerinde yalnızca sabit intent / anahtar kelime tablolarına dayanmak zorunda değildir. Apple Foundation Models üzerinde çalışan ayrı Semantic Mission Planner, kullanıcının doğal dildeki mesajından nihai amacı, semantic outcome'ları, 1–10 arası alt görevi, görev bağımlılıklarını ve gereken capability ID'lerini yapılandırılmış JSON mission olarak üretir. Deterministic AgentBrain / GoalInterpreter kaldırılmaz; model kullanılamazsa veya düşük güvenli mission üretirse güvenli fallback ve regression katmanı olarak korunur.

Semantic mission şimdilik özellikle `general`, `futureCapability`, compound ve edit hedeflerinde devreye girer. Örneğin “son çekimle ilgili kurgu yapmamız gerekiyor” ifadesi kullanıcının ayrıca “dosyaları bul” demesini gerektirmeden `files.search → perception.media → premiere.control → perception.screen` benzeri bir görev zincirine; marka için tasarım isteği ise `research.web → browser.control / reasoning → photoshop.control → perception.screen` zincirine dönüşebilir. Core mission'ın istediği capability bağlı değilse bunu varmış gibi göstermez.

Capability kataloğuna `perception.screen`, `desktop.control` ve `photoshop.control` eklenmiştir. Semantic executor'ın ilk güvenli sürümü yalnızca doğrulanmış read-only primitive'leri otomatik çalıştırır: reasoning/context, web research, local file search ve metadata. Masaüstü, browser, Premiere, Photoshop ve screen interaction provider'ları bağlanana kadar ilgili mission step'leri `blocked/partial` kalır. Bu kasıtlı sınır, semantic planlamayı gerçek uygulama yetkisinden ayırır ve sahte başarıyı önler.

Verifier artık semantic mission'ı bilir. Kullanıcı açıkça “bul” demese bile mission gerçekten `files.search` gerektiriyorsa locate hedefini stale-state sanıp reddetmez; buna karşılık mission'ın istediği çalışma alanı, dosya sonucu, araştırma kanıtı ve unavailable capability durumlarını ayrı ayrı doğrular. Mentor trace'e semantic mission'ın objective, outcomes, steps, dependencies, required capabilities, user-input gereksinimi ve confidence alanları da yazılır. Böylece sonraki Mentor turlarında yalnızca son cevabı değil, Core'un mesajı nasıl parçaladığını doğrudan incelemek mümkündür.

Bu sürümle sonraki ana geliştirme hattı netleşir: **Semantic Mission → Perception/Screen → Desktop Control → Browser Control → Premiere Provider → Photoshop Provider → Observe/Act/Verify/Replan döngüsü.**


**v0.8.12 semantic mission review + topic isolation:** Gerçek Mentor trace, Semantic Mission Planner'ın iki açık dünya hatasını gösterdi. Birincisi, “Dönerci Ahmet adında bir markamız var. Bu marka...” gibi açık yeni-entity tanıtımı, yalnızca “bu marka” referansı nedeniyle eski Estafiz task/research hafızasına continuation olarak bağlanabiliyordu. Brain ve Context Memory artık açıkça yeni marka/şirket/işletme tanıtımını yeni topic boundary olarak kabul eder; genel kullanıcı kuralları geri çağrılabilir fakat eski entity task/research kayıtları yeni markaya taşınmaz.

İkincisi, “son çekimle ilgili bir kurgu yapmamız gerekiyor” Semantic Mission üretmesine rağmen ilk model turu yalnızca `core.reasoning` seçebildi. Semantic Planner artık ilk mission'dan sonra aynı yerel modelle ayrı bir self-review turu çalıştırır. Reviewer mission'ın hedefi uçtan uca tamamlayıp tamamlamadığını denetler; gerekiyorsa `files.search`, `files.metadata`, `perception.media`, `desktop.control`, `browser.control`, `premiere.control`, `photoshop.control`, `perception.screen` ve `research.web` gibi unavailable capability'leri dahi görevin doğal gereksinimi olarak plana ekler. Gerçek operasyon outcome'u taşıyıp reasoning/context dışında hiçbir capability seçmeyen mission geçerli sayılmaz.

Verifier'daki eski substring kontrolü de kelime-sınırı güvenli hale getirildi; örneğin “başka markalara” içindeki `ara` artık file-search fiili sayılmaz. Training Lab'e gerçek “Dönerci Ahmet” yeni marka izolasyonu regression'ı eklendi. Böylece bu sürümde hedef Training Lab sonucu 30/30'dur.


**v0.8.13 semantic planner fallback + capability coverage:** v0.8.12 Mentor turunda Training Lab 30/30 ve yeni marka hafıza izolasyonu doğrulandı; ancak açık dünya semantic planning iki yeni North Star açığı gösterdi. “Son çekimle ilgili bir kurgu...” mission üretebildi fakat yalnızca research/perception seçip gerçek dosya + Premiere + ekran doğrulama zincirini eksik bıraktı. “Tavukçu Veli adında bir marka...” isteğinde ise Apple Foundation Models geçerli semantic mission üretemedi ve deterministic fallback'e dönüldü.

Semantic mission artık yalnızca geçerli JSON olmasıyla kabul edilmez. Outcome→capability coverage sözleşmesi zorunludur: locate/shortlist için files.search veya browser, assessContent için perception, research için research/browser, edit için gerçek bir edit provider, communicate için mail/browser gerekir. Deterministic fallback Goal Contract açıkça edit istiyorsa semantic mission da edit outcome'u taşımak zorundadır. Böylece “edit hedefi + yalnızca reasoning” veya “edit hedefi + sadece araştırma” mission'ları reddedilir.

Apple yerel Semantic Planner geçerli/kapalı mission üretemezse Core, mevcut Cline + ChatGPT Subscription OAuth bağlantısını yalnızca yapılandırılmış mission üretmek için ikinci planner olarak kullanır. Bu yol ayrı OpenAI API anahtarı/token gerektirmez; shell/tool izinleri kapalı kalır ve yalnızca JSON mission üretmesine izin verilir. Subscription mission da aynı capability coverage doğrulamasından geçmeden runtime'a alınmaz.

Semantic planner ayrıca yerel dosya ve uygulama capability'leriyle çözülebilen görevlerde gereksiz web araştırması eklememek üzere sıkılaştırıldı. Mentor trace artık semantic mission yanında `semanticPlannerProvider` alanını da taşır; Activity log Apple veya ChatGPT Subscription planner'ın hangisinin seçildiğini ve iki planner da başarısız olursa fallback nedenini kaydeder.


**v0.8.14 KRALİ Arena + autonomous development loop:** Geliştirme süreci yalnızca manuel Mentor trace incelemesine bağlı olmaktan çıkarılmaya başlanır. Yeni KRALİ Arena, her yeni sürümde açık-dünya görev bankasını Semantic Planner üzerinden çalıştırır. İlk paket; doğal dilde video kurgu, yeni marka sosyal medya tasarımı, masaüstü düzenleme, etkileşimli browser görevi, iş maili ve araştırmadan Photoshop üretimine uzanan çapraz-uygulama görevlerini içerir.

Arena her mission'ı iki ayrı katmanda değerlendirir. Deterministic sözleşme; zorunlu/istenmeyen capability'leri, beklenen semantic outcome'ları ve gereksiz kullanıcı girdisi istemeyi kontrol eder. Bundan ayrı olarak Apple Foundation Models üzerinde çalışan **Reviewer** ajanı mission'ın kullanıcının gerçek hedefini uçtan uca karşılayıp karşılamadığını eleştirir; eksik capability, gereksiz capability ve risk notlarını yapılandırılmış JSON olarak döndürür. Reviewer'ın yalnızca advisory risk notları otomatik kod değişikliği başlatmaz; FAIL, eksik veya gereksiz capability işaretleri geliştirme sinyali sayılır.

Arena local Semantic Planner başarısız olduğunda sınırlı sayıda ChatGPT Subscription/Cline planner fallback denemesi yapabilir. Fallback bütçesi iki denemeyle sınırlıdır; provider problemi Arena'yı süresiz kilitlemez. Subscription planner headless **Plan Mode**'da çalışır, shell/tool izinleri kapalıdır ve başarısızlık ham çıktısı `~/Library/Logs/KRALI-Semantic-Planner.log` dosyasına yazılır.

Arena raporu `~/Library/Application Support/KRALI Agent/Mentor/arena-latest.json` olarak saklanır ve Mentor Sync ile private GitHub reposuna `Mentor/arena-latest.json` olarak taşınır. Developer Agent durumu da `Mentor/developer-status.txt` dosyasına eklenir.

Developer Agent'in fast diagnostic gate'i artık dört sinyali birlikte kullanır: Training Lab, Live Research Eval, KRALİ Arena ve güncel Mentor trace. Training/Live yeşil olsa bile Arena failure veya Reviewer flag varsa Developer Agent izole `krali-dev-agent/<timestamp>` branch/worktree üzerinde otomatik candidate düzeltme turu başlatır. Candidate build-check geçmeden incelemeye hazır sayılmaz; **main branch'e otomatik merge yapılmaz**. Böylece sistem self-improving olur fakat self-deploying olmaz.

Yeni sürüm açıldığında Training Lab, Live Research Eval ve Arena sürüm bazlı otomatik çalışabilir. Arena açık-dünya problemi bulur, diğer iki temel regression katmanı yeşilse Developer Agent otomatik tetiklenir. Kullanıcının Mentor düğmesiyle gönderdiği paket artık runtime trace + Training + Live Eval + Arena + Developer Agent branch durumunu birlikte taşır. ChatGPT Mentor'un rolü mikro test taşıyıcısı olmaktan çıkıp failure cluster, candidate branch ve mimari yönü denetleyen üst seviye mentor olmaya doğru kayar.


**v0.8.15 Arena progress + headless planner reliability:** v0.8.14 gerçek Arena turunda ChatGPT Subscription/Cline semantic planner fallback iki North Star senaryosunda boş çıktı ile `status=9` verdi. Güncel Cline CLI headless JSON/Plan akışı doğrultusunda planner çağrısı `--plan --json --auto-approve true` olarak güncellendi; çalışma alanı hâlâ yalnızca Intelligence dizinidir ve command permission politikası tüm shell komutlarını reddeder. Planner retry sayısı 1, timeout 90 saniye olarak düşürüldü; iki Arena fallback bütçesi korunur.

Arena artık opak bir “test ediliyor” durumu göstermez. Her scenario başlamadan `N/Total • Senaryo • Apple Planner`, fallback sırasında `ChatGPT fallback`, ikinci görüş sırasında `Reviewer` ve sonunda `Arena tamamlandı` durumunu `arena-progress.txt` üzerinden yazar. AgentEngine bu ilerlemeyi yaklaşık 400 ms aralıkla UI'ya taşır. Böylece uzun Arena turlarında hangi katmanın çalıştığı veya nerede kaldığı görülebilir.


**v0.8.16 local mission contract repair + grounded Arena reviewer:** v0.8.15 Arena gerçek açık-dünya testinde Training Lab 30/30 ve Live Research Eval 2/2 yeşil kalırken Arena 0/6 verdi. Bu sonuç planner başarısızlığının klasik regression testlerinden bağımsız olduğunu doğruladı. Dört senaryoda hiçbir geçerli mission oluşmadı; masaüstü düzenleme mission'ı capability açısından doğruya yakın olup yalnızca locate outcome'unu eksik bıraktı; browser senaryosu ise eski/yanlış bağlamdan “Masaüstündeki videolar” gibi alakasız bir mission türetti. Local Reviewer ayrıca mission'da mevcut capability'leri “eksik” diyebildi. Developer Agent de Cline görevi sırasında başarısız oldu.

Semantic planning artık Cline fallback'a bağımlı değildir. Apple Foundation Models çıktısı parse edilemiyor veya capability contract açısından eksik kalıyorsa **Local Mission Contract Repair** devreye girer. Repair, kullanıcının güncel mesajını tek güvenilir görev-türü sinyali olarak kullanır; modelin kendi objective/step metni repair kararını yönlendiremez. Video kurgu görevleri Files/Metadata/Media Perception/Premiere/Screen, sosyal medya tasarımı Photoshop/Screen ve yeni marka ise ayrıca Research/Analyze, web arayüzü Browser, mail işi Mail, yerel dosya düzenleme Files/Move sözleşmelerine tamamlanır. Seçilen capability'lerden eksik semantic outcome'lar da geri türetilir. Yerel video görevlerinde gereksiz web research temizlenir; web görevi açıkça yerel dosya istemiyorsa stale Files/Perception capability'leri çıkarılır. Bağımlılık indeksleri yalnızca gerçekten önceki step'lere izin verecek biçimde sanitize edilir ve mission en fazla 10 step ile sınırlandırılır.

Apple modeli hiç yapılandırılmış JSON mission üretmezse, yalnızca güncel kullanıcı mesajından tanınabilen güvenli görev ailelerinde minimal bir core seed mission oluşturulur ve aynı deterministic contract repair uygulanır. Tanınmayan açık-dünya görevinde sahte operasyon mission'ı üretilmez; fallback zinciri korunur.

Arena Reviewer artık otomasyon için kör otorite değildir. Reviewer'ın “missing” iddiası mission'da capability gerçekten yoksa ve senaryonun deterministic required contract'ında bulunuyorsa; “unnecessary” iddiası capability gerçekten seçilmişse ve deterministic forbidden contract'ında bulunuyorsa bloklayıcı sayılır. Diğer serbest yorumlar ve risk notları Mentor'a taşınır fakat Developer Agent'i tek başına tetiklemez. Browser Arena senaryosu ayrıca yerel Files/Perception contamination'ını açıkça forbidden kabul eder.

Mentor Sync artık `Mentor/developer-log-tail.txt` ve `Mentor/semantic-planner-log-tail.txt` dosyalarını da gönderir. Developer Agent başlamadan Cline sürümü ve `cline doctor` çıktısı loglanır. Böylece Cline/OpenAI Codex OAuth, provider, model veya CLI kaynaklı failure'lar sonraki Mentor turunda Terminal çıktısı istemeden görülebilir.


**v0.8.17 Screen Perception probe foundation:** v0.8.16 gerçek diagnostic turunda Training Lab 30/30, Live Research Eval 2/2 ve KRALİ Arena 6/6 geçti. Local Mission Contract Repair altı açık-dünya senaryoda Cline fallback'a ihtiyaç duymadan gerekli capability zincirlerini üretti. Arena yeşil olduğunda eski Developer Agent failure durumu artık `no_change` olarak güncellenir; stale candidate durumu Mentor paketinde current health gibi görünmez.

Perception roadmap'inin ilk gerçek provider temeli eklendi. Yeni `AgentScreenPerception`, Apple'ın önerdiği ScreenCaptureKit yoluyla ana ekranı tek kare olarak yakalar; KRALİ'nin kendi uygulamasını capture filtresinden çıkarır. Vision `VNRecognizeTextRequest` ekrandaki okunabilir metni cihaz üzerinde çıkarır; ScreenCaptureKit shareable content verisinden görünür uygulama ve pencere başlıkları toplanır. Bu kanıtlar mevcut Apple Foundation Models text reasoning katmanına verilerek yalnızca gözlenen verilere dayalı kısa bir ekran durumu / doğrulama özeti oluşturulur. Capture 1600 px genişliğe kadar ölçeklenerek probe maliyeti sınırlanır.

Screen Perception ilk sürümde yalnızca manuel geliştirici probe'udur; `perception.screen` capability henüz available yapılmaz ve semantic executor'a bağlanmaz. Böylece gerçek Mac'te Screen Recording izni, capture doğruluğu, Vision metin çıkarımı ve semantic özet Mentor raporuyla doğrulanmadan runtime kendisini ekranı görebiliyor saymaz.

Geliştirici araçlarına **Screen Perception Probe** düğmesi eklendi. Sonuç `~/Library/Application Support/KRALI Agent/Mentor/screen-perception-latest.json` olarak kaydedilir ve Mentor Sync ile `Mentor/screen-perception-latest.json` dosyasına taşınır. Xcode target Info.plist üretimine `NSScreenCaptureUsageDescription` eklenmiştir. Sonraki kapı: gerçek probe başarılıysa dependency-aware semantic execution ile `perception.screen` runtime capability'sini açmak; ardından Accessibility tabanlı macOS Desktop Control provider'ına geçmek.


**v0.8.18 semantic planner resilience after Screen Probe integration:** v0.8.17 Mentor turunda Training Lab 30/30 ve Live Research Eval 2/2 yeşil kalırken Arena sonucu 2/6 oldu. Bu durum Screen Perception provider'ının kendisinden değil, Semantic Planner'ın Foundation Models çağrılarındaki hata toleransından kaynaklandı. Apple planner'ın ikinci self-review çağrısı geçici hata verdiğinde, daha önce deterministic contract repair ile oluşturulmuş geçerli mission da kaybedilip nil dönüyordu. Ayrıca browser görevinde contract repair stale Files capability'lerini required set'ten çıkarsa bile eski model step'leri listede kalabiliyor ve Arena bunları hâlâ seçilmiş capability sayıyordu.

Semantic planner artık self-review'ı advisory kabul eder. İlk/repaired mission geçerliyse ikinci Foundation Models çağrısı hata verse bile mission korunur. Apple'ın ilk planner çağrısı tamamen başarısız olsa, model kullanılamasa veya yapılandırılmış mission üretilemese dahi current user input'tan deterministic `contractFallbackMission` denenir. Bu fallback yalnızca tanınan görev ailesinde non-core capability ve operational-completeness sözleşmesi oluşuyorsa kabul edilir.

Mission Contract Repair artık required capability set'inden çıkarılan stale capability'lere ait eski step'leri de temizler. Böylece web görevinde eski `files.search/files.reveal` step'leri mission içinde kalamaz. Repair kararları yine yalnızca güncel kullanıcı mesajından türetilir.

Arena sonuç metni tamamlanmış test ile devam eden testi karıştırmayacak biçimde değiştirildi: `X/6 geçti • Y başarısız • Reviewer Z işaret`. Böylece örneğin 2/6 sonucu artık UI'da takılmış gibi görünmez; 2 pass + 4 fail olduğu açıkça anlaşılır.

Screen Perception Probe v0.8.17'de olduğu gibi manuel probe olarak kalır; `perception.screen` runtime capability'si henüz açılmaz. Önce Arena yeniden kararlı hale getirilecek, ardından gerçek screen-perception raporu doğrulanacaktır.


**v0.8.19 contract fallback hardening:** v0.8.18 Mentor turunda Training Lab 30/30 ve Live Research Eval 2/2 yeşil kalırken Arena 3/6 oldu. Video edit, desktop cleanup ve browser contact senaryoları geçti; new-brand design, work-mail ve research-to-design mission'ları geçerli mission üretemedi. Kök neden, Apple çıktısı parse edilse bile repair sonrası validation başarısızlığının doğrudan nil dönmesi ve deterministic contract fallback'a geçmemesiydi.

Semantic Planner artık repaired model mission validation'dan geçmezse current user input'tan `contractFallbackMission` dener. Foundation Models ilk çağrı, self-review çağrısı veya model availability katmanında hata verse de tanınan güvenli görev aileleri local contract üzerinden mission üretmeye devam eder. Deterministic fallback confidence 0.65'e çıkarılmıştır; runtime'ın 0.45 semantic mission kabul eşiğinin altında kalıp gereksiz Subscription fallback'a düşmez.

Arena ve runtime diagnostic'leri planner kaynağını artık daha doğru ayırır: doğrudan model mission'ı `Apple Foundation Models`, model mission'ının deterministic capability contract ile tamamlandığı yol `Apple + Contract Repair`, model olmadan current-input contract seed ile üretilen yol ise `Local Contract Repair` olarak görünür. Böylece Mentor turunda hangi katmanın gerçekten mission'ı kurtardığı anlaşılır.

Screen Perception Probe bu sürümde yine manuel probe olarak kalır ve runtime `perception.screen` availability açılmaz.


**v0.8.20 provider-neutral Core + lean planner + broader Arena:** KRALİ'nin mimari hedefi genel amaçlı bilgisayar ajanı olarak netleştirildi. Premiere, Photoshop, Browser, Mail, Desktop veya Finder Core değildir; yalnızca capability provider'lardır. Core kullanıcı hedefini semantik olarak çözer, uygun capability'leri seçer, yürütür ve doğrular. Sık kullanılan Premiere görevleri mimariyi video-editöre daraltmamalıdır.

Semantic Planner içindeki ikinci Apple Foundation Models self-review çağrısı kaldırıldı. Planner artık tek semantic model çağrısı → deterministic sanitize/contract repair → runtime coverage/verifier akışını kullanır. Arena zaten bağımsız Reviewer çalıştırdığı için planner içindeki ikinci LLM çağrısı gereksizdi ve model çağrısı kararsızlığını artırıyordu. Bu sadeleştirme daha az model çağrısıyla daha genel ve deterministik bir mission üretim hattı sağlar.

Capability→outcome türetimi de provider-neutral hale getirildi. `desktop.control` artık otomatik olarak `edit` sonucu anlamına gelmez; masaüstü provider yalnızca uygulama açma veya pencere öne getirme gibi edit olmayan işler için de kullanılabilir. `files.reveal` seçimi `open` outcome'unu besler. Premiere/Photoshop gerçek edit provider'ları olmaya devam eder.

KRALİ Arena 6 senaryodan 8 senaryoya genişletildi. Mevcut video edit, marka tasarımı, desktop cleanup, browser, mail ve research-to-design görevlerine iki medya-dışı genel bilgisayar görevi eklendi: Notlar uygulamasını açıp öne getirme (`desktop.control`) ve İndirilenler'deki en son PDF'i bulup Finder'da açma (`files.search + files.reveal`). Böylece gelecekteki değişiklikler KRALİ'yi Premiere/medya ajanına daraltırsa Arena bunu regression olarak yakalar.

Screen Perception Probe artık yalnızca başarı JSON'u üretmez; `screen-perception-status.txt` dosyasına running/success/failed durumu da yazar ve Mentor Sync bu tanıyı GitHub'a taşır. Capture başarısızsa bir sonraki Mentor turunda macOS izin/capture hatası doğrudan görülebilir.


**v0.8.21 generic desktop contract + explicit Screen Probe state:** v0.8.20 Mentor turunda Training Lab 30/30, Live Research Eval 2/2 ve genişletilmiş KRALİ Arena 7/8 geçti. Video edit, yeni marka tasarımı, desktop cleanup, browser, mail, research-to-design ve genel PDF/Finder açma senaryoları başarılı oldu. Tek failure medya-dışı genel bilgisayar görevi olan “Notlar uygulamasını aç ve pencereyi öne getir” idi.

Düzeltme uygulama adı özel-case'i olarak yapılmadı. Mission Contract Repair artık **generic desktop application open/focus** sınıfını tanır: kullanıcının mesajı herhangi bir uygulamayı açma, uygulamaya geçme veya pencereyi öne getirme hedefi içeriyorsa `desktop.control` capability'si ve `open` outcome'u eklenir. Bu sözleşme Notlar, Takvim, TextEdit, Finder veya gelecekteki başka bir macOS uygulaması için aynı şekilde çalışır.

Aynı katmana generic file-open sözleşmesi de eklendi. Kullanıcı bir dosya/PDF/belge/klasörü bulup Finder'da açmayı istediğinde `files.search + files.reveal`, `locate + open` sözleşmesi local fallback tarafından da üretilebilir. Böylece genel bilgisayar görevleri yalnızca Apple planner başarılı olduğunda çalışmak zorunda değildir.

Screen Perception Mentor tanısı artık probe hiç çalıştırılmadığında da sessiz kalmaz. Uygulama açılışında önceki Screen Perception raporu veya status yoksa `not_run|Screen Perception Probe henüz çalıştırılmadı.` durumu kaydedilir. Probe çalışırsa status `running/success/failed` olarak güncellenir. Böylece Mentor paketi rapor yokluğunu izin/capture hatasıyla karıştırmaz.


**v0.8.22 runtime Screen Perception + dependency-aware semantic execution:** v0.8.21 Mentor turunda Training Lab 30/30, Live Research Eval 2/2, KRALİ Arena 8/8 ve gerçek Screen Perception Probe başarılı oldu. Probe 1600×1040 ekran karesinden 24 OCR satırı ve 9 görünür pencere çıkardı; bu, ScreenCaptureKit + Vision provider'ın gerçek Mac ortamında çalıştığını doğruladı.

Probe raporunda önemli bir güvenlik/kalite açığı da görüldü: ChatGPT penceresinde görünen metin Screen Perception özetleyicisi tarafından hedef/talimat gibi yorumlanabildi. v0.8.22 ile ekran OCR'ı ve pencere başlıkları açıkça **untrusted visual evidence** olarak sınıflandırılır. Tek gerçek talimat `goal` alanıdır; ekrandaki metin içinde emir, prompt veya yapılacak iş yazsa bile semantic summarizer bunları uygulayamaz, hedef üretemez veya kullanıcı niyetini değiştiremez. Frontmost application bilgisi ayrıca rapora eklenir; boş uygulama isimleri temizlenir.

`perception.screen` capability artık gerçek read-only provider olarak available'dır. Semantic executor Screen Perception step'ini yalnızca mission dependency'leri gerçekten tamamlandıysa çalıştırır. Örneğin Premiere/Photoshop action blocked ise ona bağlı screen-verification step'i çalışmış sayılmaz. Semantic execution artık yalnızca capability ID düzeyinde değil mission step index düzeyinde tamamlanma takibi yapar; aynı capability birden fazla step'te kullanılsa bile başarısız/blocked dependency nedeniyle yanlışlıkla completed işaretlenmez.

Runtime Screen Perception başarılı olduğunda rapor Mentor store'a kaydedilir, semantic summary kullanıcı cevabına ekran gözlemi olarak eklenir ve runtime status yazılır. Capture başarısızsa capability yapılmış gibi gösterilmez; status failure olarak kaydedilir.

Mission Contract Repair'e provider-neutral genel ekran gözlemi sınıfı eklendi: “ekrana bak”, “ekranda ne var”, “ekranı kontrol et”, “görsel olarak kontrol et” benzeri hedefler `perception.screen` ile `analyze + explain` sonucuna yönlenebilir. Arena 8'den 9 senaryoya genişletildi; yeni medya-dışı regression “ekrana bak ve hangi uygulamanın önde olduğunu söyle” görevidir. Böylece ekran algısı Premiere/Photoshop doğrulamasına özel bir capability'ye dönüşemez.

Sonraki ana provider fazı: Accessibility/NSWorkspace tabanlı generic `desktop.control`. Önce Screen Perception runtime turu Mentor ile doğrulanmalı; ardından macOS uygulama açma, pencere odaklama ve AXUIElement tabanlı etkileşim eklenecektir.


**v0.8.23 generic Desktop Control probe foundation:** v0.8.22 Mentor turunda Training Lab 30/30, Live Research Eval 2/2, KRALİ Arena 9/9 ve gerçek runtime Screen Perception görevi başarılı oldu. Kullanıcının “Ekrana bak ve şu anda ne gördüğünü söyle.” komutu `perception.screen` üzerinden yürütüldü; frontmost application `KRALİ` olarak gözlendi, execution step completed ve verification passed oldu. OCR içeriği ekrandaki ChatGPT metninden yeni hedef türetmeden yalnızca görsel kanıt olarak işlendi.

Bu doğrulamadan sonra bir sonraki provider fazı başlatıldı: **generic macOS Desktop Control**. Yeni `AgentDesktopControl`, Apple'ın resmi `NSWorkspace` uygulama açma/aktivasyon API'sini ve Accessibility güven kontrolü için `AXIsProcessTrustedWithOptions` mekanizmasını kullanır. Accessibility izni kullanıcı tarafından verilmeden AX tabanlı UI kontrolü aktif edilmez.

İlk Desktop Control sürümü manuel geliştirici probe'udur. Probe güvenli test hedefi olarak Apple Notes/Notlar uygulamasını bundle identifier `com.apple.Notes` ile çözer; uygulama zaten açıksa öne getirir, kapalıysa `NSWorkspace.openApplication` ile açar. Sonrasında mevcut Screen Perception provider'ı kullanılarak gerçekten frontmost olup olmadığı görsel/sistem kanıtıyla doğrulanır. Probe raporu uygulamanın önceki/sonraki frontmost durumunu, Accessibility trust durumunu, uygulamanın zaten çalışıp çalışmadığını, launch/activate sonucunu ve Screen Perception doğrulamasını kaydeder.

Generic resolver yalnızca Notes'a özel değildir: `/Applications`, `/System/Applications`, `/System/Applications/Utilities` ve kullanıcı `~/Applications` alanlarında uygulama adını ve localized bundle display name'i çözebilir. Notes bundle ID sadece ilk güvenli probe'un deterministik olması için kullanılır.

`desktop.control` capability bu sürümde hâlâ `isAvailable=false` kalır. Gerçek Mac probe'unda üç koşul doğrulanmadan runtime açılmaz: (1) uygulama açma/öne getirme başarılı, (2) Screen Perception frontmost durumu doğrular, (3) Accessibility trust izinli. Probe sonucu `Mentor/desktop-control-latest.json` ve `Mentor/desktop-control-status.txt` olarak Mentor paketine eklenir.

Sonraki kapı: probe başarılı ve AX izinli ise `desktop.control` runtime provider olarak açılacak; ilk runtime operations yalnızca application open/focus gibi düşük riskli aksiyonlar olacak. AXUIElement ile button/menu/field etkileşimleri bundan sonra ayrı safety gate ile eklenecek.


**v0.8.24 low-risk desktop.app runtime + deep AX separation:** v0.8.23 gerçek Desktop Control Probe'da Notlar uygulaması başarıyla açıldı/öne getirildi ve Screen Perception frontmost durumu doğruladı (`activate=true`, `screen=true`). Probe sırasında Accessibility izin penceresi sonradan onaylandığı için ilk raporda `ax=false` kaldı; bu, NSWorkspace app activation başarısını etkilemedi.

Mimari bu sonuçla iki ayrı capability'ye bölündü. `desktop.app` düşük riskli uygulama keşfi/açma/öne getirme provider'ıdır; NSWorkspace üzerinden çalışır, Screen Perception ile frontmost sonucu doğrular ve runtime'da available'dır. `desktop.control` ise yalnızca Accessibility/AXUIElement tabanlı derin UI etkileşimi—menü, buton, alan, klavye, mouse, clipboard ve benzeri—içindir ve henüz unavailable kalır. Böylece KRALİ bir uygulamayı açabildiği için tüm macOS UI'sini kontrol edebildiğini iddia etmez.

`AgentDesktopControl` generic installed-app resolver içerir. `/Applications`, `/System/Applications`, `/System/Applications/Utilities` ve `~/Applications` içindeki uygulama bundle adlarını/localized display name'leri indeksler; kullanıcı mesajındaki uygulama adıyla eşleştirir. Runtime `desktop.app` step'i uygulamayı açar veya öne getirir, ardından Screen Perception ile doğrular. Doğrulama başarısızsa step completed sayılmaz.

Mission Contract Repair'de yalnız “uygulamayı aç / uygulamaya geç / pencereyi öne getir” hedefleri `desktop.app + open` sözleşmesine yönlenir ve gereksiz `desktop.control` kaldırılır. Tıklama, buton, menü, alan, yazma, sürükleme veya benzeri gerçek UI etkileşimi isteklerinde `desktop.control + perception.screen` tutulur ve capability bağlı olmadığı için dürüstçe blocked/partial kalır.

Desktop Probe artık Accessibility trust durumunu prompt öncesi ve prompt sonrası ayrı izler. İzin penceresinden sonra trust yaklaşık 6 saniyeye kadar yeniden kontrol edilir; kullanıcının izin vermesi aynı turda yakalanabiliyorsa final `accessibilityTrusted=true` raporlanır.

Arena'daki genel uygulama açma senaryosu artık `desktop.app` capability'sini bekler. Böylece düşük riskli app activation regression'ı, gelecekteki AX UI control geliştirmelerinden bağımsız test edilir.


**v0.8.25 app-open runtime hardening + verifier truthfulness:** v0.8.24 Mentor turunda automatic Arena raporu henüz v0.8.23 dosyasını taşıyordu; ancak v0.8.24 runtime trace'leri gerçek iki desktop.app problemi gösterdi. “takvim uygulamasını aç” mission'ında model önce screen observation, sonra desktop.app sırası üretmiş ve desktop.app partial kalmasına rağmen verifier yanlışlıkla PASS vermişti. “whatsapp uygulamasını aç” testinde ise gereksiz files.search capability mission'a sızmış ve app resolver uygulamayı çözememişti.

Generic app-open mission contract artık mevcut repo'daki explicit intent guard'larla birlikte yalnız güncel kullanıcı mesajına göre davranır. Basit uygulama açma/öne getirme görevleri `desktop.app` odaklı kalır; açıkça dosya, web veya uygulama içeriği analizi istenmedikçe Files/Web/Screen capability'leri mission'dan temizlenir. Derin UI interaction istenirse `desktop.control + perception.screen` ayrı tutulur.

Verifier'a doğrudan execution-state truth gate eklendi. Semantic mission içindeki herhangi bir zorunlu action step `partial`, `pending` veya `blocked` kaldıysa verification artık PASS veremez. Bu kontrol yalnız capability setlerinden dolaylı çıkarım yapmaz; gerçek executionSteps state'ini snapshot üzerinden verifier'a taşır. Böylece desktop.app veya başka bir gerçek action yürütülmediyse sonuç “tamamlandı” diye raporlanamaz.

Generic macOS app resolver localized ad konusunda güçlendirildi. Her uygulama için base bundle name, localized bundle display name ve Finder'ın macOS dilinde gösterdiği `FileManager.displayName(atPath:)` alias olarak indekslenir. Bu özellikle `Calendar.app → Takvim` gibi sistem yerelleştirmelerinde kullanıcı Türkçe uygulama adını yazdığında doğru eşleşmeyi sağlar. Resolver hala yalnız yüklü uygulamalar arasından seçim yapar; bulunmayan uygulama için dosya aramasına veya sahte başarıya düşmez.

v0.8.25'in doğrulama hedefi: startup Arena güncel sürümle yeniden 9/9 olmalı; ardından “Takvim uygulamasını aç” gibi düşük riskli app-open komutu `desktop.app` ile gerçekten çalışmalı ve Screen Perception ile frontmost doğrulanmalı. Accessibility/AXUIElement tabanlı `desktop.control` bu sürümde yine unavailable kalır.


**v0.8.26 updater build fix:** v0.8.25 ilk dağıtım denemesinde Swift build, `AgentVerificationSnapshot` modeline eklenen `incompleteRequiredActionCapabilityIDs` alanının Training Lab içindeki iki test initializer'ına taşınmaması nedeniyle durdu. Updater tasarımı build başarısızlığında mevcut kurulu uygulamayı yeniden açtığı için kullanıcı v0.8.24'te kaldı ve “güncelleme hazır” durumu devam etti.

Training Lab'daki `semantic-required-action-execution` test snapshot'ı artık bilinçli olarak `desktop.app` capability'sini incomplete required action olarak işaretler; `stale-goal-verifier-isolation` snapshot'ı ise boş incomplete set kullanır. Zincirleme `.attention` tip çıkarım hataları da bu initializer eksikliğinin giderilmesiyle çözülür.

Bu sürüm v0.8.25'in desktop.app/verifier/localized app resolver düzeltmelerini aynen korur; yalnızca build/install yolunu tekrar çalışabilir hale getirir.


**v0.8.27 natural-language app control hardening + probe UI clarification:** v0.8.26 Mentor turunda Desktop Control Probe tamamen yeşil oldu (`activate=true | ax=true | screen=true`). Böylece Accessibility izni, NSWorkspace activation ve Screen Perception doğrulaması gerçek Mac ortamında birlikte doğrulandı.

Runtime testleri üç ek açık gösterdi. “Takvim uygulamasını aç” Türkçe uygulama adını çözümleyemedi; “WhatsApp uygulamasını aç” uygulamayı buldu ancak tek `activate()` dönüş değeri false olduğu için gereğinden erken başarısız sayıldı; “XYZ123 diye bir uygulama aç” ifadesi ise generic app-open contract tarafından yakalanmadığı için Apple planner Files/Screen yoluna sapabildi.

App resolver artık her bundle için base name, Finder display name, aktif localized info ve bundle içindeki **tüm InfoPlist.strings localization adlarını** alias olarak indeksler. Böylece sistem dili/uygulama localization'ı farklı olsa bile `Calendar.app → Takvim` gibi eşleşmeler generic olarak çözülebilir. Bu Takvim'e özel hard-code değildir.

App activation artık tek `NSRunningApplication.activate()` Boolean sonucuna güvenmez. Launch başarılıysa kısa bir retry döngüsüyle gerçek frontmost uygulama bundle ID / alias üzerinden kontrol edilir; gerekirse activation tekrar denenir. Son başarı yine Screen Perception ile doğrulanır. Böylece yavaş açılan veya ilk activate çağrısında false dönen uygulamalar erken başarısız sayılmaz.

Mission Contract Repair generic “uygulama aç” kalıbını da tanır; “XYZ123 diye bir uygulama aç” gibi ifadeler artık desktop.app yoluna düşer. Kurulu olmayan uygulama için Files aramasına sapmak yerine desktop.app resolver açıkça application-not-found sonucu üretir.

Training Lab'daki semantic-required-action-execution testi yeni verifier hata metniyle uyumlandı. Test artık action incomplete olduğunda `attention` + `desktop.app` + tamamlanmadı/yürütülmedi sinyalini doğrular.

Geliştirici panelindeki Screen Perception Probe ve Desktop Control Probe butonları “Test” olarak etiketlendi ve panelde bu kontrollerin yalnız geliştirici tanısı olduğu açıklandı. Ürün ilkesi: normal kullanıcı capability çalıştırmak için ayrı butona basmaz; “Takvim'i aç”, “ekrana bak”, “Photoshop'ta şunu yap” gibi doğal dil hedefleri uygun provider'ı otomatik tetikler. Yeni capability'ler için kullanıcı-facing manuel çalıştır butonları üretilmeyecek.


**v0.8.28 normal-use performance pass + single-flight execution:** v0.8.27 Mentor zaman çizelgesi normal kullanım gecikmesinin önemli bir kısmının startup diagnostics ile çakıştığını gösterdi. Uygulama 12:41:51'de açıldı; Training Lab hemen çalıştı, Live Research yaklaşık 11 saniye sürdü ve Arena da aynı başlangıç penceresinde planner/reviewer yükü oluşturdu. Kullanıcı normal WhatsApp app-open görevini bu ağır geliştirici testleri sürerken gönderdi. Bu yüzden Training Lab, Live Research Eval ve Arena artık normal uygulama açılışında otomatik çalıştırılmaz. Son raporlar yüklenir; testler yalnız geliştirici tanısı gerektiğinde manuel çalıştırılır. Ürün runtime'ı test runner ile CPU/model/network paylaşmaz.

KRALİ execution modeli bu sürümde **single-flight** olarak sabitlendi. Bir görev yürürken chat composer, mikrofon ve quick action'lar kilitlenir; engine seviyesinde de ikinci `send` çağrısı reddedilir. Böylece kullanıcı “KRALİ düşünüyor” aşamasında ikinci görev gönderip iki mission'ın state, selectedCapabilities, verification ve Mentor trace alanlarını birbirine karıştırmaz. Çoklu/queued task modeli ileride ayrı bir scheduler olarak tasarlanabilir; mevcut sürümde doğruluk için tek aktif görev ilkesi kullanılır.

Basit `desktop.app` görevleri Apple Foundation Models semantic planner'ını beklemeden deterministic contract fallback ile planlanır. “X uygulamasını aç/öne getir” gibi tek amaçlı komutlar model planlama turunu atlar; karmaşık app içi etkileşim, dosya/web, analiz veya derin UI istekleri normal semantic planner yolunda kalır.

Low-risk app-open başarı doğrulaması da hızlandırıldı. `focusCandidate` zaten gerçek `NSWorkspace.frontmostApplication` bundle ID / localized alias kanıtını kontrol ettiği için başarılı normal yolda ScreenCaptureKit + Vision + semantic screen summarizer ikinci kez çalıştırılmaz. Screen Perception yalnız NSWorkspace frontmost doğrulaması başarısız/şüpheli olduğunda fallback olarak kullanılır. Bu değişiklik uygulamanın fiziksel cold-start süresini değiştirmez; fakat uygulama öne geldikten sonra KRALİ'nin cevap vermek için gereksiz birkaç saniye daha beklemesini kaldırır.

Chat pipeline'daki 180 ms yapay başlangıç gecikmesi kaldırıldı. Her görev artık başlangıç ve bitiş zamanını ölçer; Activity/Mentor trace içinde `Görev tamamlandı • X.XX sn` satırı bulunur. Sonraki performans optimizasyonları hissiyata değil gerçek tur sürelerine göre yapılacaktır.

Startup sırasında seçili çalışma alanının mevcut file index restore akışı şimdilik korunur; v0.8.27 Mentor'da ~1772 dosya / 68 klasör indeksleme aynı saniye içinde tamamlandığı için gözlenen ana gecikme kaynağı bu değil, ağır diagnostics + model/screen doğrulama zinciriydi.
