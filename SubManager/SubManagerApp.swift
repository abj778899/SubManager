import SwiftUI

@main
struct SubManagerApp: App {
    @StateObject private var viewModel = SubscriptionViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
