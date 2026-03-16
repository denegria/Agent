import SwiftUI

/// A glassmorphism-styled card with frosted background
struct GlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(Theme.spacingMD)
            .glassBackground()
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Premium Harness")
                    .font(Theme.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("Unlock advanced capabilities")
                    .font(Theme.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
}
