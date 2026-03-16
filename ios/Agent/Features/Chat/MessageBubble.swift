import SwiftUI

/// Chat message bubble with role-based styling and streaming support
struct MessageBubble: View {
    let message: Message
    
    private var isUser: Bool { message.role == .user }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                // Tool indicator styling
                if !isUser && message.content.hasPrefix("🔧") {
                    toolIndicator
                } else {
                    // Regular message
                    HStack(alignment: .bottom, spacing: 0) {
                        Text(message.content)
                            .font(Theme.body)
                            .foregroundStyle(isUser ? .white : Theme.textPrimary)
                            .textSelection(.enabled)
                        
                        // Blinking cursor for streaming
                        if message.isStreaming && !message.content.isEmpty {
                            BlinkingCursor()
                                .padding(.leading, 1)
                        }
                    }
                    .padding(.horizontal, Theme.spacingMD)
                    .padding(.vertical, 10)
                    .background(
                        isUser
                            ? AnyShapeStyle(Theme.accentGradient)
                            : AnyShapeStyle(Theme.surface)
                    )
                    .clipShape(
                        BubbleShape(isUser: isUser)
                    )
                }
                
                // Timestamp
                if !message.isStreaming {
                    Text(message.timestamp.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textMuted)
                        .padding(.horizontal, 4)
                }
            }
            
            if !isUser { Spacer(minLength: 60) }
        }
    }
    
    // MARK: - Tool indicator
    
    private var toolIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(Theme.accent)
                .scaleEffect(0.7)
            
            Text(message.content.replacingOccurrences(of: "🔧 ", with: ""))
                .font(Theme.footnote)
                .foregroundStyle(Theme.textSecondary)
                .italic()
        }
        .padding(.horizontal, Theme.spacingMD)
        .padding(.vertical, 8)
        .background(Theme.accent.opacity(0.08))
        .clipShape(Capsule())
    }
}


// MARK: - Blinking Cursor

struct BlinkingCursor: View {
    @State private var isVisible = true
    
    var body: some View {
        Rectangle()
            .fill(Theme.accent)
            .frame(width: 2, height: 16)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isVisible = false
                }
            }
    }
}


// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let isUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailRadius: CGFloat = 6
        
        var path = Path()
        
        if isUser {
            // User bubble — rounded with small tail bottom-right
            path.addRoundedRect(in: CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: rect.height
            ), cornerRadii: RectangleCornerRadii(
                topLeading: radius,
                bottomLeading: radius,
                bottomTrailing: tailRadius,
                topTrailing: radius
            ))
        } else {
            // Assistant bubble — rounded with small tail bottom-left
            path.addRoundedRect(in: CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: rect.height
            ), cornerRadii: RectangleCornerRadii(
                topLeading: radius,
                bottomLeading: tailRadius,
                bottomTrailing: radius,
                topTrailing: radius
            ))
        }
        
        return path
    }
}


// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var dot1 = false
    @State private var dot2 = false
    @State private var dot3 = false
    
    var body: some View {
        HStack {
            HStack(spacing: 5) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 8, height: 8)
                    .offset(y: dot1 ? -6 : 0)
                Circle()
                    .fill(Theme.accent.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .offset(y: dot2 ? -6 : 0)
                Circle()
                    .fill(Theme.accent.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .offset(y: dot3 ? -6 : 0)
            }
            .padding(.horizontal, Theme.spacingMD)
            .padding(.vertical, 12)
            .background(Theme.surface)
            .clipShape(Capsule())
            
            Spacer(minLength: 60)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                dot1 = true
            }
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(0.15)) {
                dot2 = true
            }
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(0.3)) {
                dot3 = true
            }
        }
    }
}


#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 12) {
            MessageBubble(message: .userMessage("Hello! How are you?"))
            MessageBubble(message: .assistantMessage("I'm doing great! How can I help you today?"))
            MessageBubble(message: .assistantMessage("Thinking about this", streaming: true))
            MessageBubble(message: .assistantMessage("🔧 Using web_search...", streaming: true))
            TypingIndicator()
        }
        .padding()
    }
}
