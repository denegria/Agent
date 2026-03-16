import SwiftUI

/// Harness avatar/icon displayed in the chat screen and marketplace
struct HarnessAvatar: View {
    let harness: Harness
    let size: CGFloat
    
    init(_ harness: Harness, size: CGFloat = 56) {
        self.harness = harness
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: harness.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            Image(systemName: harness.iconName)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(.white)
        }
        .shadow(color: harness.gradientColors.first?.opacity(0.4) ?? .clear, radius: 8)
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        HStack(spacing: 20) {
            HarnessAvatar(Harness.defaultHarness)
            HarnessAvatar(Harness.preview(icon: "music.note", name: "Musician"), size: 72)
            HarnessAvatar(Harness.preview(icon: "lightbulb.fill", name: "Startup"), size: 44)
        }
    }
}
