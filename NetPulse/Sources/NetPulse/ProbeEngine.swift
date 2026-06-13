import Foundation

private final class MetricsDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var collectedMetrics: URLSessionTaskMetrics?

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        lock.lock()
        collectedMetrics = metrics
        lock.unlock()
    }

    func snapshot() -> URLSessionTaskMetrics? {
        lock.lock()
        defer { lock.unlock() }
        return collectedMetrics
    }
}

enum ProbeEngine {
    static func run(
        targets: [ProbeTarget],
        sampleCount: Int,
        timeoutSeconds: Double
    ) async -> NetworkRun {
        let startedAt = Date()
        let enabledTargets = targets.filter(\.enabled)

        let results = await withTaskGroup(of: ProbeResult.self, returning: [ProbeResult].self) { group in
            for target in enabledTargets {
                group.addTask {
                    await probe(target: target, sampleCount: sampleCount, timeoutSeconds: timeoutSeconds)
                }
            }

            var output: [ProbeResult] = []
            for await result in group {
                output.append(result)
            }
            return output.sorted {
                if $0.target.service == $1.target.service {
                    return $0.target.name < $1.target.name
                }
                return $0.target.service < $1.target.service
            }
        }

        return NetworkRun(startedAt: startedAt, finishedAt: Date(), results: results)
    }

    static func probe(
        target: ProbeTarget,
        sampleCount: Int,
        timeoutSeconds: Double
    ) async -> ProbeResult {
        let addresses = await resolve(host: URL(string: target.urlString)?.host)
        let samples = await withTaskGroup(of: ProbeSample.self, returning: [ProbeSample].self) { group in
            for _ in 0..<max(1, sampleCount) {
                group.addTask {
                    await sample(target: target, timeoutSeconds: timeoutSeconds)
                }
            }
            var output: [ProbeSample] = []
            for await sample in group {
                output.append(sample)
            }
            return output.sorted { $0.checkedAt < $1.checkedAt }
        }
        return ProbeResult(target: target, resolvedAddresses: addresses, samples: samples)
    }

    static func sample(target: ProbeTarget, timeoutSeconds: Double) async -> ProbeSample {
        guard let url = URL(string: target.urlString) else {
            return failureSample(totalMs: 0, phase: "config", detail: "URL 无效")
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = timeoutSeconds
        request.setValue(
            "Mozilla/5.0 (Macintosh; Apple Silicon Mac OS X) AppleWebKit/537.36 NetPulse/1.0",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        if let rangeBytes = target.rangeBytes, rangeBytes > 0 {
            request.setValue("bytes=0-\(rangeBytes - 1)", forHTTPHeaderField: "Range")
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForRequest = timeoutSeconds
        configuration.timeoutIntervalForResource = timeoutSeconds
        configuration.waitsForConnectivity = false
        configuration.httpMaximumConnectionsPerHost = max(3, target.rangeBytes == nil ? 3 : 2)

        let delegate = MetricsDelegate()
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        let startedAt = Date()

        do {
            let (data, response) = try await session.data(for: request)
            let elapsed = Date().timeIntervalSince(startedAt) * 1_000
            let metrics = delegate.snapshot()?.transactionMetrics.last
            session.finishTasksAndInvalidate()

            guard let http = response as? HTTPURLResponse else {
                return failureSample(totalMs: elapsed, phase: "http", detail: "没有 HTTP 响应")
            }

            let contentType = http.value(forHTTPHeaderField: "Content-Type")
            let statusOK = target.acceptAnyStatusBelow500
                ? (200..<500).contains(http.statusCode)
                : target.acceptedStatusCodes.contains(http.statusCode)
            let contentOK = target.expectedContentPrefix.map {
                (contentType ?? "").lowercased().hasPrefix($0.lowercased())
            } ?? true
            let bytesOK = data.count >= target.minimumBytes

            let phase: String?
            let detail: String?
            if !statusOK {
                phase = "http_status"
                detail = "HTTP \(http.statusCode)"
            } else if !contentOK {
                phase = "content_type"
                detail = contentType ?? "缺少 Content-Type"
            } else if !bytesOK {
                phase = "content"
                detail = "只读取到 \(data.count)B，要求至少 \(target.minimumBytes)B"
            } else {
                phase = nil
                detail = nil
            }

            return ProbeSample(
                ok: statusOK && contentOK && bytesOK,
                checkedAt: startedAt,
                statusCode: http.statusCode,
                contentType: contentType,
                bytesRead: data.count,
                timings: timings(from: metrics, fallbackTotalMs: elapsed),
                protocolName: metrics?.networkProtocolName,
                isProxyConnection: metrics?.isProxyConnection,
                errorPhase: phase,
                errorDetail: detail
            )
        } catch {
            let elapsed = Date().timeIntervalSince(startedAt) * 1_000
            let metrics = delegate.snapshot()?.transactionMetrics.last
            session.invalidateAndCancel()
            let classified = classify(error: error)
            return ProbeSample(
                ok: false,
                checkedAt: startedAt,
                statusCode: nil,
                contentType: nil,
                bytesRead: 0,
                timings: timings(from: metrics, fallbackTotalMs: elapsed),
                protocolName: metrics?.networkProtocolName,
                isProxyConnection: metrics?.isProxyConnection,
                errorPhase: classified.phase,
                errorDetail: classified.detail
            )
        }
    }

    private static func timings(
        from metric: URLSessionTaskTransactionMetrics?,
        fallbackTotalMs: Double
    ) -> ProbeTimings {
        let measuredTotal = interval(metric?.fetchStartDate, metric?.responseEndDate)
        return ProbeTimings(
            dnsMs: interval(metric?.domainLookupStartDate, metric?.domainLookupEndDate),
            tcpMs: interval(metric?.connectStartDate, metric?.connectEndDate),
            tlsMs: interval(metric?.secureConnectionStartDate, metric?.secureConnectionEndDate),
            firstByteMs: interval(metric?.requestStartDate, metric?.responseStartDate),
            totalMs: measuredTotal ?? fallbackTotalMs
        )
    }

    private static func interval(_ start: Date?, _ end: Date?) -> Double? {
        guard let start, let end else { return nil }
        return end.timeIntervalSince(start) * 1_000
    }

    private static func classify(error: Error) -> (phase: String, detail: String) {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            return ("network", error.localizedDescription)
        }
        let code = URLError.Code(rawValue: nsError.code)

        let phase: String
        switch code {
        case .cannotFindHost, .dnsLookupFailed:
            phase = "dns"
        case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
            phase = "tcp"
        case .secureConnectionFailed, .serverCertificateHasBadDate,
             .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid, .clientCertificateRejected:
            phase = "tls"
        case .timedOut:
            phase = "timeout"
        default:
            phase = "http"
        }
        return (phase, nsError.localizedDescription)
    }

    private static func failureSample(totalMs: Double, phase: String, detail: String) -> ProbeSample {
        ProbeSample(
            ok: false,
            checkedAt: Date(),
            statusCode: nil,
            contentType: nil,
            bytesRead: 0,
            timings: ProbeTimings(totalMs: totalMs),
            protocolName: nil,
            isProxyConnection: nil,
            errorPhase: phase,
            errorDetail: detail
        )
    }

    private static func resolve(host: String?) async -> [String] {
        guard let host, !host.isEmpty else { return [] }
        return await Task.detached(priority: .utility) {
            var hints = addrinfo(
                ai_flags: AI_ADDRCONFIG,
                ai_family: AF_UNSPEC,
                ai_socktype: SOCK_STREAM,
                ai_protocol: IPPROTO_TCP,
                ai_addrlen: 0,
                ai_canonname: nil,
                ai_addr: nil,
                ai_next: nil
            )
            var result: UnsafeMutablePointer<addrinfo>?
            guard getaddrinfo(host, nil, &hints, &result) == 0, let first = result else {
                return []
            }
            defer { freeaddrinfo(first) }

            var addresses = Set<String>()
            var cursor: UnsafeMutablePointer<addrinfo>? = first
            while let current = cursor {
                var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let info = current.pointee
                if getnameinfo(
                    info.ai_addr,
                    info.ai_addrlen,
                    &buffer,
                    socklen_t(buffer.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                ) == 0 {
                    addresses.insert(String(cString: buffer))
                }
                cursor = info.ai_next
            }
            return Array(addresses).sorted()
        }.value
    }
}
