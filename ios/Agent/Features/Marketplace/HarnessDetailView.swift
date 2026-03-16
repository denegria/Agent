import SwiftUI

/// Harness detail view — shows full info, tool capabilities, and purchase option
struct HarnessDetailView: View {
    let harness: Harness
    @State private var viewModel = MarketplaceViewModel()
    @Environment(\.dismiss) private var dismiss
    
    /// Tool display metadata
    private struct ToolInfo {
        let icon: String
        let name: String
        let description: String
        let color: Color
    }
    
    private var toolDetails: [ToolInfo] {
        guard let tools = harness.toolsConfig else { return [] }
        return tools.compactMap { tool -> ToolInfo? in
            switch tool {
            case "web_search":
                return ToolInfo(icon: "magnifyingglass", name: "Web Search", description: "Search the web in real time", color: Theme.accent)
            case "web_fetch":
                return ToolInfo(icon: "globe", name: "Web Fetch", description: "Read and extract content from URLs", color: Theme.success)
            case "calculator":
                return ToolInfo(icon: "function", name: "Calculator", description: "Evaluate math expressions", color: Theme.warning)
            case "get_datetime":
                return ToolInfo(icon: "clock", name: "Date & Time", description: "Get current date, time, and day", color: Theme.secondary)
            case "memory_note":
                return ToolInfo(icon: "brain", name: "Memory", description: "Remember your preferences forever", color: .purple)
            case "set_reminder":
                return ToolInfo(icon: "bell.fill", name: "Reminders", description: "Schedule notifications", color: .orange)
            case "document_writer":
                return ToolInfo(icon: "doc.text.fill", name: "Document Writer", description: "Draft structured documents", color: Theme.accent)
            case "chord_lookup":
                return ToolInfo(icon: "guitars.fill", name: "Chord Lookup", description: "Find guitar/piano chords", color: Theme.success)
            case "rhyme_finder":
                return ToolInfo(icon: "quote.closing", name: "Rhyme Finder", description: "Find rhyming words", color: Theme.warning)
            case "summarizer":
                return ToolInfo(icon: "text.justify.leading", name: "Summarizer", description: "Summarize long texts", color: Theme.secondary)
            default:
                return ToolInfo(icon: "puzzlepiece.fill", name: tool.replacingOccurrences(of: "_", with: " ").capitalized, description: "Custom capability", color: Theme.textMuted)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.spacingLG) {
                        // Hero
                        VStack(spacing: Theme.spacingMD) {
                            HarnessAvatar(harness, size: 100)
                            
                            Text(harness.name)
                                .font(Theme.title)
                                .foregroundStyle(Theme.textPrimary)
                            
                            HStack(spacing: Theme.spacingSM) {
                                Text(harness.category.rawValue)
                                    .font(Theme.caption)
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Theme.accent.opacity(0.15))
                                    .clipShape(Capsule())
                                
                                if harness.isFree {
                                    Text("FREE")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Theme.success)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Theme.success.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.top, Theme.spacingLG)
                        
                        // Description
                        GlassCard {
                            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                                Text("About")
                                    .font(Theme.headline)
                                    .foregroundStyle(Theme.textPrimary)
                                
                                Text(harness.description)
                                    .font(Theme.body)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, Theme.spacingLG)
                        
                        // Tools with icons
                        if !toolDetails.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: Theme.spacingMD) {
                                    HStack(spacing: Theme.spacingSM) {
                                        Image(systemName: "wrench.and.screwdriver.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Theme.accent)
                                        Text("Capabilities")
                                            .font(Theme.headline)
                                            .foregroundStyle(Theme.textPrimary)
                                        Spacer()
                                        Text("\(toolDetails.count) tools")
                                            .font(Theme.caption)
                                            .foregroundStyle(Theme.textMuted)
                                    }
                                    
                                    ForEach(toolDetails.indices, id: \.self) { index in
                                        let tool = toolDetails[index]
                                        
                                        HStack(spacing: Theme.spacingMD) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(tool.color.opacity(0.15))
                                                    .frame(width: 34, height: 34)
                                                
                                                Image(systemName: tool.icon)
                                                    .font(.system(size: 15))
                                                    .foregroundStyle(tool.color)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(tool.name)
                                                    .font(Theme.body)
                                                    .foregroundStyle(Theme.textPrimary)
                                                Text(tool.description)
                                                    .font(Theme.caption)
                                                    .foregroundStyle(Theme.textSecondary)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Theme.success)
                                                .font(.system(size: 14))
                                        }
                                        
                                        if index < toolDetails.count - 1 {
                                            Divider().background(Color.white.opacity(0.05))
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, Theme.spacingLG)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // Fixed bottom CTA
                VStack {
                    Spacer()
                    
                    if harness.isFree {
                        activateButton(label: "Activate for Free", gradient: Theme.accentGradient)
                    } else if viewModel.isPurchased(harness) {
                        activateButton(label: "Activate", gradient: Theme.accentGradient)
                    } else {
                        purchaseButton
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textMuted)
                            .font(.title2)
                    }
                }
            }
        }
    }
    
    private func activateButton(label: String, gradient: LinearGradient) -> some View {
        Button {
            dismiss()
        } label: {
            HStack {
                Image(systemName: "bolt.fill")
                Text(label)
            }
            .font(Theme.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(gradient)
            .cornerRadius(Theme.radiusLG)
        }
        .padding(Theme.spacingLG)
        .background(
            Theme.background
                .shadow(color: .black.opacity(0.3), radius: 20, y: -10)
        )
    }
    
    private var purchaseButton: some View {
        Button {
            viewModel.purchaseHarness(harness)
        } label: {
            HStack {
                Image(systemName: "cart.fill")
                Text("Purchase — $2.99")
            }
            .font(Theme.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Theme.micGradient)
            .cornerRadius(Theme.radiusLG)
        }
        .padding(Theme.spacingLG)
        .background(
            Theme.background
                .shadow(color: .black.opacity(0.3), radius: 20, y: -10)
        )
    }
}

#Preview {
    HarnessDetailView(harness: Harness.allHarnesses[1])
}
