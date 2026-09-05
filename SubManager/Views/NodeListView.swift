import SwiftUI

struct NodeListView: View {
    let subscription: Subscription
    @EnvironmentObject var viewModel: SubscriptionViewModel
    @State private var searchText = ""
    @State private var showCopiedAlert = false

    var filteredNodes: [Node] {
        if searchText.isEmpty {
            return subscription.nodes
        }
        return subscription.nodes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            ForEach(filteredNodes) { node in
                NodeRow(node: node) {
                    viewModel.copyNodeLink(node)
                    showCopiedAlert = true
                }
            }
        }
        .navigationTitle(subscription.name)
        .searchable(text: $searchText, prompt: "搜索节点")
        .alert("已复制", isPresented: $showCopiedAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("节点链接已复制到剪贴板")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        viewModel.updateSubscription(subscription)
                    }) {
                        Label("更新订阅", systemImage: "arrow.clockwise")
                    }
                    Button(action: {
                        if let url = viewModel.saveConfigToFile() {
                            // 分享文件
                            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let rootVC = windowScene.windows.first?.rootViewController {
                                rootVC.present(activityVC, animated: true)
                            }
                        }
                    }) {
                        Label("导出配置", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

struct NodeRow: View {
    let node: Node
    let onCopy: () -> Void
    @State private var latency: Int?
    @State private var isTesting = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.subheadline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(node.type.uppercased())
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(typeColor(node.type).opacity(0.2))
                        .foregroundColor(typeColor(node.type))
                        .cornerRadius(4)

                    Text("\(node.server):\(node.port)")
                        .font(.caption2)
                        .foregroundColor(.gray)

                    if let latency = latency {
                        Text("\(latency)ms")
                            .font(.caption2)
                            .foregroundColor(latencyColor(latency))
                    } else if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }

            Spacer()

            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            testLatency()
        }
    }

    private func testLatency() {
        isTesting = true
        latency = nil

        let url = URL(string: "http://\(node.server):\(node.port)")!
        let startTime = Date()

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { _, _, error in
            DispatchQueue.main.async {
                isTesting = false
                if error == nil {
                    latency = Int(Date().timeIntervalSince(startTime) * 1000)
                } else {
                    latency = 9999
                }
            }
        }.resume()
    }

    private func typeColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "trojan": return .purple
        case "vmess": return .blue
        case "ss", "shadowsocks": return .green
        case "ssr": return .orange
        case "vless": return .pink
        default: return .gray
        }
    }

    private func latencyColor(_ latency: Int) -> Color {
        if latency < 100 { return .green }
        if latency < 300 { return .yellow }
        if latency < 1000 { return .orange }
        return .red
    }
}
