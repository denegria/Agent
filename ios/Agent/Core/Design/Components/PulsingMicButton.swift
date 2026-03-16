import SwiftUI

/// Large animated pulsing microphone button for voice chat
struct PulsingMicButton: View {
    let isRecording: Bool
    let isProcessing: Bool
    let action: () -> Void
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0
    
    private var buttonSize: CGFloat { 88 }
    
    var body: some View {
        ZStack {
            // Outer pulse rings (visible when recording)
            if isRecording {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Theme.accent.opacity(0.3 - Double(i) * 0.1), lineWidth: 2)
                        .frame(width: buttonSize + CGFloat(i) * 30,
                               height: buttonSize + CGFloat(i) * 30)
                        .scaleEffect(pulseScale)
                        .opacity(glowOpacity)
                }
            }
            
            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Theme.accent.opacity(isRecording ? 0.4 : 0.0),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: buttonSize / 2,
                        endRadius: buttonSize
                    )
                )
                .frame(width: buttonSize * 2, height: buttonSize * 2)
            
            // Main button
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Theme.micGradient : Theme.accentGradient)
                        .frame(width: buttonSize, height: buttonSize)
                        .shadow(color: Theme.accent.opacity(0.5), radius: isRecording ? 20 : 10)
                    
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(isRecording ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                startPulsing()
            } else {
                stopPulsing()
            }
        }
    }
    
    private func startPulsing() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.3
            glowOpacity = 0.8
        }
    }
    
    private func stopPulsing() {
        withAnimation(.easeOut(duration: 0.3)) {
            pulseScale = 1.0
            glowOpacity = 0.0
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 40) {
            PulsingMicButton(isRecording: false, isProcessing: false) {}
            PulsingMicButton(isRecording: true, isProcessing: false) {}
            PulsingMicButton(isRecording: false, isProcessing: true) {}
        }
    }
}
