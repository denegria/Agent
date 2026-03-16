import Foundation
import StoreKit

/// Marketplace view model — manages harness catalog and IAP purchases
@Observable
final class MarketplaceViewModel {
    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var isLoading = false
    
    // StoreKit product identifiers
    static let premiumSetupID = "com.agent.premium_setup"
    static let proSubscriptionID = "com.agent.pro_monthly"
    
    static let allProductIDs: Set<String> = [
        premiumSetupID,
        proSubscriptionID,
        "com.agent.harness.startup",
        "com.agent.harness.musician",
        "com.agent.harness.research",
        "com.agent.harness.lifeos",
        "com.agent.harness.website"
    ]
    
    init() {
        Task { await loadProducts() }
        Task { await observeTransactions() }
    }
    
    // MARK: - Load Products
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            products = try await Product.products(for: Self.allProductIDs)
        } catch {
            print("MarketplaceVM: Failed to load products - \(error)")
        }
    }
    
    // MARK: - Purchase
    
    func purchasePremium() {
        guard let product = products.first(where: { $0.id == Self.premiumSetupID }) else {
            return
        }
        Task { await purchase(product) }
    }
    
    func purchaseHarness(_ harness: Harness) {
        guard let productID = harness.productID,
              let product = products.first(where: { $0.id == productID }) else {
            return
        }
        Task { await purchase(product) }
    }
    
    private func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                
                // Verify with backend
                do {
                    _ = try await APIClient.shared.verifyPurchase(
                        transactionID: String(transaction.id),
                        productID: transaction.productID
                    )
                } catch {
                    // Proceed anyway — backend verification can be retried
                    print("MarketplaceVM: Backend verification failed - \(error)")
                }
                
                purchasedProductIDs.insert(transaction.productID)
                await transaction.finish()
                
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            print("MarketplaceVM: Purchase failed - \(error)")
        }
    }
    
    // MARK: - Transaction Observation
    
    private func observeTransactions() async {
        for await result in Transaction.updates {
            guard let transaction = try? checkVerified(result) else { continue }
            purchasedProductIDs.insert(transaction.productID)
            await transaction.finish()
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    func isPurchased(_ harness: Harness) -> Bool {
        harness.isFree || purchasedProductIDs.contains(harness.productID ?? "")
    }
    
    // MARK: - Errors
    
    enum StoreError: LocalizedError {
        case verificationFailed
        
        var errorDescription: String? {
            "Purchase verification failed"
        }
    }
}
