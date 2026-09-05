import Foundation

struct Subscription: Codable, Identifiable {
    var id = UUID()
    var name: String
    var url: String
    var addTime: Date
    var updateTime: Date?
    var nodeCount: Int
    var nodes: [Node]
    var autoUpdate: Bool = true
}

struct Node: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var type: String
    var server: String
    var port: Int
    var password: String?
    var uuid: String?
    var cipher: String?
    var network: String?
    var sni: String?
    var wsPath: String?
    var wsHost: String?
    var tls: Bool = false
    var udp: Bool = true
    var skipCertVerify: Bool = false
    var latency: Int?
    var rawConfig: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case id, name, type, server, port, password, uuid, cipher, network, sni, wsPath, wsHost, tls, udp, skipCertVerify, latency
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(server, forKey: .server)
        try container.encode(port, forKey: .port)
        try container.encodeIfPresent(password, forKey: .password)
        try container.encodeIfPresent(uuid, forKey: .uuid)
        try container.encodeIfPresent(cipher, forKey: .cipher)
        try container.encodeIfPresent(network, forKey: .network)
        try container.encodeIfPresent(sni, forKey: .sni)
        try container.encodeIfPresent(wsPath, forKey: .wsPath)
        try container.encodeIfPresent(wsHost, forKey: .wsHost)
        try container.encode(tls, forKey: .tls)
        try container.encode(udp, forKey: .udp)
        try container.encode(skipCertVerify, forKey: .skipCertVerify)
        try container.encodeIfPresent(latency, forKey: .latency)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        server = try container.decode(String.self, forKey: .server)
        port = try container.decode(Int.self, forKey: .port)
        password = try container.decodeIfPresent(String.self, forKey: .password)
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid)
        cipher = try container.decodeIfPresent(String.self, forKey: .cipher)
        network = try container.decodeIfPresent(String.self, forKey: .network)
        sni = try container.decodeIfPresent(String.self, forKey: .sni)
        wsPath = try container.decodeIfPresent(String.self, forKey: .wsPath)
        wsHost = try container.decodeIfPresent(String.self, forKey: .wsHost)
        tls = try container.decode(Bool.self, forKey: .tls)
        udp = try container.decode(Bool.self, forKey: .udp)
        skipCertVerify = try container.decode(Bool.self, forKey: .skipCertVerify)
        latency = try container.decodeIfPresent(Int.self, forKey: .latency)
    }

    init(name: String, type: String, server: String, port: Int) {
        self.name = name
        self.type = type
        self.server = server
        self.port = port
    }

    // 生成节点链接
    var nodeLink: String {
        switch type.lowercased() {
        case "trojan":
            let user = password ?? ""
            var params: [String] = []
            if let sni = sni { params.append("sni=\(sni)") }
            if let network = network, network == "ws" {
                params.append("type=ws")
                if let wsPath = wsPath { params.append("path=\(wsPath)") }
                if let wsHost = wsHost { params.append("host=\(wsHost)") }
            }
            if skipCertVerify { params.append("allowInsecure=1") }
            let paramStr = params.joined(separator: "&")
            return "trojan://\(user)@\(server):\(port)?\(paramStr)#\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)"

        case "vmess":
            let uuidStr = uuid ?? ""
            var dict: [String: Any] = [
                "v": "2",
                "ps": name,
                "add": server,
                "port": port,
                "id": uuidStr,
                "aid": 0,
                "scy": cipher ?? "auto",
                "net": network ?? "tcp",
                "type": "none",
                "host": wsHost ?? "",
                "path": wsPath ?? "",
                "tls": tls ? "tls" : "",
                "sni": sni ?? ""
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: dict),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                return "vmess://\(Data(jsonStr.utf8).base64EncodedString())"
            }
            return "vmess://"

        case "ss", "shadowsocks":
            let method = cipher ?? "aes-256-gcm"
            let passwordStr = password ?? ""
            let userInfo = "\(method):\(passwordStr)"
            let base64UserInfo = Data(userInfo.utf8).base64EncodedString()
            return "ss://\(base64UserInfo)@\(server):\(port)#\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)"

        default:
            return "\(type)://\(server):\(port)"
        }
    }

    // 生成Clash配置
    var clashConfig: [String: Any] {
        var config: [String: Any] = [
            "name": name,
            "type": type,
            "server": server,
            "port": port,
            "udp": udp
        ]
        if let password = password { config["password"] = password }
        if let uuid = uuid { config["uuid"] = uuid }
        if let cipher = cipher { config["cipher"] = cipher }
        if let network = network { config["network"] = network }
        if let sni = sni { config["sni"] = sni }
        if let wsPath = wsPath { config["ws-path"] = wsPath }
        if let wsHost = wsHost { config["ws-headers"] = ["Host": wsHost] }
        if tls { config["tls"] = true }
        if skipCertVerify { config["skip-cert-verify"] = true }
        return config
    }
}
