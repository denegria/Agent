import SwiftUI

/// Main chat screen with voice and text input
struct ChatView: View {
    @Environment(AppRouter.self) private var router
    @State private var viewModel = ChatViewModel()
    @State private var showHarnessPicker = false
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Theme.spacingMD) {
                            // Active harness header
                            harnessHeader
                                .padding(.top, Theme.spacingSM)
                            
                            // Loading history indicator
                            if viewModel.isLoadingHistory {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .tint(Theme.textMuted)
                                        .scaleEffect(0.8)
                                    Text("Loading conversation…")
                                        .font(Theme.caption)
                                        .foregroundStyle(Theme.textMuted)
                                }
                                .padding(.vertical, Theme.spacingMD)
                            }
                            
                            // Messages
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                            
                            // Typing indicator (processing but not yet streaming)
                            if viewModel.isProcessing && !viewModel.isStreaming {
                                TypingIndicator()
                                    .id("typing-indicator")
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            }
                            
                            // Live transcript (when recording)
                            if !viewModel.liveTranscript.isEmpty {
                                liveTranscriptBubble
                                    .id("live-transcript")
                            }
                        }
                        .padding(.horizontal, Theme.spacingMD)
                        .padding(.bottom, Theme.spacingLG)
                        .animation(.spring(response: 0.3), value: viewModel.messages.count)
                    }
                    .onChange(of: viewModel.messages.count) {
                        withAnimation(.spring(response: 0.3)) {
                            if viewModel.isProcessing {
                                proxy.scrollTo("typing-indicator", anchor: .bottom)
                            } else {
                                proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.isProcessing) { _, processing in
                        if processing {
                            withAnimation {
                                proxy.scrollTo("typing-indicator", anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.streamingText) {
                        // Auto-scroll as streaming text arrives
                        if let lastMsg = viewModel.messages.last {
                            withAnimation(.easeOut(duration: 0.1)) {
                                proxy.scrollTo(lastMsg.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Input area
                inputArea
            }
            
            // Error banner overlay
            if viewModel.showError, let errorMsg = viewModel.errorMessage {
                VStack {
                    errorBanner(errorMsg)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4), value: viewModel.showError)
                .zIndex(100)
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    showHarnessPicker = true
                } label: {
                    HStack(spacing: 6) {
                        HarnessAvatar(viewModel.activeHarness, size: 28)
                        Text(viewModel.activeHarness.name)
                            .font(Theme.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }
        }
        .sheet(isPresented: $showHarnessPicker) {
            HarnessPickerSheet(
                selected: $viewModel.activeHarness,
                onSelect: { harness in
                    viewModel.switchHarness(harness)
                    showHarnessPicker = false
                }
            )
            .presentationDetents([.medium])
        }
        .onAppear {
            viewModel.connect()
        }
        .onDisappear {
            viewModel.disconnect()
        }
    }
    
    // MARK: - Error Banner
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.warning)
                .font(.system(size: 16))
            
            Text(message)
                .font(Theme.footnote)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
            
            Spacer()
            
            Button {
                withAnimation {
                    viewModel.showError = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .padding(Theme.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        )
        .padding(.horizontal, Theme.spacingMD)
        .padding(.top, 8)
    }
    
    // MARK: - Harness Header
    
    private var harnessHeader: some View {
        VStack(spacing: Theme.spacingSM) {
            HarnessAvatar(viewModel.activeHarness, size: 64)
            
            Text(viewModel.activeHarness.name)
                .font(Theme.title2)
                .foregroundStyle(Theme.textPrimary)
            
            Text(viewModel.activeHarness.description)
                .font(Theme.footnote)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, Theme.spacingXL)
            
            // Connection status pill
            HStack(spacing: 4) {
                Circle()
                    .fill(Theme.success)
                    .frame(width: 6, height: 6)
                Text("Ready")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Theme.success.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(.vertical, Theme.spacingLG)
    }
    
    // MARK: - Live Transcript
    
    private var liveTranscriptBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Theme.error)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .fill(Theme.error)
                                .frame(width: 8, height: 8)
                                .scaleEffect(1.5)
                                .opacity(0.3)
                        )
                    Text("Listening…")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.error)
                }
                
                Text(viewModel.liveTranscript)
                    .font(Theme.body)
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(Theme.spacingMD)
            .background(Theme.error.opacity(0.1))
            .cornerRadius(Theme.radiusLG)
            
            Spacer()
        }
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        VStack(spacing: Theme.spacingSM) {
            // Waveform (visible when recording or agent is speaking)
            if viewModel.isRecording || viewModel.isAgentSpeaking {
                WaveformView(
                    isAnimating: viewModel.isRecording || viewModel.isAgentSpeaking,
                    color: viewModel.isRecording ? Theme.error : Theme.accent
                )
                .frame(height: 44)
                .padding(.horizontal, Theme.spacingLG)
                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .bottom)))
            }
            
            HStack(spacing: Theme.spacingMD) {
                // Text input
                HStack {
                    TextField("Type a message…", text: $viewModel.inputText, axis: .vertical)
                        .font(Theme.body)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1...4)
                        .padding(.horizontal, Theme.spacingMD)
                        .padding(.vertical, Theme.spacingSM)
                        .onSubmit { viewModel.sendTextMessage() }
                    
                    // Send button (when text is present)
                    if !viewModel.inputText.isEmpty {
                        Button {
                            viewModel.sendTextMessage()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Theme.accent)
                        }
                        .padding(.trailing, 4)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .background(Theme.surface)
                .cornerRadius(Theme.radiusXL)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusXL)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                
                // Mic button
                PulsingMicButton(
                    isRecording: viewModel.isRecording,
                    isProcessing: viewModel.isProcessing
                ) {
                    viewModel.toggleRecording()
                }
                .frame(width: 56, height: 56)
            }
            .padding(.horizontal, Theme.spacingMD)
            .padding(.vertical, Theme.spacingSM)
            .animation(.spring(response: 0.3), value: viewModel.inputText.isEmpty)
        }
        .background(
            Theme.surface.opacity(0.8)
                .background(.ultraThinMaterial)
        )
    }
}

// MARK: - Harness Picker Sheet

struct HarnessPickerSheet: View {
    @Binding var selected: Harness
    let onSelect: (Harness) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.spacingSM) {
                        ForEach(Harness.allHarnesses) { harness in
                            Button {
                                onSelect(harness)
                            } label: {
                                HStack(spacing: Theme.spacingMD) {
                                    HarnessAvatar(harness, size: 44)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(harness.name)
                                            .font(Theme.headline)
                                            .foregroundStyle(Theme.textPrimary)
                                        Text(harness.description)
                                            .font(Theme.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    if harness.isFree {
                                        Text("FREE")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(Theme.success)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Theme.success.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                    
                                    if harness.id == selected.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.success)
                                    }
                                }
                                .padding(Theme.spacingMD)
                                .glassBackground()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Theme.spacingMD)
                }
            }
            .navigationTitle("Switch Harness")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
    .environment(AppRouter())
}
