import SwiftData
import SwiftUI

@main
struct DirectorSeatApp: App {
    @StateObject private var storeManager = StoreManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await storeManager.loadProducts()
                    await storeManager.restorePurchases()
                }
        }
        .modelContainer(for: FilmProject.self)
    }
}
