import Foundation

class SubscriptionParser {
    static let shared = SubscriptionParser()

    func parseSubscription(url: String, completion: @escaping (Result<(name: String, nodes: [Node]), Error>) -> Void) {
        guard let url = URL(string: url) else {
            completion(.failure(NSError(domain: "SubscriptionParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("clash.meta", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "SubscriptionParser", code: -2, userInfo: [NSLocalizedDescriptionKey: "无数据"])))
                return
            }

            // 尝试解析为Clash YAML
            if let nodes = self.parseClashYAML(data: data) {
                let name = (response as? HTTPURLResponse)?.allHeaderFields["Subscription-Userinfo"] as? String ?? "订阅"
                completion(.success((name: name, nodes: nodes)))
                return
            }

            // 尝试解析为Base64编码的节点列表
            if let content = String(data: data, encoding: .utf8) {
                // 检查是否是base64
                if let decodedData = Data(base64Encoded: content.trimmingCharacters(in: .whitespacesAndNewlines)),
                   let decodedString = String(data: decodedData, encoding: .utf8) {
                    let nodes = self.parseNodeLinks(decodedString)
                    if !nodes.isEmpty {
                        completion(.success((name: "订阅", nodes: nodes)))
                        return
                    }
                }

                // 直接解析节点链接
                let nodes = self.parseNodeLinks(content)
                if !nodes.isEmpty {
                    completion(.success((name: "订阅", nodes: nodes)))
                    return
                }
            }

            completion(.failure(NSError(domain: "SubscriptionParser", code: -3, userInfo: [NSLocalizedDescriptionKey: "无法解析订阅格式"])))
        }.resume()
    }

    // 解析Clash YAML格式
    func parseClashYAML(data: Data) -> [Node]? {
        guard let content = String(data: data, encoding: .utf8) else { return nil }

        // 简单的YAML解析，查找proxies部分
        guard let proxiesRange = content.range(of: "proxies:") else { return nil }

        let proxiesContent = String(content[proxiesRange.upperBound...])
        var nodes: [Node] = []

        // 按行解析
        let lines = proxiesContent.components(separatedBy: .newlines)
        var inProxies = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("- {") || trimmed.hasPrefix("- name:") {
                inProxies = true
                if let node = parseClashProxyLine(line) {
                    nodes.append(node)
                }
            } else if inProxies && !trimmed.isEmpty && !trimmed.hasPrefix("-") && !trimmed.hasPrefix(" ") && !trimmed.hasPrefix("#") {
                // 遇到新的顶级键，结束proxies解析
                break
            }
        }

        return nodes.isEmpty ? nil : nodes
    }

    // 解析单行Clash代理配置
    func parseClashProxyLine(_ line: String) -> Node? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var content = trimmed
        if content.hasPrefix("- ") {
            content = String(content.dropFirst(2))
        }

        // 尝试解析为JSON格式（内联格式）
        if content.hasPrefix("{") {
            if let jsonData = content.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                return parseClashProxyDict(dict)
            }
        }

        // 解析为YAML键值对格式
        var dict: [String: Any] = [:]
        let pattern = "([a-zA-Z_-]+):\\s*([^,}]+)"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            for match in matches {
                if let keyRange = Range(match.range(at: 1), in: content),
                   let valueRange = Range(match.range(at: 2), in: content) {
                    let key = String(content[keyRange])
                    let value = String(content[valueRange]).trimmingCharacters(in: .whitespaces)
                    dict[key] = parseValue(value)
                }
            }
        }

        return parseClashProxyDict(dict)
    }

    // 解析Clash代理字典
    func parseClashProxyDict(_ dict: [String: Any]) -> Node? {
        guard let name = dict["name"] as? String,
              let type = dict["type"] as? String,
              let server = dict["server"] as? String,
              let port = (dict["port"] as? Int) ?? Int(dict["port"] as? String ?? "") else {
            return nil
        }

        var node = Node(name: name, type: type, server: server, port: port)

        node.password = dict["password"] as? String
        node.uuid = dict["uuid"] as? String
        node.cipher = dict["cipher"] as? String
        node.network = dict["network"] as? String
        node.sni = dict["sni"] as? String
        node.wsPath = dict["ws-path"] as? String ?? dict["path"] as? String
        node.wsHost = dict["ws-headers"] as? String ?? (dict["ws-headers"] as? [String: String])?["Host"]
        node.tls = (dict["tls"] as? Bool) ?? (type.lowercased() == "trojan")
        node.udp = dict["udp"] as? Bool ?? true
        node.skipCertVerify = dict["skip-cert-verify"] as? Bool ?? false

        return node
    }

    // 解析值类型
    func parseValue(_ value: String) -> Any {
        if value == "true" { return true }
        if value == "false" { return false }
        if let int = Int(value) { return int }
        return value
    }

    // 解析节点链接列表
    func parseNodeLinks(_ content: String) -> [Node] {
        var nodes: [Node] = []
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            if let node = parseNodeLink(trimmed) {
                nodes.append(node)
            }
        }

        return nodes
    }

    // 解析单个节点链接
    func parseNodeLink(_ link: String) -> Node? {
        if link.hasPrefix("trojan://") {
            return parseTrojanLink(link)
        } else if link.hasPrefix("vmess://") {
            return parseVmessLink(link)
        } else if link.hasPrefix("ss://") {
            return parseSSLink(link)
        }
        return nil
    }

    // 解析Trojan链接
    func parseTrojanLink(_ link: String) -> Node? {
        guard let url = URL(string: link) else { return nil }
        let password = url.user ?? ""
        let server = url.host ?? ""
        let port = url.port ?? 443
        let name = url.fragment?.removingPercentEncoding ?? "Trojan"

        var node = Node(name: name, type: "trojan", server: server, port: port)
        node.password = password
        node.tls = true

        if let query = url.query {
            let params = query.components(separatedBy: "&")
            for param in params {
                let parts = param.components(separatedBy: "=")
                if parts.count == 2 {
                    let key = parts[0]
                    let value = parts[1].removingPercentEncoding ?? parts[1]
                    switch key {
                    case "sni": node.sni = value
                    case "type": node.network = value
                    case "path": node.wsPath = value
                    case "host": node.wsHost = value
                    case "allowInsecure": node.skipCertVerify = value == "1"
                    default: break
                    }
                }
            }
        }

        return node
    }

    // 解析VMess链接
    func parseVmessLink(_ link: String) -> Node? {
        let base64Part = String(link.dropFirst("vmess://".count))
        guard let data = Data(base64Encoded: base64Part),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let name = json["ps"] as? String ?? "VMess"
        let server = json["add"] as? String ?? ""
        let port = (json["port"] as? Int) ?? Int(json["port"] as? String ?? "") ?? 443
        let uuid = json["id"] as? String ?? ""

        var node = Node(name: name, type: "vmess", server: server, port: port)
        node.uuid = uuid
        node.cipher = json["scy"] as? String ?? "auto"
        node.network = json["net"] as? String ?? "tcp"
        node.wsPath = json["path"] as? String
        node.wsHost = json["host"] as? String
        node.tls = (json["tls"] as? String) == "tls"
        node.sni = json["sni"] as? String

        return node
    }

    // 解析SS链接
    func parseSSLink(_ link: String) -> Node? {
        guard let url = URL(string: link) else { return nil }
        let userInfo = url.user ?? ""
        let server = url.host ?? ""
        let port = url.port ?? 8388
        let name = url.fragment?.removingPercentEncoding ?? "SS"

        // 解码userInfo
        guard let decodedData = Data(base64Encoded: userInfo),
              let decoded = String(data: decodedData, encoding: .utf8) else {
            return nil
        }

        let parts = decoded.components(separatedBy: ":")
        guard parts.count >= 2 else { return nil }

        var node = Node(name: name, type: "ss", server: server, port: port)
        node.cipher = parts[0]
        node.password = parts.dropFirst().joined(separator: ":")

        return node
    }

    // 生成Clash配置文件
    func generateClashConfig(subscriptions: [Subscription]) -> String {
        var allNodes: [[String: Any]] = []
        var allProxyNames: [String] = []

        for sub in subscriptions {
            for node in sub.nodes {
                allNodes.append(node.clashConfig)
                allProxyNames.append(node.name)
            }
        }

        let config: [String: Any] = [
            "mixed-port": 7890,
            "allow-lan": true,
            "mode": "rule",
            "log-level": "info",
            "external-controller": "127.0.0.1:9090",
            "proxies": allNodes,
            "proxy-groups": [
                [
                    "name": "节点选择",
                    "type": "select",
                    "proxies": allProxyNames + ["DIRECT", "REJECT"]
                ],
                [
                    "name": "自动选择",
                    "type": "url-test",
                    "proxies": allProxyNames,
                    "url": "http://www.gstatic.com/generate_204",
                    "interval": 300
                ]
            ],
            "rules": [
                "DOMAIN-SUFFIX,local,DIRECT",
                "IP-CIDR,127.0.0.0/8,DIRECT",
                "GEOIP,CN,DIRECT",
                "MATCH,节点选择"
            ]
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }

        return ""
    }
}
