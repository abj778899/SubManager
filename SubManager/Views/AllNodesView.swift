import SwiftUI

struct AllNodesView: View {
    @EnvironmentObject var viewModel: SubscriptionViewModel
    @State private var searchText = ""
    @State private var showCopiedAlert = false
    @State private var selectedType = "全部"

    let types = ["全部", "trojan", "vmess", "ss", "ssr", "vless"]

    var allNodes: [Node] {
        var nodes: [Node] = []
        for sub in viewModel.subscriptions {
            nodes.append(contentsOf: sub.nodes)
        }
        return nodes
    }

    var filteredNodes: [Node] {
        var nodes = allNodes

        if selectedType != "全部" {
            nodes = nodes.filter { $0.type.lowercased() == selectedType.lowercased() }
        }

        if !searchText.isEmpty {
            nodes = nodes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return nodes
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 类型筛选
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(types, id: \.self) { type in
                            Button(action: {
                                selectedType = type
                            }) {
                                Text(type.uppercased())
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedType == type ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedType == type ? .white : .gray)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                List {
                    ForEach(filteredNodes) { node in
                        NodeRow(node: node) {
                            viewModel.copyNodeLink(node)
                            showCopiedAlert = true
                        }
                    }
                }
            }
            .navigationTitle("全部节点")
            .searchable(text: $searchText, prompt: "搜索节点")
            .alert("已复制", isPresented: $showCopiedAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("节点链接已复制到剪贴板")
            }
            .overlay(
                VStack {
                    if filteredNodes.isEmpty {
                        Text("没有节点")
                            .foregroundColor(.gray)
                        Text("请先更新订阅")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            )
        }
    }
}
