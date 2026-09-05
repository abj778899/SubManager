import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: SubscriptionViewModel
    @State private var showExportView = false
    @State private var exportContent = ""

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("统计")) {
                    HStack {
                        Text("订阅数量")
                        Spacer()
                        Text("\(viewModel.subscriptions.count)")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("节点总数")
                        Spacer()
                        Text("\(totalNodes)")
                            .foregroundColor(.gray)
                    }
                }

                Section(header: Text("操作")) {
                    Button(action: {
                        viewModel.updateAllSubscriptions()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundColor(.blue)
                            Text("更新全部订阅")
                        }
                    }

                    Button(action: {
                        exportContent = viewModel.exportClashConfig()
                        showExportView = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up.fill")
                                .foregroundColor(.green)
                            Text("导出 Clash 配置")
                        }
                    }

                    Button(action: {
                        if let url = viewModel.saveConfigToFile() {
                            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let rootVC = windowScene.windows.first?.rootViewController {
                                rootVC.present(activityVC, animated: true)
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.orange)
                            Text("分享配置文件")
                        }
                    }
                }

                Section(header: Text("使用说明")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. 添加订阅链接，自动解析节点")
                        Text("2. 点击节点测试延迟")
                        Text("3. 点击复制图标复制节点链接")
                        Text("4. 导出配置可导入 Shadowrocket / Stash / Loon 等代理 App")
                        Text("5. 支持 Trojan / VMess / SS / SSR / VLESS 等协议")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 4)
                }

                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("支持协议")
                        Spacer()
                        Text("Trojan/VMess/SS/SSR/VLESS")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showExportView) {
                NavigationView {
                    ScrollView {
                        Text(exportContent)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                    }
                    .navigationTitle("Clash 配置")
                    .navigationBarItems(trailing: Button("完成") {
                        showExportView = false
                    })
                }
            }
        }
    }

    private var totalNodes: Int {
        viewModel.subscriptions.reduce(0) { $0 + $1.nodes.count }
    }
}
