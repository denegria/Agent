import SwiftUI

/// Animated audio waveform visualization
struct WaveformView: View {
    let isAnimating: Bool
    let barCount: Int
    let color: Color
    
    @State private var amplitudes: [CGFloat]
    
    init(isAnimating: Bool, barCount: Int = 40, color: Color = Theme.accent) {
        self.isAnimating = isAnimating
        self.barCount = barCount
        self.color = color
        self._amplitudes = State(initialValue: Array(repeating: 0.1, count: barCount))
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: amplitudes[index] * 40)
                    .animation(
                        .easeInOut(duration: Double.random(in: 0.15...0.35))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.02),
                        value: amplitudes[index]
                    )
            }
        }
        .frame(height: 44)
        .onChange(of: isAnimating) { _, animating in
            if animating {
                startAnimating()
            } else {
                stopAnimating()
            }
        }
        .onAppear {
            if isAnimating { startAnimating() }
        }
    }
    
    private func startAnimating() {
        for i in amplitudes.indices {
            amplitudes[i] = CGFloat.random(in: 0.2...1.0)
        }
        // Continuously randomize
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { timer in
            if !isAnimating {
                timer.invalidate()
                return
            }
            for i in amplitudes.indices {
                amplitudes[i] = CGFloat.random(in: 0.15...1.0)
            }
        }
    }
    
    private func stopAnimating() {
        withAnimation(.easeOut(duration: 0.3)) {
            for i in amplitudes.indices {
                amplitudes[i] = 0.1
            }
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 30) {
            WaveformView(isAnimating: true)
            WaveformView(isAnimating: true, color: Theme.success)
            WaveformView(isAnimating: false)
        }
        .padding()
    }
}
