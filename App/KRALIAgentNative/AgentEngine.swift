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
    @Published var indexedFolders: [FolderRecord] = []
    @Published var pendingFileAction: PendingFileAction?
    @Published var lastUndoAction: UndoFileAction?
    @Published var fileSearchResults: [FileRecord] = []
    @Published var folderSearchResults: [FolderRecord] = []
    @Published var fileSearchTitle = ""

    @Published var currentGoal = "Hazır"
    @Published var currentPlan = "Yeni görevi bekliyor"
    @Published var currentAlternatives: [String] = []

    @Published var voiceOutputEnabled = true
    @Published var busy = false

    let speech = SpeechController()

    private let memoryKey = "krali.native.memories.v1"
    private let selectedRootKey = "krali.native.selectedRootPath.v1"
    private let fileManager = FileManager.default
    private let brain = AgentBrain()
    private var lastDecision: AgentDecision?

    init() {
        loadMemory()
        log("KRALİ Core hazır")
        log("Otomatik alt-modül yönlendirme aktif")
        restoreSelectedFolder()
    }

    // MARK: - Chat

    func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(role: .user, text: text))

        let decision = brain.analyze(
            text,
            context: brainContext()
        )

        activeRoute = decision.route
        currentGoal = decision.goal
        currentPlan = decision.selectedPlan
        currentAlternatives = decision.alternatives
        lastDecision = decision

        log("KRALİ Core hedefi çıkardı: \(decision.goal)")
        log("Seçilen plan: \(decision.selectedPlan)")
        log("Otomatik rota: \(activeRoute.joined(separator: " → "))")

        busy = true

        Task {
            try? await Task.sleep(for: .milliseconds(180))
            let baseReply = makeReply(for: text, decision: decision)
            let reply = appendSuggestion(
                to: baseReply,
                suggestion: decision.proactiveSuggestion
            )

            messages.append(ChatMessage(role: .assistant, text: reply))
            busy = false

            if voiceOutputEnabled {
                speech.speak(reply)
            }
        }
    }

    private func makeReply(
        for text: String,
        decision: AgentDecision
    ) -> String {
        switch decision.intent {
        case .approve:
            return approvePendingFileAction()

        case .reject:
            pendingFileAction = nil
            log("Bekleyen dosya işlemi iptal edildi")
            return "Tamam, dosya işlemini iptal ettim."

        case .undo:
            return undoLastFileAction()

        case .conversation:
            return conversationReply(for: text)

        case .assessWorkspace:
            return assessWorkspace()

        case .remember:
            if let explicitRule = memoryIntent(from: text) {
                addMemory(explicitRule)
                return "Kaydettim: “\(explicitRule)”. Uygun görevlerde bunu otomatik uygulayacağım."
            }
            return "Bunu bir çalışma kuralı olarak algıladım fakat kaydedilecek kısmı net çıkaramadım."

        case .organizeScreenshots:
            return prepareScreenshotOrganizeAction()

        case .fileSearch:
            if decision.target == .folder {
                return searchIndexedFolders(
                    for: text,
                    decision: decision
                )
            }

            return searchIndexedFiles(
                for: text,
                decision: decision
            )

        case .openPreviousResult:
            return openPreviousResult(
                selection: decision.resultSelection
            )

        case .contextSuggestion:
            return suggestFromPreviousResults()

        case .workMail:
            log("Mail görevi planlandı; gönderim onay gerektiriyor")
            return "Mail hedefini anladım. Şimdilik gerçek mail bağlantısını çalıştırmadan önce kaynak ve taslak aşamasını ayrı tutuyorum."

        case .futureCapability:
            return "Bu hedefi anladım fakat ilgili dış araç henüz KRALİ'ye bağlı değil. Mevcut yerel araçlarla yapılabilecek kısmı ayırıp güvenli plan üretebilirim."

        case .general:
            return "Hedefi analiz ettim fakat mevcut yerel araçlardan biriyle güvenilir biçimde eşleştiremedim. Şu an en güvenli planım: \(decision.selectedPlan)."
        }
    }

    private func brainContext() -> AgentContextSnapshot {
        AgentContextSnapshot(
            hasWorkspace: selectedRootURL != nil,
            workspaceName: selectedRootURL?.lastPathComponent,
            fileCount: indexedFiles.count,
            imageCount: imageCount,
            videoCount: videoCount,
            projectCount: projectCount,
            documentCount: documentCount,
            screenshotCount: screenshotCount,
            hasPendingAction: pendingFileAction != nil,
            previousFileResultCount: fileSearchResults.count,
            previousFolderResultCount: folderSearchResults.count,
            lastTarget: lastDecision?.target,
            lastGoal: lastDecision?.goal
        )
    }

    private func appendSuggestion(
        to reply: String,
        suggestion: String?
    ) -> String {
        guard let suggestion, !suggestion.isEmpty else {
            return reply
        }

        return reply + "\n\nÖnerim: " + suggestion
    }

    private func conversationReply(for text: String) -> String {
        let t = normalize(text)

        if containsAny(t, ["nasılsın", "nasilsin", "naber", "ne haber"]) {
            if let root = selectedRootURL {
                return "İyiyim, hazırım. Şu an “\(root.lastPathComponent)” çalışma alanını hatırlıyorum ve \(indexedFiles.count) dosyayı yerel olarak görebiliyorum."
            }

            return "İyiyim, hazırım. Şu an aktif bir çalışma klasörü seçili değil; istersen bir alan seçip birlikte inceleyebiliriz."
        }

        if containsAny(t, ["ne yapıyorsun", "ne yapiyorsun"]) {
            if let root = selectedRootURL {
                return "Şu an “\(root.lastPathComponent)” çalışma alanını takip ediyorum. \(indexedFiles.count) dosya indeksli; yeni bir hedef verdiğinde önce ne istediğini analiz edip uygun modülü kendim seçeceğim."
            }

            return "Şu an yeni bir hedef bekliyorum. Bir görev verdiğinde önce niyeti ve bağlamı analiz edip hangi modülün gerektiğine kendim karar vereceğim."
        }

        return "Selam. Hazırım; sadece komut beklemek yerine hedefini anlamaya, seçenekleri düşünmeye ve uygun yolu seçmeye çalışacağım."
    }

    private func assessWorkspace() -> String {
        guard let root = selectedRootURL else {
            return "Önce bir çalışma klasörü seçmeliyim. Sonra hiçbir dosyayı değiştirmeden yapıyı inceleyip birkaç alternatif önerebilirim."
        }

        indexSelectedFolder()

        var observations: [String] = [
            "\(indexedFiles.count) dosya",
            "\(imageCount) görsel",
            "\(videoCount) video",
            "\(documentCount) belge",
            "\(projectCount) proje dosyası"
        ]

        if screenshotCount > 0 {
            observations.append("\(screenshotCount) ekran görüntüsü")
        }

        var ideas: [String] = []

        if screenshotCount >= 5 {
            ideas.append("Ekran görüntülerini ayrı klasöre toplamak düşük riskli ve geri alınabilir bir ilk adım.")
        }

        if videoCount > 0 {
            ideas.append("Videoları en yeni veya belirli bir tarihe göre ayırıp yalnızca ilgili çekimleri öne çıkarabilirim.")
        }

        if documentCount > 0 {
            ideas.append("Belgeleri tür veya tarihe göre gruplandırmadan önce sadece listeleyip dağınıklığın kaynağını gösterebilirim.")
        }

        if ideas.isEmpty {
            ideas.append("Şimdilik değişiklik yapmak yerine son eklenen dosyaları inceleyip en yararlı düzenleme adımını seçebiliriz.")
        }

        return "“\(root.lastPathComponent)” alanını inceledim: " +
            observations.joined(separator: ", ") +
            ".\n\nDüşündüğüm seçenekler:\n• " +
            ideas.joined(separator: "\n• ") +
            "\n\nDosyalarda değişiklik yapmadım."
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
        UserDefaults.standard.set(url.path, forKey: selectedRootKey)
        pendingFileAction = nil
        lastUndoAction = nil
        indexSelectedFolder()

        log("Çalışma klasörü seçildi: \(url.lastPathComponent)")
    }

    func indexSelectedFolder() {
        guard let root = selectedRootURL else { return }

        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .isDirectoryKey,
            .creationDateKey,
            .contentModificationDateKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            indexedFiles = []
            log("Klasör indekslenemedi")
            return
        }

        var records: [FileRecord] = []
        var folders: [FolderRecord] = []
        let maxItems = 5000

        for case let url as URL in enumerator {
            if records.count + folders.count >= maxItems {
                log("İndeks güvenlik sınırına ulaştı: \(maxItems) öğe")
                break
            }

            do {
                let values = try url.resourceValues(forKeys: Set(keys))
                let name = url.lastPathComponent
                let relativePath = url.path.replacingOccurrences(
                    of: root.path + "/",
                    with: ""
                )

                if values.isDirectory == true {
                    folders.append(
                        FolderRecord(
                            url: url,
                            name: name,
                            relativePath: relativePath,
                            creationDate: values.creationDate,
                            modificationDate: values.contentModificationDate
                        )
                    )
                    continue
                }

                guard values.isRegularFile == true else { continue }

                let ext = url.pathExtension.lowercased()

                records.append(
                    FileRecord(
                        url: url,
                        name: name,
                        relativePath: relativePath,
                        fileExtension: ext,
                        isScreenshot: isScreenshotFileName(name, extension: ext),
                        creationDate: values.creationDate,
                        modificationDate: values.contentModificationDate
                    )
                )
            } catch {
                continue
            }
        }

        indexedFiles = records.sorted {
            $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
        }

        indexedFolders = folders.sorted {
            $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
        }

        let screenshotCount = indexedFiles.filter(\.isScreenshot).count
        log("\(indexedFiles.count) dosya ve \(indexedFolders.count) klasör indekslendi")
        log("\(screenshotCount) ekran görüntüsü adayı bulundu")
    }

    var screenshotCount: Int {
        indexedFiles.filter(\.isScreenshot).count
    }

    var imageCount: Int {
        let extensions = Set(["png", "jpg", "jpeg", "heic", "tif", "tiff", "webp", "gif"])
        return indexedFiles.filter { extensions.contains($0.fileExtension) }.count
    }

    var videoCount: Int {
        let extensions = Set(["mov", "mp4", "m4v", "avi", "mkv", "webm", "mts", "m2ts"])
        return indexedFiles.filter { extensions.contains($0.fileExtension) }.count
    }

    var projectCount: Int {
        let extensions = Set(["prproj", "aep", "psd", "ai", "indd", "fcpxml"])
        return indexedFiles.filter { extensions.contains($0.fileExtension) }.count
    }

    var documentCount: Int {
        let extensions = Set(["pdf", "doc", "docx", "txt", "rtf", "md", "pages", "numbers", "key"])
        return indexedFiles.filter { extensions.contains($0.fileExtension) }.count
    }

    private func restoreSelectedFolder() {
        guard let path = UserDefaults.standard.string(forKey: selectedRootKey),
              !path.isEmpty else {
            return
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            UserDefaults.standard.removeObject(forKey: selectedRootKey)
            return
        }

        selectedRootURL = URL(fileURLWithPath: path, isDirectory: true)
        indexSelectedFolder()
        log("Çalışma klasörü geri yüklendi: \(selectedRootURL?.lastPathComponent ?? path)")
    }

    // MARK: - Local File Search

    func revealFile(_ file: FileRecord) {
        guard fileManager.fileExists(atPath: file.url.path) else {
            log("Finder'da gösterilemedi: dosya artık mevcut değil")
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([file.url])
        log("Finder'da gösterildi: \(file.name)")
    }

    private func isFileSearchIntent(_ text: String) -> Bool {
        let actionWords = [
            "bul", "ara", "göster", "listele",
            "nerede", "hangileri", "hangi dosya"
        ]

        let fileWords = [
            "dosya", "pdf", "video", "görsel", "gorsel",
            "resim", "fotoğraf", "fotograf", "proje",
            "belge", "doküman", "dokuman", "logo",
            "ekran görünt", "ekran gorunt", "ekran resmi"
        ]

        return containsAny(text, actionWords) && containsAny(text, fileWords)
    }

    func revealFolder(_ folder: FolderRecord) {
        guard fileManager.fileExists(atPath: folder.url.path) else {
            log("Finder'da gösterilemedi: klasör artık mevcut değil")
            return
        }

        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.url.path)
        log("Finder'da klasör açıldı: \(folder.name)")
    }

    private func openPreviousResult(
        selection: AgentResultSelection?
    ) -> String {
        if !fileSearchResults.isEmpty {
            let file: FileRecord
            switch selection ?? .first {
            case .first:
                file = fileSearchResults[0]
            case .last:
                file = fileSearchResults[fileSearchResults.count - 1]
            }

            revealFile(file)
            return "Önceki sonuçlardan “\(file.name)” dosyasını Finder'da gösterdim."
        }

        if !folderSearchResults.isEmpty {
            let folder: FolderRecord
            switch selection ?? .first {
            case .first:
                folder = folderSearchResults[0]
            case .last:
                folder = folderSearchResults[folderSearchResults.count - 1]
            }

            revealFolder(folder)
            return "Önceki sonuçlardan “\(folder.name)” klasörünü Finder'da açtım."
        }

        return "Referans verebileceğim önceki bir arama sonucu kalmamış. Önce dosya veya klasör araması yapalım."
    }

    private func suggestFromPreviousResults() -> String {
        if !fileSearchResults.isEmpty {
            let candidate = fileSearchResults.max { left, right in
                let leftDate = left.modificationDate ?? left.creationDate ?? .distantPast
                let rightDate = right.modificationDate ?? right.creationDate ?? .distantPast
                return leftDate < rightDate
            } ?? fileSearchResults[0]

            log("Bağlamdan çalışma adayı seçildi: \(candidate.name)")
            return "Önceki sonuçlar içinde başlangıç adayı olarak “\(candidate.name)” dosyasını öne çıkarıyorum. Mevcut metadata içinde en güncel görünen aday bu. İstersen “onu aç” veya “sonuçları daralt” diyebilirsin."
        }

        if !folderSearchResults.isEmpty {
            let candidate = folderSearchResults.max { left, right in
                let leftDate = left.modificationDate ?? left.creationDate ?? .distantPast
                let rightDate = right.modificationDate ?? right.creationDate ?? .distantPast
                return leftDate < rightDate
            } ?? folderSearchResults[0]

            log("Bağlamdan klasör adayı seçildi: \(candidate.name)")
            return "Önceki klasör sonuçları içinde “\(candidate.name)” en güncel aday olarak öne çıkıyor. İstersen “onu aç” diyebilirsin."
        }

        return "Önceki sonuç kalmadığı için seçim yapamıyorum. Önce ilgili dosya veya klasörleri bulalım."
    }

    private func searchIndexedFolders(
        for rawText: String,
        decision: AgentDecision
    ) -> String {
        activeRoute = decision.route

        guard let root = selectedRootURL else {
            folderSearchResults = []
            fileSearchResults = []
            fileSearchTitle = ""
            return "Önce bir çalışma klasörü seç. Klasör aramasını seçili alanın içinde yapacağım."
        }

        indexSelectedFolder()

        var results = indexedFolders

        if let range = decision.dateRange {
            results = results.filter { folder in
                switch decision.dateField {
                case .created:
                    guard let date = folder.creationDate else { return false }
                    return range.contains(date)
                case .modified:
                    guard let date = folder.modificationDate else { return false }
                    return range.contains(date)
                case .either:
                    let createdMatch = folder.creationDate.map(range.contains) ?? false
                    let modifiedMatch = folder.modificationDate.map(range.contains) ?? false
                    return createdMatch || modifiedMatch
                }
            }
        }

        if decision.sortMode == .newestFirst {
            results.sort {
                let left = $0.creationDate ?? $0.modificationDate ?? .distantPast
                let right = $1.creationDate ?? $1.modificationDate ?? .distantPast
                return left > right
            }
        }

        folderSearchResults = results
        fileSearchResults = []
        fileSearchTitle = decision.goal

        log("Yerel klasör araması: \(decision.goal)")
        log("\(results.count) klasör eşleşmesi bulundu")

        guard !results.isEmpty else {
            return "“\(root.lastPathComponent)” içinde \(decision.goal) için eşleşme bulamadım."
        }

        let preview = results.prefix(5).map(\.name).joined(separator: ", ")
        let extra = results.count > 5 ? " ve \(results.count - 5) klasör daha" : ""

        return "\(results.count) klasör buldum: \(preview)\(extra). Sağdaki sonuçlardan klasörü Finder'da açabilirsin."
    }

    private func searchIndexedFiles(
        for rawText: String,
        decision: AgentDecision
    ) -> String {
        activeRoute = decision.route

        guard let root = selectedRootURL else {
            fileSearchResults = []
            fileSearchTitle = ""
            return "Önce bir çalışma klasörü seç. Aramayı seçtiğin klasör ve alt klasörlerinde yapacağım."
        }

        indexSelectedFolder()

        let text = normalize(rawText)
        let imageExtensions = Set(["png", "jpg", "jpeg", "heic", "tif", "tiff", "webp", "gif"])
        let videoExtensions = Set(["mov", "mp4", "m4v", "avi", "mkv", "webm", "mts", "m2ts"])
        let projectExtensions = Set(["prproj", "aep", "psd", "ai", "indd", "fcpxml"])
        let documentExtensions = Set(["pdf", "doc", "docx", "txt", "rtf", "md", "pages", "numbers", "key"])

        var title = decision.goal
        var results: [FileRecord]
        let sourceFiles = decision.usePreviousResults
            ? fileSearchResults
            : indexedFiles

        switch decision.target {
        case .screenshot:
            results = sourceFiles.filter(\.isScreenshot)
        case .pdf:
            results = sourceFiles.filter { $0.fileExtension == "pdf" }
        case .video:
            results = sourceFiles.filter { videoExtensions.contains($0.fileExtension) }
        case .image:
            results = sourceFiles.filter { imageExtensions.contains($0.fileExtension) }
        case .project:
            results = sourceFiles.filter { projectExtensions.contains($0.fileExtension) }
        case .document:
            results = sourceFiles.filter { documentExtensions.contains($0.fileExtension) }
        case .folder:
            results = []
        case .any:
            let query = fileNameQuery(from: text)
            title = query.isEmpty ? decision.goal : "“\(query)” araması"

            if query.isEmpty {
                results = sourceFiles
            } else {
                let tokens = query.split(separator: " ").map(String.init)
                results = sourceFiles.filter { file in
                    let name = normalize(file.name)
                    let path = normalize(file.relativePath)
                    return tokens.allSatisfy { name.contains($0) || path.contains($0) }
                }
            }
        }

        if let range = decision.dateRange {
            results = results.filter { file in
                switch decision.dateField {
                case .created:
                    guard let date = file.creationDate else { return false }
                    return range.contains(date)
                case .modified:
                    guard let date = file.modificationDate else { return false }
                    return range.contains(date)
                case .either:
                    let createdMatch = file.creationDate.map(range.contains) ?? false
                    let modifiedMatch = file.modificationDate.map(range.contains) ?? false
                    return createdMatch || modifiedMatch
                }
            }
        }

        if decision.sortMode == .newestFirst {
            results.sort {
                let left = $0.creationDate ?? $0.modificationDate ?? .distantPast
                let right = $1.creationDate ?? $1.modificationDate ?? .distantPast
                return left > right
            }
        }

        fileSearchResults = results
        folderSearchResults = []
        fileSearchTitle = title

        log("Yerel dosya araması: \(title)")
        if decision.usePreviousResults {
            log("Bağlam filtresi önceki sonuç kümesine uygulandı")
        }
        log("\(results.count) eşleşme bulundu")

        let askedForWholeComputer = containsAny(
            text,
            ["bilgisayarımda", "bilgisayarimda", "mac'imde", "macimde", "tüm bilgisayar", "tum bilgisayar"]
        )

        let computerScopeNote = askedForWholeComputer
            ? "Not: Bu sürüm henüz tüm Mac’i değil, seçili “\(root.lastPathComponent)” klasörü ve alt klasörlerini tarıyor. "
            : ""

        let contextScopeNote = decision.usePreviousResults
            ? "Önceki sonuçların içinde filtreledim. "
            : ""

        let scopeNote = computerScopeNote + contextScopeNote

        guard !results.isEmpty else {
            return scopeNote + "\(title) için eşleşme bulamadım."
        }

        let preview = results.prefix(5).map(\.name).joined(separator: ", ")
        let extra = results.count > 5 ? " ve \(results.count - 5) dosya daha" : ""

        return scopeNote + "\(results.count) eşleşme buldum: \(preview)\(extra). Sağdaki sonuçlardan istediğini Finder'da gösterebilirsin."
    }

    private func turkishDayMonth(from text: String) -> (day: Int, month: Int, monthName: String)? {
        let months: [(name: String, number: Int)] = [
            ("ocak", 1), ("şubat", 2), ("subat", 2), ("mart", 3),
            ("nisan", 4), ("mayıs", 5), ("mayis", 5), ("haziran", 6),
            ("temmuz", 7), ("ağustos", 8), ("agustos", 8),
            ("eylül", 9), ("eylul", 9), ("ekim", 10),
            ("kasım", 11), ("kasim", 11), ("aralık", 12), ("aralik", 12)
        ]

        for month in months where text.contains(month.name) {
            let tokens = text
                .replacingOccurrences(of: month.name, with: " \(month.name) ")
                .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
                .map(String.init)

            guard let monthIndex = tokens.firstIndex(of: month.name) else { continue }

            let candidateIndexes = [monthIndex - 1, monthIndex + 1]
            for index in candidateIndexes where tokens.indices.contains(index) {
                if let day = Int(tokens[index]), (1...31).contains(day) {
                    return (day, month.number, month.name)
                }
            }
        }

        return nil
    }

    private func matches(day: Int, month: Int, date: Date?) -> Bool {
        guard let date else { return false }
        let components = Calendar.current.dateComponents([.day, .month], from: date)
        return components.day == day && components.month == month
    }

    private func fileNameQuery(from text: String) -> String {
        var cleaned = text

        let stopPhrases = [
            "bana", "şu", "bu", "bir", "vardı", "vardi", "onu",
            "dosyayı", "dosyalari", "dosyaları", "dosya",
            "bul", "ara", "göster", "goster", "listele", "nerede",
            "klasördeki", "klasordeki", "klasörde", "klasorde",
            "seçili", "secili", "çalışma", "calisma",
            "içindeki", "icindeki", "olan", "tarihli",
            "bilgisayarımda", "bilgisayarimda",
            "var mı", "varmi", "lütfen", "lutfen"
        ]

        for phrase in stopPhrases {
            cleaned = cleaned.replacingOccurrences(of: phrase, with: " ")
        }

        return cleaned
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Real File Actions

    private func prepareScreenshotOrganizeAction() -> String {
        activeRoute = ["Core", "File Memory", "File Actions"]

        guard let root = selectedRootURL else {
            log("Dosya işlemi için klasör seçimi bekleniyor")
            return "Önce sağdaki “Klasör seç ve indeksle” ile Masaüstü klasörünü seç. Bu sürüm dosyaları yalnızca senin seçtiğin klasör içinde değiştirecek."
        }

        indexSelectedFolder()

        let screenshots = indexedFiles.filter {
            $0.isScreenshot &&
            $0.url.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL
        }

        guard !screenshots.isEmpty else {
            log("Ekran görüntüsü bulunamadı")
            return "\(root.lastPathComponent) içinde doğrudan duran ekran görüntüsü bulamadım."
        }

        let destination = root.appendingPathComponent("Ekran Görüntüleri", isDirectory: true)

        let preview = screenshots
            .prefix(5)
            .map { "• \($0.name)" }
            .joined(separator: "\n")

        let extraCount = max(0, screenshots.count - 5)
        let extraLine = extraCount > 0 ? "\n… ve \(extraCount) dosya daha" : ""

        pendingFileAction = PendingFileAction(
            title: "Ekran görüntülerini toparla",
            detail: "\(screenshots.count) ekran görüntüsü “Ekran Görüntüleri” klasörüne taşınacak.\n\n\(preview)\(extraLine)",
            sourceURLs: screenshots.map(\.url),
            destinationFolderURL: destination
        )

        log("\(screenshots.count) ekran görüntüsü bulundu")
        log("Gerçek dosya taşıma işlemi onay bekliyor")

        let sampleNames = screenshots
            .prefix(3)
            .map(\.name)
            .joined(separator: ", ")

        return "\(screenshots.count) ekran görüntüsü buldum. İlk adaylar: \(sampleNames). “Ekran Görüntüleri” klasörüne taşımak için onayını bekliyorum."
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

        if containsAny(t, ["dosya", "klasör", "çekim", "bul", "ara", "göster", "listele", "logo", "arşiv", "masaüst", "masaustu", "ekran görünt", "ekran gorunt", "ekran resmi", "toparla", "taşı", "tasi"]) {
            modules.append("File Memory")
        }

        if isFileSearchIntent(t) {
            modules.append("File Search")
        }

        if isScreenshotOrganizeIntent(t) || pendingFileAction != nil {
            modules.append("File Actions")
        }

        if !isFileSearchIntent(t) && containsAny(t, ["reels", "video", "kurgu", "premiere", "altyaz", "export", "sequence"]) {
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
