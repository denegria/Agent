import Foundation
import Speech
import AVFoundation

/// Coordinates STT (Apple Speech) and TTS (ElevenLabs + Apple fallback)
final class VoicePipeline: NSObject, @unchecked Sendable {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    
    private var onTranscript: ((String) -> Void)?
    private var onSpeakingDone: (() -> Void)?
    
    override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        synthesizer.delegate = self
    }
    
    // MARK: - STT (Apple Speech)
    
    func startListening(onTranscript: @escaping (String) -> Void) {
        self.onTranscript = onTranscript
        
        // Request authorization
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else { return }
            
            Task { @MainActor in
                self?.beginRecognition()
            }
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
    }
    
    private func beginRecognition() {
        guard let speechRecognizer, speechRecognizer.isAvailable else { return }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else { return }
            
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = true // Privacy-first
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                if let result {
                    let transcript = result.bestTranscription.formattedString
                    self?.onTranscript?(transcript)
                }
                
                if error != nil || (result?.isFinal ?? false) {
                    self?.stopListening()
                }
            }
            
            let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
            audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("VoicePipeline: Failed to start recognition - \(error)")
        }
    }
    
    // MARK: - TTS
    
    func speak(text: String, onDone: @escaping () -> Void) {
        self.onSpeakingDone = onDone
        
        // Try ElevenLabs first if API key is available
        if let elevenLabsKey = KeychainManager.shared.getAPIKey(for: .openai) {
            // TODO: ElevenLabs streaming TTS (requires separate API key storage)
            // For now, fall through to Apple TTS
        }
        
        // Apple TTS fallback (always available, free, on-device)
        speakWithAppleTTS(text: text)
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        onSpeakingDone?()
    }
    
    private func speakWithAppleTTS(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.1
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("VoicePipeline: Audio session error - \(error)")
        }
        
        synthesizer.speak(utterance)
    }
    
    // MARK: - Permissions
    
    func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        let micStatus = await AVAudioApplication.requestRecordPermission()
        
        return speechStatus && micStatus
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoicePipeline: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onSpeakingDone?()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onSpeakingDone?()
    }
}
