import Foundation
import Speech
import AVFoundation
import AppKit

@MainActor
final class SpeechController: NSObject, ObservableObject, AVAudioRecorderDelegate {
    enum State: Equatable {
        case idle
        case requestingPermission
        case recording
        case transcribing
        case denied
        case failed(String)
    }

    @Published var state: State = .idle
    @Published var transcript = ""
    @Published var elapsedSeconds = 0
    @Published var statusText = "Hazır"

    var isRecording: Bool { state == .recording }

    var isBusy: Bool {
        switch state {
        case .requestingPermission, .transcribing: return true
        default: return false
        }
    }

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "tr-TR"))
    private var recorder: AVAudioRecorder?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var timer: Timer?
    private var recordingURL: URL?
    private var onFinal: ((String) -> Void)?
    private let synthesizer = AVSpeechSynthesizer()

    func microphoneTapped(onFinal: @escaping (String) -> Void) {
        switch state {
        case .idle, .failed:
            self.onFinal = onFinal
            Task {
                statusText = "İzinler kontrol ediliyor…"
                state = .requestingPermission

                let allowed = await requestPermissionsIfNeeded()
                guard allowed else {
                    statusText = "Mikrofon veya konuşma tanıma izni kapalı."
                    state = .denied
                    return
                }

                startRecording()
            }

        case .recording:
            stopRecordingAndTranscribe()

        case .requestingPermission, .transcribing:
            break

        case .denied:
            openPrivacySettings()
        }
    }

    func cancelRecording() {
        guard state == .recording else { return }

        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        elapsedSeconds = 0
        transcript = ""

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }

        recordingURL = nil
        statusText = "Kayıt iptal edildi."
        state = .idle
    }

    private func requestPermissionsIfNeeded() async -> Bool {
        let speechAllowed = await requestSpeechPermissionIfNeeded()
        guard speechAllowed else { return false }
        return await requestMicrophonePermissionIfNeeded()
    }

    private func requestSpeechPermissionIfNeeded() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        @unknown default:
            return false
        }
    }

    private func requestMicrophonePermissionIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    private func startRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        transcript = ""
        elapsedSeconds = 0

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("krali-voice-\(UUID().uuidString).m4a")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.delegate = self
            newRecorder.isMeteringEnabled = true

            guard newRecorder.prepareToRecord(), newRecorder.record() else {
                let message = "Mikrofon kaydı başlatılamadı."
                statusText = message
                state = .failed(message)
                return
            }

            recorder = newRecorder
            statusText = "Dinliyorum…"
            state = .recording

            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.state == .recording else { return }
                    self.elapsedSeconds += 1

                    if self.elapsedSeconds >= 180 {
                        self.stopRecordingAndTranscribe()
                    }
                }
            }
        } catch {
            let message = "Mikrofon kaydı başlatılamadı: \(error.localizedDescription)"
            statusText = message
            state = .failed(message)
        }
    }

    private func stopRecordingAndTranscribe() {
        guard state == .recording else { return }

        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil

        guard let url = recordingURL else {
            let message = "Ses kaydı bulunamadı."
            statusText = message
            state = .failed(message)
            return
        }

        statusText = "Ses yazıya çevriliyor…"
        state = .transcribing
        transcribe(url: url)
    }

    private func transcribe(url: URL) {
        guard let recognizer, recognizer.isAvailable else {
            finishWithError("Türkçe konuşma tanıma şu anda kullanılamıyor.", url: url)
            return
        }

        recognitionTask?.cancel()

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation

        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }

        // Do not force Apple's local speech service. This avoids the 1101 issue
        // seen in earlier builds on this Mac.
        if #available(macOS 10.15, *) {
            request.requiresOnDeviceRecognition = false
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            Task { @MainActor in
                if let result, result.isFinal {
                    let text = result.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    self.recognitionTask = nil
                    self.cleanupAudioFile(url)

                    if text.isEmpty {
                        let message = "Ses algılandı ancak anlaşılır bir metin çıkarılamadı."
                        self.statusText = message
                        self.state = .failed(message)
                        return
                    }

                    self.transcript = text
                    self.statusText = "Komut alındı."
                    self.state = .idle
                    self.elapsedSeconds = 0

                    let callback = self.onFinal
                    self.onFinal = nil
                    callback?(text)
                    return
                }

                if let error {
                    self.recognitionTask = nil
                    let nsError = error as NSError
                    self.finishWithError(
                        "Ses yazıya çevrilemedi (\(nsError.domain) / \(nsError.code)): \(nsError.localizedDescription)",
                        url: url
                    )
                }
            }
        }
    }

    private func finishWithError(_ message: String, url: URL) {
        cleanupAudioFile(url)
        elapsedSeconds = 0
        statusText = message
        state = .failed(message)
    }

    private func cleanupAudioFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        if recordingURL == url {
            recordingURL = nil
        }
    }

    func dismissError() {
        if case .failed = state {
            statusText = "Hazır"
            state = .idle
        }
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "tr-TR")
        utterance.rate = 0.48
        synthesizer.speak(utterance)
    }
}
