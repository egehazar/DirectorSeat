import SwiftData
import SwiftUI

@main
struct DirectorSeatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: FilmProject.self)
    }
}
