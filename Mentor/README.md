# KRALİ Mentor Bridge

Bu klasör KRALİ'nin geliştirme dönemindeki **mentor geri-bildirim köprüsüdür**.

## Amaç

KRALİ her görevin sonunda yerel olarak yapılandırılmış bir mentor trace üretir. Trace; kullanıcının isteğini, Goal Contract'ı, seçilen capability'leri, planı, execution durumlarını, Verifier sonucunu, research kaynaklarını ve nihai cevabı içerir.

Yerel dosya:

```
~/Library/Application Support/KRALI Agent/Mentor/latest.json
```

Uygulamadaki **Mentor Sync** işlemi bu dosyanın son sürümünü private GitHub reposundaki:

```
Mentor/latest.json
```

konumuna gönderir.

Training Lab raporu varsa aynı senkron ayrıca:

```
Mentor/training-latest.json
```

dosyasını da gönderir. Bu rapor tek tek kullanıcı testi gerektirmeden Core ve North Star senaryolarının toplu sonucunu içerir.

Böylece kullanıcı ChatGPT'ye sadece **“KRALİ mentor kaydına bak”** diyebilir. ChatGPT private GitHub bağlantısı üzerinden gerçek trace'i ve varsa Training Lab toplu raporunu okuyup davranış hatalarını teşhis edebilir ve kaynak kodu güncelleyebilir.

## Training Lab

Training Lab; araştırma güvenilirliği, marka analizi, genel analiz/çıkarım, bağımsız fikir üretme, dosya görevleri, bağlam, capability gap, güvenlik sınırları ve henüz tamamlanmamış North Star davranışları için yerel senaryolar çalıştırır.

İki skor ayrı tutulur:

- **Core:** bugün güvenilir çalışması gereken temel davranışlar.
- **North Star:** KRALİ'nin nihai hedefindeki henüz gelişmekte olan genel ajan davranışları.

Başarısız senaryolar hata olarak saklanır; kullanıcı bunları tek tek yeniden üretmek zorunda değildir.

## Maliyet

Mentor Bridge OpenAI API çağrısı yapmaz. Kullanıcının mevcut ChatGPT aboneliği dışında ayrı API ücreti gerektirmez.

## Güvenlik

- Trace kullanıcı mesajı ve KRALİ cevabı içerebilir.
- Senkron yalnızca kullanıcının açıkça **Mentor Sync** işlemini başlatmasıyla yapılır.
- Repo temiz değilse script otomatik commit yapmaz.
- Mentor trace herhangi bir uzaktan kodu indirip çalıştırmaz.
- ChatGPT mentorluğu kod değişikliği önerebilir/uygulayabilir; KRALİ'nin kendi kendine sessizce yeni izin veya capability etkinleştirmesi ayrı onay gerektirir.


## Live Research Eval

Yeni sürümlerde gerçek internet araştırma kalitesi ayrı bir canlı test paketiyle ölçülür. Son rapor:

```
Mentor/live-eval-latest.json
```

dosyasına senkronlanır. Bu rapor statik Training Lab'den farklı olarak gerçek arama sağlayıcılarını ve sayfa-içi evidence okumasını çalıştırır; kaynak sayısı, domain çeşitliliği ve deep-reading başarısını gösterir. Mentor bu raporu kullanarak “iskelet geçti ama gerçek araştırma bozuk” durumlarını otomatik ayırabilir.
