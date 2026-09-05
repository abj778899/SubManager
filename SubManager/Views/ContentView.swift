import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: SubscriptionViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            SubscriptionListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("订阅")
                }
                .tag(0)

            AllNodesView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("节点")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("设置")
                }
                .tag(2)
        }
        .sheet(isPresented: $viewModel.showAddSubscription) {
            AddSubscriptionView()
        }
        .alert(item: Binding(
            get: { viewModel.errorMessage.map { AlertWrapper(message: $0) } },
            set: { _ in viewModel.errorMessage = nil }
        )) { wrapper in
            Alert(title: Text("错误"), message: Text(wrapper.message), dismissButton: .default(Text("确定")))
        }
    }
}

struct AlertWrapper: Identifiable {
    let id = UUID()
    let message: String
}
