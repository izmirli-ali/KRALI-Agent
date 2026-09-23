# Mentor/History — repository policy

Bu klasör Git repository içinde bounded tutulur.

- Tam Mentor geçmişi kullanıcının Mac'inde `~/Library/Application Support/KRALI Agent/Mentor/History` altında kalır.
- `Scripts/publish-mentor-trace.command` local History klasörüne yazmaz, dosya silmez ve History JSON'larını GitHub reposuna aynalamaz.
- Git tarafında yalnız `Mentor/latest.json` ve diğer bounded `*-latest.json` / `*-status.txt` diagnostic snapshot'ları yayınlanır.
- Daha önce commit edilmiş History dosyaları Git geçmişinde kalır; history rewrite yapılmaz.
- Repo tarafında yeniden history retention istenirse bu ayrı ve açıkça bounded bir politika ile eklenmelidir.
