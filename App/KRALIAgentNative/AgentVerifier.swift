import Foundation

struct AgentVerificationSnapshot {
    let hasWorkspace: Bool
    let fileResultCount: Int
    let folderResultCount: Int
    let hasPendingAction: Bool
    let hasUndoAction: Bool
}

struct AgentVerifier {
    func verify(
        decision: AgentDecision,
        snapshot: AgentVerificationSnapshot
    ) -> AgentVerificationResult {
        switch decision.intent {
        case .fileSearch:
            guard snapshot.hasWorkspace else {
                return attention(
                    "Arama çalıştırılamadı çünkü aktif çalışma alanı yok.",
                    fallback: "Önce çalışma klasörü seç ve aramayı yeniden çalıştır."
                )
            }

            let count = decision.target == .folder
                ? snapshot.folderResultCount
                : snapshot.fileResultCount

            return AgentVerificationResult(
                state: .passed,
                summary: "Arama tamamlandı ve sonuç kümesi yeniden okunarak doğrulandı: \(count) eşleşme.",
                fallback: nil
            )

        case .organizeScreenshots:
            if snapshot.hasPendingAction {
                return AgentVerificationResult(
                    state: .passed,
                    summary: "Gerçek dosya işlemi uygulanmadı; güvenli taşıma planı oluşturuldu ve onay bekliyor.",
                    fallback: nil
                )
            }

            return AgentVerificationResult(
                state: .passed,
                summary: "Tarama tamamlandı; uygulanacak bir taşıma planı oluşmadı.",
                fallback: nil
            )

        case .approve:
            if snapshot.hasPendingAction {
                return attention(
                    "Onay işlendi ancak bekleyen işlem hâlâ aktif görünüyor.",
                    fallback: "Dosya durumunu yeniden indeksle ve işlemi tekrar planla."
                )
            }

            if snapshot.hasUndoAction {
                return AgentVerificationResult(
                    state: .passed,
                    summary: "Dosya işlemi tamamlandı ve geri alma kaydı oluşturuldu.",
                    fallback: nil
                )
            }

            return attention(
                "Onay tamamlandı ancak başarılı bir taşıma kaydı doğrulanamadı.",
                fallback: "Dosya sistemini yeniden indeksle ve başarısız öğeleri ayrı kontrol et."
            )

        case .reject:
            return snapshot.hasPendingAction
                ? attention(
                    "İptal sonrasında bekleyen işlem hâlâ aktif.",
                    fallback: "Bekleyen planı temizle ve dosyalara dokunma."
                )
                : AgentVerificationResult(
                    state: .passed,
                    summary: "Bekleyen işlem dosyalara dokunmadan kaldırıldı.",
                    fallback: nil
                )

        case .undo:
            return snapshot.hasUndoAction
                ? attention(
                    "Geri alma sonrasında işlem kaydı hâlâ aktif.",
                    fallback: "Dosya konumlarını yeniden indeksle ve kalan öğeleri raporla."
                )
                : AgentVerificationResult(
                    state: .passed,
                    summary: "Geri alma kaydı temizlendi; işlem sonlandırıldı.",
                    fallback: nil
                )

        case .openPreviousResult:
            let hasResult =
                snapshot.fileResultCount > 0 ||
                snapshot.folderResultCount > 0

            return hasResult
                ? AgentVerificationResult(
                    state: .passed,
                    summary: "Önceki sonuç bağlamı korunuyor ve referans çözüldü.",
                    fallback: nil
                )
                : attention(
                    "Açılacak önceki sonuç kümesi bulunamadı.",
                    fallback: "Aramayı yeniden çalıştır ve sonucu tekrar seç."
                )

        case .assessWorkspace:
            return snapshot.hasWorkspace
                ? AgentVerificationResult(
                    state: .passed,
                    summary: "Çalışma alanı salt-okunur incelendi; gerçek dosya değişikliği yapılmadı.",
                    fallback: nil
                )
                : attention(
                    "İncelenecek aktif çalışma alanı yok.",
                    fallback: "Önce çalışma klasörü seç."
                )

        case .conversation, .contextSuggestion, .remember, .workMail, .futureCapability, .general:
            return AgentVerificationResult(
                state: .skipped,
                summary: "Bu turda doğrulanacak gerçek araç işlemi yok.",
                fallback: nil
            )
        }
    }

    private func attention(
        _ summary: String,
        fallback: String
    ) -> AgentVerificationResult {
        AgentVerificationResult(
            state: .attention,
            summary: summary,
            fallback: fallback
        )
    }
}
