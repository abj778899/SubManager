import Foundation
import Combine
import UIKit

class SubscriptionViewModel: ObservableObject {
    @Published var subscriptions: [Subscription] = []
    @Published var selectedSubscription: Subscription?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showAddSubscription = false

    private let parser = SubscriptionParser.shared

    init() {
        loadSubscriptions()
        // 如果没有订阅，添加预设的订阅
        if subscriptions.isEmpty {
            addDefaultSubscription()
        }
    }

    // 添加预设订阅
    func addDefaultSubscription() {
        let defaultURL = "https://sub2.smallstrawberry.com/api/v1/client/subscribe?token=74ffb35155f2d0098ff814b82e3949fc"
        addSubscription(name: "一元机场", url: defaultURL)
    }

    // 添加订阅
    func addSubscription(name: String, url: String) {
        let subscription = Subscription(
            name: name,
            url: url,
            addTime: Date(),
            updateTime: nil,
            nodeCount: 0,
            nodes: []
        )
        subscriptions.append(subscription)
        saveSubscriptions()
        updateSubscription(subscription)
    }

    // 删除订阅
    func removeSubscription(_ subscription: Subscription) {
        subscriptions.removeAll { $0.id == subscription.id }
        saveSubscriptions()
    }

    // 更新订阅
    func updateSubscription(_ subscription: Subscription) {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) else { return }

        isLoading = true
        errorMessage = nil

        parser.parseSubscription(url: subscription.url) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let data):
                    self?.subscriptions[index].nodes = data.nodes
                    self?.subscriptions[index].nodeCount = data.nodes.count
                    self?.subscriptions[index].updateTime = Date()
                    if !data.name.isEmpty && data.name != "订阅" {
                        self?.subscriptions[index].name = data.name
                    }
                    self?.saveSubscriptions()

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // 更新所有订阅
    func updateAllSubscriptions() {
        for subscription in subscriptions {
            updateSubscription(subscription)
        }
    }

    // 测试节点延迟
    func testNodeLatency(_ node: Node, completion: @escaping (Int?) -> Void) {
        let url = URL(string: "http://\(node.server):\(node.port)")!
        let startTime = Date()

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { _, _, error in
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            if error != nil {
                // 连接失败但有响应时间，返回超时
                completion(nil)
            } else {
                completion(latency)
            }
        }.resume()
    }

    // 复制节点链接
    func copyNodeLink(_ node: Node) {
        UIPasteboard.general.string = node.nodeLink
    }

    // 导出Clash配置
    func exportClashConfig() -> String {
        return parser.generateClashConfig(subscriptions: subscriptions)
    }

    // 保存到文件
    func saveConfigToFile() -> URL? {
        let config = exportClashConfig()
        let fileName = "config.yaml"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try config.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }

    // MARK: - 持久化
    private func saveSubscriptions() {
        if let encoded = try? JSONEncoder().encode(subscriptions) {
            UserDefaults.standard.set(encoded, forKey: "subscriptions")
        }
    }

    private func loadSubscriptions() {
        if let data = UserDefaults.standard.data(forKey: "subscriptions"),
           let decoded = try? JSONDecoder().decode([Subscription].self, from: data) {
            subscriptions = decoded
        }
    }
}
