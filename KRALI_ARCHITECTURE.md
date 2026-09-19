# KRALİ — Core Architecture Roadmap

KRALİ'nin hedefi bir komut çalıştırıcı olmak değil; kullanıcının niyetini anlayan, bağlamı koruyan, plan üreten, uygun aracı seçen, sonucu doğrulayan ve zamanla çalışma tercihlerini öğrenen yerel bir kişisel ajan olmaktır.

## Tasarım ilkesi

Geliştirme sırası özellik sayısına göre değil, zeka iskeletine göre ilerler:

1. **Understanding** — doğal dili normalize et, niyet ve hedefi ayır.
2. **Context** — önceki konuşma, son arama ve aktif çalışma alanını koru.
3. **Principles** — güvenlik sınırları ve değişmez davranış kuralları.
4. **Planner** — tek komut yerine hedefe ulaşmak için alternatif planlar üret.
5. **Router** — gerekli modülleri kullanıcı seçmeden otomatik belirle.
6. **Executor** — izin verilen yerel işlemleri uygula.
7. **Verifier** — yapılan işin gerçekten tamamlandığını kontrol et.
8. **Memory / Learning** — açık kullanıcı tercihlerini ve tekrar eden çalışma kurallarını sakla.
9. **Multimodal / Tools** — görüntü, ses, tarayıcı, Premiere, mail ve diğer bağlantılar daha sonra bu çekirdeğe eklenir.

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
  → Router
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

## Sürüm aşamaları

### 0.6.x — Foundation
Yerel dosya algısı, güvenli aksiyonlar, intent, tarih çözümleme, bağlam ve temel planning.

### 0.7.x — Planner + Verifier
Çok adımlı görev planları, alternatif yol, işlem sonrası doğrulama ve başarısızlıkta ikinci plan.

**v0.7.0 başlangıcı:** Her tur için görünür yürütme planı oluşturulur. Executor sonrası Verifier, File Search ve güvenli File Actions durumunu tekrar okur. Doğrulanamayan gerçek işlemlerde Core otomatik olarak Plan B taşır; bağlantısı olmayan araçlarda sahte başarı üretmez.

### 0.8.x — Memory
Kısa süreli konuşma belleği ile kalıcı kullanıcı tercihlerini ayırma; bağlam özetleme.

### 0.9.x — Perception
Ses, ekran/görsel ve dosya içeriğini ortak bir bağlam modelinde birleştirme.

### 1.0 — Tool-using KRALİ
Core olgunlaştıktan sonra Browser, Work/Mail, Premiere ve harici model bağlantılarının güvenli orkestrasyonu.
