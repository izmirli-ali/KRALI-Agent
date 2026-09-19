import Foundation
import AppKit

@MainActor
final class AgentEngine: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Hazırım. Bana normal konuşur gibi görev ver; hangi alt modülün gerektiğini ben seçeceğim.")
    ]

    @Published var activities: [ActivityItem] = []
    @Published var activeRoute: [String] = ["Core"]
    @Published var memories: [String] = []

    @Published var selectedRootURL: URL?
    @Published var indexedFiles: [FileRecord] = []
    @Published var pendingFileAction: PendingFileAction?
    @Published var lastUndoAction: UndoFileAction?

    @Published var voiceOutputEnabled = true
    @Published var busy = false

    let speech = SpeechController()

    private let memoryKey = "krali.native.memories.v1"
    private let fileManager = FileManager.default

    init() {
        loadMemory()
        log("KRALİ Core hazır")
        log("Otomatik alt-modül yönlendirme aktif")
    }

    // MARK: - Chat

    func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(role: .user, text: text))
        activeRoute = chooseModules(for: text)
        log("Niyet analiz edildi")
        log("Otomatik rota: \(activeRoute.joined(separator: " → "))")

        busy = true

        Task {
            try? await Task.sleep(for: .milliseconds(220))
            let reply = makeReply(for: text)
            messages.append(ChatMessage(role: .assistant, text: reply))
            busy = false

            if voiceOutputEnabled {
                speech.speak(reply)
            }
        }
    }

    private func makeReply(for text: String) -> String {
        let t = normalize(text)

        if pendingFileAction != nil && isApproval(t) {
            return approvePendingFileAction()
        }

        if pendingFileAction != nil && isRejection(t) {
            pendingFileAction = nil
            log("Bekleyen dosya işlemi iptal edildi")
            return "Tamam, dosya işlemini iptal ettim."
        }

        if containsAny(t, ["geri al", "undo"]) {
            return undoLastFileAction()
        }

        if let explicitRule = memoryIntent(from: text) {
            addMemory(explicitRule)
            return "Kaydettim: “\(explicitRule)”. Uygun görevlerde bunu otomatik uygulayacağım."
        }

        if isScreenshotOrganizeIntent(t) {
            return prepareScreenshotOrganizeAction()
        }

        if containsAny(t, ["17:55", "mail"]) {
            log("Günlük rapor kaynağı seçildi")
            log("Mail taslağı oluşturma akışı hazırlandı")
            log("Gönderim noktası onay gerektiriyor")

            return "Günlük iş maili akışını kendim seçtim. Gerçek sürümde raporu okuyup taslağı hazırlayacağım; sen onay vermeden göndermeyeceğim."
        }

        if containsAny(t, ["reels", "kurgu", "premiere", "video"]) {
            log("Director görevi parçaladı")

            if !indexedFiles.isEmpty {
                log("\(indexedFiles.count) indeksli dosya aday olarak görüldü")
            }

            log("Premiere → Auto Cut")
            log("Premiere → Caption")
            log("QC → çalışma kopyası kontrolü")

            return "Kurgu için File Memory, Director ve Premiere modüllerini otomatik devreye aldım. Gerçek Premiere bağlantısı sonraki modülde eklenecek."
        }

        if containsAny(t, ["hata", "sorun", "chatgpt", "openai", "bilmiyorsan"]) {
            log("Önce yerel proje/hafıza taranacak")
            log("Yetersizse OpenAI danışmanı çağrılacak")

            return "Önce mevcut bilgi, proje ve geçmiş çözümleri incelerim. Yeterli olmazsa gerekli bağlamı paketleyip ChatGPT/OpenAI tarafına danışırım. Bu demo henüz gerçek OpenAI bağlantısı kurmuyor."
        }

        if containsAny(t, ["dosya", "bul", "logo", "klasör", "masaüst", "ekran görünt", "ekran resmi"]) {
            log("Yerel dosya indeksinde arama")

            guard selectedRootURL != nil else {
                return "Önce sağdaki “Klasör seç ve indeksle” ile çalışacağım klasörü seç. Dosya işlemlerini yalnızca senin seçtiğin klasör içinde yapacağım."
            }

            if !indexedFiles.isEmpty {
                let sample = indexedFiles.prefix(3).map(\.name).joined(separator: ", ")
                return "Yerel dosya indeksini kullanıyorum. Örnek kayıtlar: \(sample)"
            }

            return "Seçtiğin klasörde henüz indekslenmiş dosya yok."
        }

        if containsAny(t, ["duyabiliyor musun", "beni duyuyor musun", "sesim geliyor mu"]) {
            return "Evet, sesli komutun yazıya çevrildi ve bana ulaştı."
        }

        return "Görevi aldım. \(activeRoute.joined(separator: " → ")) rotasını otomatik seçtim."
    }

    // MARK: - File Selection & Indexing

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "KRALİ'nin çalışacağı klasörü seç"
        panel.message = "KRALİ bu sürümde gerçek dosya işlemlerini yalnızca seçtiğin klasörün doğrudan içindeki dosyalarda yapar."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        selectedRootURL = url
        pendingFileAction = nil
        lastUndoAction = nil
        indexSelectedFolder()

        log("Çalışma klasörü seçildi: \(url.lastPathComponent)")
    }

    func indexSelectedFolder() {
        guard let root = selectedRootURL else { return }

        do {
            let urls = try fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            let records = urls.compactMap { url -> FileRecord? in
                do {
                    let values = try url.resourceValues(forKeys: [.isRegularFileKey])
                    guard values.isRegularFile == true else { return nil }

                    let name = url.lastPathComponent
                    let ext = url.pathExtension.lowercased()

                    return FileRecord(
                        url: url,
                        name: name,
                        relativePath: name,
                        fileExtension: ext,
                        isScreenshot: isScreenshotFileName(name, extension: ext)
                    )
                } catch {
                    return nil
                }
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

            indexedFiles = records

            let screenshotCount = records.filter(\.isScreenshot).count
            log("\(records.count) doğrudan dosya indekslendi")
            log("\(screenshotCount) ekran görüntüsü adayı bulundu")
        } catch {
            indexedFiles = []
            log("Klasör indekslenemedi: \(error.localizedDescription)")
        }
    }

    var screenshotCount: Int {
        indexedFiles.filter(\.isScreenshot).count
    }

    // MARK: - Real File Actions

    private func prepareScreenshotOrganizeAction() -> String {
        activeRoute = ["Core", "File Memory", "File Actions"]

        guard let root = selectedRootURL else {
            log("Dosya işlemi için klasör seçimi bekleniyor")
            return "Önce sağdaki “Klasör seç ve indeksle” ile Masaüstü klasörünü seç. Bu sürüm dosyaları yalnızca senin seçtiğin klasör içinde değiştirecek."
        }

        indexSelectedFolder()

        let screenshots = indexedFiles.filter(\.isScreenshot)

        guard !screenshots.isEmpty else {
            log("Ekran görüntüsü bulunamadı")
            return "\(root.lastPathComponent) içinde doğrudan duran ekran görüntüsü bulamadım."
        }

        let destination = root.appendingPathComponent("Ekran Görüntüleri", isDirectory: true)

        pendingFileAction = PendingFileAction(
            title: "Ekran görüntülerini toparla",
            detail: "\(screenshots.count) ekran görüntüsü “Ekran Görüntüleri” klasörüne taşınacak.",
            sourceURLs: screenshots.map(\.url),
            destinationFolderURL: destination
        )

        log("\(screenshots.count) ekran görüntüsü bulundu")
        log("Gerçek dosya taşıma işlemi onay bekliyor")

        return "\(screenshots.count) ekran görüntüsü buldum. “Ekran Görüntüleri” klasörü oluşturup hepsini içine taşıyacağım. Onaylıyor musun?"
    }

    func approvePendingFileAction() -> String {
        guard let action = pendingFileAction else {
            return "Onay bekleyen bir dosya işlemi yok."
        }

        guard let root = selectedRootURL else {
            pendingFileAction = nil
            return "Çalışma klasörü artık seçili değil; işlemi durdurdum."
        }

        do {
            try fileManager.createDirectory(
                at: action.destinationFolderURL,
                withIntermediateDirectories: true
            )
        } catch {
            log("Hedef klasör oluşturulamadı: \(error.localizedDescription)")
            return "Hedef klasörü oluşturamadım: \(error.localizedDescription)"
        }

        var moves: [FileMoveRecord] = []
        var failed = 0

        for source in action.sourceURLs {
            // Safety: only direct children of the user-selected root are movable.
            guard source.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL else {
                failed += 1
                continue
            }

            guard fileManager.fileExists(atPath: source.path) else {
                failed += 1
                continue
            }

            let preferred = action.destinationFolderURL.appendingPathComponent(source.lastPathComponent)
            let destination = collisionSafeURL(preferred)

            do {
                try fileManager.moveItem(at: source, to: destination)
                moves.append(
                    FileMoveRecord(
                        originalURL: source,
                        movedURL: destination
                    )
                )
            } catch {
                failed += 1
                log("Taşınamadı: \(source.lastPathComponent) — \(error.localizedDescription)")
            }
        }

        pendingFileAction = nil

        if !moves.isEmpty {
            lastUndoAction = UndoFileAction(moves: moves)
        }

        indexSelectedFolder()

        log("\(moves.count) dosya gerçekten taşındı")

        if failed > 0 {
            log("\(failed) dosya taşınamadı")
        }

        if moves.isEmpty {
            return "Hiçbir dosyayı taşıyamadım. Activity bölümündeki hatalara bakabiliriz."
        }

        if failed == 0 {
            return "\(moves.count) ekran görüntüsünü “Ekran Görüntüleri” klasörüne taşıdım. İstersen “geri al” diyebilirsin."
        }

        return "\(moves.count) dosyayı taşıdım, \(failed) dosyada hata oluştu. Başarılı taşıma işlemlerini “geri al” komutuyla geri çevirebilirsin."
    }

    func cancelPendingFileAction() {
        guard pendingFileAction != nil else { return }
        pendingFileAction = nil
        log("Bekleyen dosya işlemi kullanıcı tarafından iptal edildi")
        messages.append(ChatMessage(role: .assistant, text: "Dosya işlemini iptal ettim."))
    }

    func undoLastFileAction() -> String {
        guard let undo = lastUndoAction else {
            return "Geri alınabilecek bir dosya işlemi yok."
        }

        var restored = 0
        var failed = 0

        for move in undo.moves.reversed() {
            guard fileManager.fileExists(atPath: move.movedURL.path) else {
                failed += 1
                continue
            }

            let target = collisionSafeURL(move.originalURL)

            do {
                try fileManager.moveItem(at: move.movedURL, to: target)
                restored += 1
            } catch {
                failed += 1
                log("Geri alınamadı: \(move.movedURL.lastPathComponent) — \(error.localizedDescription)")
            }
        }

        lastUndoAction = nil
        indexSelectedFolder()

        log("\(restored) dosya işlemi geri alındı")

        if failed == 0 {
            return "\(restored) dosyayı önceki konumuna geri taşıdım."
        }

        return "\(restored) dosyayı geri aldım, \(failed) dosyada hata oluştu."
    }

    private func collisionSafeURL(_ preferred: URL) -> URL {
        guard fileManager.fileExists(atPath: preferred.path) else {
            return preferred
        }

        let directory = preferred.deletingLastPathComponent()
        let ext = preferred.pathExtension
        let base = preferred.deletingPathExtension().lastPathComponent

        var counter = 2

        while true {
            let name = ext.isEmpty
                ? "\(base) \(counter)"
                : "\(base) \(counter).\(ext)"

            let candidate = directory.appendingPathComponent(name)

            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }

            counter += 1
        }
    }

    private func isScreenshotFileName(_ name: String, extension ext: String) -> Bool {
        let imageExtensions = Set(["png", "jpg", "jpeg", "heic", "tif", "tiff", "webp"])
        guard imageExtensions.contains(ext) else { return false }

        let n = normalize(name)

        let patterns = [
            "ekran resmi",
            "ekran goruntusu",
            "ekran görüntüsü",
            "screenshot",
            "screen shot"
        ]

        return patterns.contains { n.contains($0) }
    }

    // MARK: - Memory

    func addMemory(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        memories.append(text)
        saveMemory()
        log("Yeni çalışma kuralı hafızaya kaydedildi")
    }

    private func memoryIntent(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let range = trimmed.range(
            of: "öğret:",
            options: [.caseInsensitive, .diacriticInsensitive]
        ) {
            return cleanedMemory(String(trimmed[range.upperBound...]))
        }

        let lower = normalize(trimmed)

        let explicitTriggers = [
            "bunu unutma",
            "aklinda tut",
            "aklında tut",
            "bunu hatirla",
            "bunu hatırla",
            "hatirla",
            "hatırla"
        ]

        if explicitTriggers.contains(where: { lower.contains($0) }) {
            var rule = trimmed

            for trigger in explicitTriggers {
                rule = rule.replacingOccurrences(
                    of: trigger,
                    with: "",
                    options: [.caseInsensitive, .diacriticInsensitive]
                )
            }

            return cleanedMemory(rule)
        }

        if lower.hasPrefix("bundan sonra ") {
            return cleanedMemory(String(trimmed.dropFirst("bundan sonra ".count)))
        }

        return nil
    }

    private func cleanedMemory(_ raw: String) -> String? {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? nil : cleaned
    }

    private func loadMemory() {
        if let saved = UserDefaults.standard.stringArray(forKey: memoryKey),
           !saved.isEmpty {
            memories = saved
        } else {
            memories = [
                "Ana projeyi doğrudan değiştirme; çalışma kopyasında ilerle.",
                "Basit işleri yerelde çöz; karmaşık problemde gerekirse güçlü modele danış."
            ]
        }
    }

    private func saveMemory() {
        UserDefaults.standard.set(memories, forKey: memoryKey)
    }

    // MARK: - Intent Helpers

    private func chooseModules(for text: String) -> [String] {
        let t = normalize(text)
        var modules = ["Core"]

        if containsAny(t, ["dosya", "klasör", "çekim", "bul", "logo", "arşiv", "masaüst", "masaustu", "ekran görünt", "ekran gorunt", "ekran resmi", "toparla", "taşı", "tasi"]) {
            modules.append("File Memory")
        }

        if isScreenshotOrganizeIntent(t) || pendingFileAction != nil {
            modules.append("File Actions")
        }

        if containsAny(t, ["reels", "video", "kurgu", "premiere", "altyaz", "export", "sequence"]) {
            modules += ["Director", "Premiere"]
        }

        if containsAny(t, ["mail", "gmail", "17:55", "faruk", "muammer"]) {
            modules.append("Work/Mail")
        }

        if containsAny(t, ["chatgpt", "openai", "hata", "sorun", "araştır", "bilmiyorsan"]) {
            modules.append("Research/OpenAI")
        }

        if containsAny(t, ["öğret", "bundan sonra", "tercih", "hep böyle", "unutma", "aklında tut", "hatırla"]) {
            modules.append("Learning")
        }

        return Array(NSOrderedSet(array: modules)) as? [String] ?? modules
    }

    private func isScreenshotOrganizeIntent(_ t: String) -> Bool {
        let screenshot = containsAny(t, ["ekran görünt", "ekran gorunt", "ekran resmi", "screenshot", "screen shot"])
        let action = containsAny(t, ["toparla", "taşı", "tasi", "klasöre", "klasore", "düzenle", "duzenle"])
        return screenshot && action
    }

    private func isApproval(_ t: String) -> Bool {
        let exact = [
            "evet",
            "onayla",
            "tamam",
            "devam",
            "yap",
            "olur",
            "taşı",
            "tasi",
            "onaylıyorum",
            "onayliyorum"
        ]
        return exact.contains(t)
    }

    private func isRejection(_ t: String) -> Bool {
        let exact = [
            "hayır",
            "hayir",
            "iptal",
            "vazgeç",
            "vazgec",
            "yapma"
        ]
        return exact.contains(t)
    }

    private func normalize(_ text: String) -> String {
        text
            .lowercased(with: Locale(identifier: "tr_TR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsAny(_ text: String, _ values: [String]) -> Bool {
        values.contains { text.contains($0) }
    }

    private func log(_ text: String) {
        activities.insert(ActivityItem(text: text), at: 0)

        if activities.count > 120 {
            activities.removeLast()
        }
    }
}
