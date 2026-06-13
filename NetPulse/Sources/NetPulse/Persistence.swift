import Foundation

enum Persistence {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("NetPulse", isDirectory: true)
    }

    static func loadConfiguration() -> AppConfiguration {
        load(AppConfiguration.self, from: directory.appendingPathComponent("config.json"))
            ?? .default
    }

    static func saveConfiguration(_ configuration: AppConfiguration) {
        save(configuration, to: directory.appendingPathComponent("config.json"))
    }

    static func loadHistory() -> [NetworkRun] {
        load([NetworkRun].self, from: directory.appendingPathComponent("history.json"))
            ?? []
    }

    static func saveHistory(_ history: [NetworkRun]) {
        save(Array(history.prefix(50)), to: directory.appendingPathComponent("history.json"))
    }

    private static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private static func save<T: Encodable>(_ value: T, to url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(value)
            let temporary = url.appendingPathExtension("tmp")
            try data.write(to: temporary, options: .atomic)
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: url)
            }
        } catch {
            NSLog("NetPulse persistence error: \(error)")
        }
    }
}
