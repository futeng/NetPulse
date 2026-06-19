import Foundation

enum ExitIPEngine {
    static func fetchIPinfoLite(
        token: String,
        timeoutSeconds: Double = 5
    ) async -> Result<ExitIPInfo, ExitIPFetchError> {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            return .failure(ExitIPFetchError(message: "缺少 IPinfo Lite API Token"))
        }

        var components = URLComponents(string: "https://api.ipinfo.io/lite/me")
        components?.queryItems = [URLQueryItem(name: "token", value: trimmedToken)]
        guard let url = components?.url else {
            return .failure(ExitIPFetchError(message: "IPinfo Lite URL 无效"))
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutSeconds
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue(
            "Mozilla/5.0 (Macintosh; Apple Silicon Mac OS X) AppleWebKit/537.36 NetPulse/1.0",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeoutSeconds
        configuration.timeoutIntervalForResource = timeoutSeconds
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: configuration)
        let startedAt = Date()

        do {
            let (data, response) = try await session.data(for: request)
            let elapsed = Date().timeIntervalSince(startedAt) * 1_000
            session.finishTasksAndInvalidate()

            guard let http = response as? HTTPURLResponse else {
                return .failure(ExitIPFetchError(message: "没有 HTTP 响应"))
            }

            guard http.statusCode == 200 else {
                return .failure(
                    ExitIPFetchError(message: "IPinfo Lite 返回 HTTP \(http.statusCode)")
                )
            }

            let decoded = try JSONDecoder().decode(IPinfoLiteResponse.self, from: data)
            guard !decoded.ip.isEmpty else {
                return .failure(ExitIPFetchError(message: "IPinfo Lite 响应缺少 IP"))
            }

            return .success(
                ExitIPInfo(
                    ip: decoded.ip,
                    country: decoded.country,
                    countryCode: decoded.countryCode,
                    continent: decoded.continent,
                    asn: decoded.asn,
                    asName: decoded.asName,
                    asDomain: decoded.asDomain,
                    checkedAt: startedAt,
                    durationMs: elapsed
                )
            )
        } catch {
            session.invalidateAndCancel()
            return .failure(ExitIPFetchError(message: error.localizedDescription))
        }
    }
}

private struct IPinfoLiteResponse: Decodable {
    var ip: String
    var asn: String?
    var asName: String?
    var asDomain: String?
    var countryCode: String?
    var country: String?
    var continentCode: String?
    var continent: String?

    private enum CodingKeys: String, CodingKey {
        case ip
        case asn
        case asName = "as_name"
        case asDomain = "as_domain"
        case countryCode = "country_code"
        case country
        case continentCode = "continent_code"
        case continent
    }
}
