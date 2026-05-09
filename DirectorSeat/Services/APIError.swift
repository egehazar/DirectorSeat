import Foundation

enum APIError: Error, LocalizedError {
    case networkUnavailable          // -1009
    case timeout                     // -1001
    case dnsFailure                  // -1003
    case sslFailure                  // -2102 inner code
    case invalidAuth                 // 401, 403
    case rateLimited(retryAfterSeconds: Int?)  // 429
    case serverError(status: Int)    // 5xx
    case malformedResponse(String)
    case decodingFailed(String)
    case cancelled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: return "No internet connection"
        case .timeout: return "The request took too long"
        case .dnsFailure: return "Couldn't reach the server"
        case .sslFailure: return "Secure connection failed"
        case .invalidAuth: return "Authentication issue — please contact support"
        case .rateLimited(let retry):
            if let retry { return "Too many requests — try again in \(retry) seconds" }
            return "Too many requests — try again in a moment"
        case .serverError(let status): return "Server error (\(status)) — try again in a moment"
        case .malformedResponse: return "Got an unexpected response"
        case .decodingFailed: return "Couldn't read the response"
        case .cancelled: return "Request cancelled"
        case .unknown(let msg): return msg
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .timeout, .dnsFailure, .sslFailure,
             .rateLimited, .serverError: return true
        case .invalidAuth, .malformedResponse, .decodingFailed, .cancelled, .unknown: return false
        }
    }

    /// Suggested wait before retry, in seconds. Honors Retry-After when present.
    var retryDelay: TimeInterval {
        switch self {
        case .rateLimited(let retry): return TimeInterval(retry ?? 5)
        case .serverError: return 2.0
        default: return 1.0
        }
    }
}

/// Maps an arbitrary Error or HTTPURLResponse + Data to a typed APIError.
/// Inspect NSError.code for URLError classification, then HTTP status for API responses.
enum APIErrorMapper {
    static func from(_ error: Error) -> APIError {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case -1001: return .timeout
            case -1003: return .dnsFailure
            case -1009: return .networkUnavailable
            case -1200, -1202: return .sslFailure
            case -999: return .cancelled
            default: return .unknown(error.localizedDescription)
            }
        }
        // Inner stream error code -2102 means SSL handshake issue
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.userInfo["_kCFStreamErrorCodeKey"] as? Int == -2102 {
            return .sslFailure
        }
        return .unknown(error.localizedDescription)
    }

    static func fromResponse(_ response: HTTPURLResponse, data: Data?) -> APIError? {
        switch response.statusCode {
        case 200..<300: return nil
        case 401, 403: return .invalidAuth
        case 429:
            let retry = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            return .rateLimited(retryAfterSeconds: retry)
        case 500..<600: return .serverError(status: response.statusCode)
        default:
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            return .malformedResponse("HTTP \(response.statusCode): \(body.prefix(200))")
        }
    }
}
