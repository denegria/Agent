import Foundation

/// Home screen view model
@Observable
final class HomeViewModel {
    var activeHarness: Harness = .defaultHarness
    
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Good night"
        }
    }
}
