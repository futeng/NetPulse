import Foundation

struct ExitIPInfo: Equatable {
    var ip: String
    var country: String?
    var countryCode: String?
    var continent: String?
    var asn: String?
    var asName: String?
    var asDomain: String?
    var checkedAt: Date
    var durationMs: Double

    var locationText: String {
        [country, continent].compactMap { $0 }.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        .joined(separator: " · ")
    }

    var organizationText: String {
        [asn, asName].compactMap { $0 }.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        .joined(separator: " ")
    }
}

enum ExitIPState: Equatable {
    case idle
    case checking
    case success(ExitIPInfo)
    case failure(String)
}

struct ExitIPFetchError: Error, Equatable {
    var message: String
}
