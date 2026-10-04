import SwiftUI

@main
struct AnswersWatchApp: App {
    @StateObject private var store = WatchPaperStore.shared
    @StateObject private var cloudSync = WatchCloudSync.shared

    var body: some Scene {
        WindowGroup {
            WatchMainView()
                .preferredColorScheme(.dark)
        }
    }
}
