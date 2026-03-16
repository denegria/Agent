import SwiftUI
import StoreKit

/// Harness marketplace — browse, preview, and purchase harnesses
struct MarketplaceView: View {
    @State private var viewModel = MarketplaceViewModel()
    @State private var selectedCategory: Harness.HarnessCategory? = nil
    @State private var selectedHarness: Harness? = nil
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Theme.spacingLG) {
                    // Header
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        Text("Harness Marketplace")
                            .font(Theme.largeTitle)
                            .foregroundStyle(Theme.textPrimary)
                        
                        Text("Unlock specialized AI agents for any task")
                            .font(Theme.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.spacingLG)
                    .padding(.top, Theme.spacingSM)
                    
                    // Premium banner
                    premiumBanner
                        .padding(.horizontal, Theme.spacingLG)
                    
                    // Category filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.spacingSM) {
                            categoryChip(nil, label: "All")
                            ForEach(Harness.HarnessCategory.allCases, id: \.self) { cat in
                                categoryChip(cat, label: cat.rawValue)
                            }
                        }
                        .padding(.horizontal, Theme.spacingLG)
                    }
                    
                    // Harness grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: Theme.spacingMD) {
                        ForEach(filteredHarnesses) { harness in
                            harnessCard(harness)
                                .onTapGesture {
                                    selectedHarness = harness
                                }
                        }
                    }
                    .padding(.horizontal, Theme.spacingLG)
                    
                    Spacer(minLength: 80)
                }
            }
        }
        .navigationTitle("")
        .sheet(item: $selectedHarness) { harness in
            HarnessDetailView(harness: harness)
        }
    }
    
    private var filteredHarnesses: [Harness] {
        guard let category = selectedCategory else {
            return Harness.allHarnesses
        }
        return Harness.allHarnesses.filter { $0.category == category }
    }
    
    // MARK: - Premium Banner
    
    private var premiumBanner: some View {
        GlassCard {
            HStack(spacing: Theme.spacingMD) {
                ZStack {
                    Circle()
                        .fill(Theme.micGradient)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "crown.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Get Premium Setup")
                        .font(Theme.headline)
                        .foregroundStyle(Theme.textPrimary)
                    
                    Text("Unlock all harnesses + unlimited switching")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                
                Spacer()
                
                Button {
                    viewModel.purchasePremium()
                } label: {
                    Text("$9.99")
                        .font(Theme.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.accentGradient)
                        .cornerRadius(Theme.radiusFull)
                }
            }
        }
    }
    
    // MARK: - Category Chip
    
    private func categoryChip(_ category: Harness.HarnessCategory?, label: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedCategory = category
            }
        } label: {
            Text(label)
                .font(Theme.footnote)
                .foregroundStyle(selectedCategory == category ? .white : Theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selectedCategory == category ? Theme.accent : Theme.surface)
                .cornerRadius(Theme.radiusFull)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusFull)
                        .stroke(Color.white.opacity(selectedCategory == category ? 0 : 0.1), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Harness Card
    
    private func harnessCard(_ harness: Harness) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack {
                HarnessAvatar(harness, size: 44)
                Spacer()
                if harness.isFree {
                    Text("FREE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.success.opacity(0.15))
                        .cornerRadius(4)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                }
            }
            
            Text(harness.name)
                .font(Theme.headline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            
            Text(harness.description)
                .font(Theme.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(3)
        }
        .padding(Theme.spacingMD)
        .glassBackground()
    }
}

#Preview {
    NavigationStack {
        MarketplaceView()
    }
}
