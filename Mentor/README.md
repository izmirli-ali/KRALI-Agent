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

Böylece kullanıcı ChatGPT'ye sadece **“KRALİ mentor kaydına bak”** diyebilir. ChatGPT private GitHub bağlantısı üzerinden gerçek trace'i okuyup davranış hatasını teşhis edebilir ve kaynak kodu güncelleyebilir.

## Maliyet

Mentor Bridge OpenAI API çağrısı yapmaz. Kullanıcının mevcut ChatGPT aboneliği dışında ayrı API ücreti gerektirmez.

## Güvenlik

- Trace kullanıcı mesajı ve KRALİ cevabı içerebilir.
- Senkron yalnızca kullanıcının açıkça **Mentor Sync** işlemini başlatmasıyla yapılır.
- Repo temiz değilse script otomatik commit yapmaz.
- Mentor trace herhangi bir uzaktan kodu indirip çalıştırmaz.
- ChatGPT mentorluğu kod değişikliği önerebilir/uygulayabilir; KRALİ'nin kendi kendine sessizce yeni izin veya capability etkinleştirmesi ayrı onay gerektirir.
