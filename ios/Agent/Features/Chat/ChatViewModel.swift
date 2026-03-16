import Foundation
import UIKit

/// Chat view model — manages messages, WebSocket connection, voice, and streaming
@Observable
final class ChatViewModel {
    // MARK: - Published State
    var messages: [Message] = []
    var inputText = ""
    var liveTranscript = ""
    var isRecording = false
    var isProcessing = false
    var isAgentSpeaking = false
    var isStreaming = false
    var isLoadingHistory = false
    var activeHarness: Harness = .defaultHarness
    var errorMessage: String?
    var showError = false
    
    // Streamed text buffer for the current assistant response
    var streamingText = ""
    
    // MARK: - Private
    private var voicePipeline: VoicePipeline?
    private var webSocketTask: URLSessionWebSocketTask?
    private var sessionID: String
    private let urlSession = URLSession(configuration: .default)
    
    init() {
        sessionID = UUID().uuidString
        setupVoicePipeline()
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - Connection
    
    func connect() {
        guard webSocketTask == nil else { return }
        
        guard let provider = getActiveProvider(),
              let apiKey = getActiveAPIKey() else {
            showErrorMessage("No API key configured. Go to Settings to add one.")
            return
        }
        
        let baseURL = APIConfig.wsBaseURL
        let token = AuthManager.shared.currentToken ?? ""
        
        guard let url = URL(string: "\(baseURL)/api/v1/chat/\(sessionID)?token=\(token)&harness_id=\(activeHarness.id)") else {
            showErrorMessage("Invalid server URL")
            return
        }
        
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        listenForMessages()
        
        // Load history
        loadHistory()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
    
    // MARK: - Voice
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        // Interrupt agent if speaking
        if isAgentSpeaking {
            voicePipeline?.stopSpeaking()
            isAgentSpeaking = false
        }
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        isRecording = true
        liveTranscript = ""
        
        voicePipeline?.startListening { [weak self] transcript in
            Task { @MainActor in
                self?.liveTranscript = transcript
            }
        }
    }
    
    func stopRecording() {
        isRecording = false
        voicePipeline?.stopListening()
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        let transcript = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        liveTranscript = ""
        
        guard !transcript.isEmpty else { return }
        sendMessage(transcript)
    }
    
    // MARK: - Text
    
    func sendTextMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        sendMessage(text)
    }
    
    // MARK: - Harness
    
    func switchHarness(_ harness: Harness) {
        activeHarness = harness
        
        // Tell backend to switch
        let payload: [String: Any] = [
            "type": "switch_harness",
            "harness_id": harness.id
        ]
        sendJSON(payload)
    }
    
    // MARK: - Private — Messaging
    
    private func sendMessage(_ text: String) {
        let userMessage = Message.userMessage(text)
        messages.append(userMessage)
        
        // Haptic
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        
        // Clear any error
        errorMessage = nil
        showError = false
        isProcessing = true
        
        guard let provider = getActiveProvider(),
              let apiKey = getActiveAPIKey() else {
            showErrorMessage("No API key configured. Go to Settings to add one.")
            isProcessing = false
            return
        }
        
        // Ensure connected
        if webSocketTask == nil {
            connect()
        }
        
        let payload: [String: Any] = [
            "type": "message",
            "content": text,
            "api_key": apiKey,
            "provider": provider.backendIdentifier
        ]
        sendJSON(payload)
    }
    
    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else { return }
        
        webSocketTask?.send(.string(string)) { [weak self] error in
            if let error {
                Task { @MainActor in
                    self?.showErrorMessage("Send failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadHistory() {
        isLoadingHistory = true
        sendJSON(["type": "load_history"])
    }
    
    // MARK: - Private — Receiving
    
    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    Task { @MainActor in
                        self.handleServerEvent(text)
                    }
                default:
                    break
                }
                // Keep listening
                self.listenForMessages()
                
            case .failure(let error):
                Task { @MainActor in
                    self.showErrorMessage("Connection lost: \(error.localizedDescription)")
                    self.webSocketTask = nil
                }
            }
        }
    }
    
    private func handleServerEvent(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = event["type"] as? String else { return }
        
        switch type {
        case "agent_start":
            isProcessing = true
            isStreaming = false
            streamingText = ""
            
        case "message_start":
            isStreaming = true
            streamingText = ""
            // Add streaming placeholder message
            let streamMsg = Message.assistantMessage("", streaming: true)
            messages.append(streamMsg)
            
        case "text_chunk":
            if let text = event["content"] as? String {
                streamingText += text
                // Update the last message in place
                if let lastIndex = messages.indices.last, messages[lastIndex].role == .assistant {
                    messages[lastIndex] = Message.assistantMessage(streamingText, streaming: true)
                }
            }
            
        case "message_end":
            isStreaming = false
            // Finalize the last message
            if let lastIndex = messages.indices.last, messages[lastIndex].role == .assistant {
                messages[lastIndex] = Message.assistantMessage(streamingText, streaming: false)
            }
            // Speak the response
            speakResponse(streamingText)
            streamingText = ""
            
        case "tool_start":
            // Show tool usage indicator
            if let toolName = event["tool_name"] as? String {
                let toolMsg = Message.assistantMessage("🔧 Using \(toolName)...", streaming: true)
                messages.append(toolMsg)
            }
            
        case "tool_end":
            // Remove tool indicator — the next message_start will replace it
            if let lastIndex = messages.indices.last,
               messages[lastIndex].content.hasPrefix("🔧") {
                messages.remove(at: lastIndex)
            }
            
        case "agent_end":
            isProcessing = false
            isStreaming = false
            // Success haptic
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
        case "error":
            isProcessing = false
            isStreaming = false
            if let message = event["message"] as? String {
                showErrorMessage(message)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            
        case "history":
            isLoadingHistory = false
            if let msgArray = event["messages"] as? [[String: Any]] {
                messages = msgArray.compactMap { dict -> Message? in
                    guard let role = dict["role"] as? String,
                          let content = dict["content"] as? String else { return nil }
                    if role == "user" {
                        return Message.userMessage(content)
                    } else if role == "assistant" {
                        return Message.assistantMessage(content, streaming: false)
                    }
                    return nil
                }
            }
            
        case "harness_switched":
            if let name = event["harness_name"] as? String {
                messages = []
                sessionID = UUID().uuidString
                // Reconnect with new session
                disconnect()
                showErrorMessage("Switched to \(name)")
            }
            
        default:
            break
        }
    }
    
    // MARK: - Private — Speech
    
    private func speakResponse(_ text: String) {
        guard !text.isEmpty else { return }
        isAgentSpeaking = true
        
        voicePipeline?.speak(text: text) { [weak self] in
            Task { @MainActor in
                self?.isAgentSpeaking = false
            }
        }
    }
    
    private func setupVoicePipeline() {
        voicePipeline = VoicePipeline()
    }
    
    // MARK: - Private — Helpers
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
        
        // Auto-dismiss after 5 seconds
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            if errorMessage == message {
                showError = false
            }
        }
    }
    
    private func getActiveProvider() -> LLMProvider? {
        for provider in LLMProvider.allCases {
            if KeychainManager.shared.getAPIKey(for: provider) != nil {
                return provider
            }
        }
        return nil
    }
    
    private func getActiveAPIKey() -> String? {
        guard let provider = getActiveProvider() else { return nil }
        return KeychainManager.shared.getAPIKey(for: provider)
    }
}
